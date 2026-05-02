import Foundation

extension Notification.Name {
    static let gitHubUnauthorized = Notification.Name("GitHubUnauthorized")
}

enum APIError: Error {
    case unauthenticated
    case unauthorized
    case invalidURL
    case networkError(Error)
    case unparsableResponse
}

class GitHubClient {
    static let shared = GitHubClient()
    private let baseURL = "https://api.github.com"
    
    private var tokenResponse: OAuthTokenResponse? {
        KeychainHelper.shared.fetchToken()
    }
    
    private var token: String? {
        tokenResponse?.accessToken
    }
    
    private let refresher = TokenRefresher()
    
    private func makeRequest(endpoint: String, queryItems: [URLQueryItem]? = nil, ignoreCache: Bool = false) throws -> URLRequest {
        guard let token = token else {
            throw APIError.unauthenticated
        }
        
        var components = URLComponents(string: baseURL + endpoint)
        if let queryItems = queryItems {
            components?.queryItems = queryItems
        }
        
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        if ignoreCache {
            request.cachePolicy = .reloadIgnoringLocalCacheData
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2026-03-10", forHTTPHeaderField: "X-GitHub-Api-Version")
        return request
    }
    
    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        var executingRequest = request
        let (data, response) = try await URLSession.shared.data(for: executingRequest)
        
        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            guard let tokenResp = tokenResponse else {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .gitHubUnauthorized, object: nil)
                }
                throw APIError.unauthorized
            }
            
            do {
                let newResp = try await refresher.refresh(using: tokenResp, clientId: AuthManager.clientId)
                executingRequest.setValue("Bearer \(newResp.accessToken)", forHTTPHeaderField: "Authorization")
                
                let (retryData, retryResponse) = try await URLSession.shared.data(for: executingRequest)
                if let retryHttp = retryResponse as? HTTPURLResponse, retryHttp.statusCode == 401 {
                    throw APIError.unauthorized
                }
                return (retryData, retryResponse)
            } catch {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .gitHubUnauthorized, object: nil)
                }
                throw APIError.unauthorized
            }
        }
        return (data, response)
    }
    
    // Fetch only the repositories the GitHub App installation has access to
    func fetchRepositories(ignoreCache: Bool = false) async throws -> [GHRepository] {
        // 1. Fetch the user's app installations
        let installationsReq = try makeRequest(endpoint: "/user/installations", ignoreCache: ignoreCache)
        var installations: [GHInstallation] = []
        
        do {
            AppLogger.log("fetching installations: \(installationsReq.url?.absoluteString ?? "")")
            let (data, response) = try await performRequest(installationsReq)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                AppLogger.log("API ERROR [fetchInstallations]: \(http.statusCode) - \(String(data: data, encoding: .utf8) ?? "")")
            }
            installations = try JSONDecoder().decode(GHInstallationResponse.self, from: data).installations
        } catch {
            AppLogger.log("DECODE/NETWORK ERROR [fetchInstallations]: \(error)")
            throw APIError.networkError(error)
        }
        
        // 2. Fetch the permissible repositories for each installation
        var allAccessibleRepos: [GHRepository] = []
        
        for installation in installations {
            let reposReq = try makeRequest(endpoint: "/user/installations/\(installation.id)/repositories", queryItems: [URLQueryItem(name: "per_page", value: "100")], ignoreCache: ignoreCache)
            do {
                AppLogger.log("fetching repos for installation \(installation.id)")
                let (data, response) = try await performRequest(reposReq)
                if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                    AppLogger.log("API ERROR [fetchinstallationRepositories]: \(http.statusCode)")
                }
                let payload = try JSONDecoder().decode(GHInstallationRepositoriesResponse.self, from: data)
                allAccessibleRepos.append(contentsOf: payload.repositories)
            } catch {
                AppLogger.log("DECODE/NETWORK ERROR [fetchInstallationRepos]: \(error)")
                // Continue to other installations
            }
        }
        
        return allAccessibleRepos
    }
    
    // Fetch workflow runs for a specific user across a repository
    func fetchWorkflowRuns(forRepo ownerRepo: String, actor: String, ignoreCache: Bool = false) async throws -> [GHWorkflowRun] {
        let maxLimit = await MainActor.run { SettingsManager.shared.runsToFetch }
        var gatheredRuns: [GHWorkflowRun] = []
        
        for page in 1...3 {
            let query = [
                URLQueryItem(name: "actor", value: actor),
                URLQueryItem(name: "per_page", value: "50"),
                URLQueryItem(name: "page", value: "\(page)")
            ]
            
            let request = try makeRequest(endpoint: "/repos/\(ownerRepo)/actions/runs", queryItems: query, ignoreCache: ignoreCache)
            
            AppLogger.log("fetching workflows for \(ownerRepo) [Page \(page)]: \(request.url?.absoluteString ?? "")")
            let (data, response) = try await performRequest(request)
            
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                AppLogger.log("API ERROR [fetchWorkflowRuns]: \(http.statusCode) - \(String(data: data, encoding: .utf8) ?? "")")
                break
            }
            
            let res = try JSONDecoder().decode(GHWorkflowRunResponse.self, from: data)
            gatheredRuns.append(contentsOf: res.workflowRuns)
            
            // Short-circuit if we hit the requested preference limit mathematically early
            if gatheredRuns.count >= maxLimit {
                break
            }
            
            // Short-circuit if there are no more paginated results natively
            if res.workflowRuns.count < 50 {
                break
            }
        }
        
        return Array(gatheredRuns.prefix(maxLimit))
    }
    
    // Fetch a single workflow run by ID
    func fetchWorkflowRun(forRepo ownerRepo: String, runId: Int) async throws -> GHWorkflowRun? {
        let request = try makeRequest(endpoint: "/repos/\(ownerRepo)/actions/runs/\(runId)")
        let (data, response) = try await performRequest(request)
        if let http = response as? HTTPURLResponse, http.statusCode < 400 {
            return try JSONDecoder().decode(GHWorkflowRun.self, from: data)
        }
        return nil
    }
    
    // Rerun failed jobs of a workflow
    func retryFailedWorkflow(forRepo ownerRepo: String, runId: Int) async throws {
        var request = try makeRequest(endpoint: "/repos/\(ownerRepo)/actions/runs/\(runId)/rerun-failed-jobs")
        request.httpMethod = "POST"
        request.httpBody = Data("{}".utf8) // Sometimes POST requires body bytes explicitly
        
        let (data, response) = try await performRequest(request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let errorBody = String(data: data, encoding: .utf8) ?? "unknown"
            AppLogger.log("RETRY API ERROR [\(http.statusCode)]: \(errorBody)")
            throw APIError.networkError(NSError(domain: "GitHubClient", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: errorBody]))
        }
        AppLogger.log("RETRY API SUCCESS [\(ownerRepo) / \(runId)]")
    }
    

    
    // Cancel an active workflow run
    func cancelWorkflow(forRepo ownerRepo: String, runId: Int) async throws {
        var request = try makeRequest(endpoint: "/repos/\(ownerRepo)/actions/runs/\(runId)/cancel")
        request.httpMethod = "POST"
        request.httpBody = Data("{}".utf8)
        
        let (data, response) = try await performRequest(request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let errorBody = String(data: data, encoding: .utf8) ?? "unknown"
            AppLogger.log("CANCEL API ERROR [\(http.statusCode)]: \(errorBody)")
            throw APIError.networkError(NSError(domain: "GitHubClient", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: errorBody]))
        }
        AppLogger.log("CANCEL API SUCCESS [\(ownerRepo) / \(runId)]")
    }
    

    
    // Fetch user details to get exact username and avatar for actor scope
    func fetchCurrentUser(ignoreCache: Bool = false) async throws -> GHActor {
        let request = try makeRequest(endpoint: "/user", ignoreCache: ignoreCache)
        
        do {
            AppLogger.log("fetching user: \(request.url?.absoluteString ?? "")")
            let (data, response) = try await performRequest(request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                AppLogger.log("API ERROR [fetchCurrentUser]: \(http.statusCode) - \(String(data: data, encoding: .utf8) ?? "")")
            }
            let actor = try JSONDecoder().decode(GHActor.self, from: data)
            return actor
        } catch {
            AppLogger.log("DECODE/NETWORK ERROR [fetchCurrentUser]: \(error)")
            throw APIError.networkError(error)
        }
    }
}

actor TokenRefresher {
    private var activeRefreshTask: Task<OAuthTokenResponse, Error>?
    
    func refresh(using response: OAuthTokenResponse, clientId: String) async throws -> OAuthTokenResponse {
        if let existing = activeRefreshTask {
            return try await existing.value
        }
        
        let task = Task { () -> OAuthTokenResponse in
            guard let refreshToken = response.refreshToken else {
                throw APIError.unauthorized
            }
            
            let url = URL(string: "https://github.com/login/oauth/access_token")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: String] = [
                "client_id": clientId,
                "grant_type": "refresh_token",
                "refresh_token": refreshToken
            ]
            request.httpBody = try? JSONEncoder().encode(body)
            
            let (data, res) = try await URLSession.shared.data(for: request)
            if let http = res as? HTTPURLResponse, http.statusCode >= 400 {
                throw APIError.unauthorized
            }
            if let errorResponse = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data), errorResponse.error != "" {
                throw APIError.unauthorized
            }
            
            let newResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
            KeychainHelper.shared.saveToken(newResponse)
            return newResponse
        }
        
        activeRefreshTask = task
        
        do {
            let value = try await task.value
            activeRefreshTask = nil
            return value
        } catch {
            activeRefreshTask = nil
            throw error
        }
    }
}
