import Foundation

enum AuthState: Equatable {
    case unauthenticated
    case requestingCode
    case waitingForUser(userCode: String, verificationUri: String)
    case authenticating
    case authenticated
    case error(String)
}

@MainActor
class AuthManager: ObservableObject {
    @Published var state: AuthState = .unauthenticated
    
    static let clientId = "Iv23liuw2TWVmmqns2fT"
    let scopes = "repo read:org"
    
    init() {
        checkExistingToken()
    }
    
    func checkExistingToken() {
        if KeychainHelper.shared.fetchToken() != nil {
            self.state = .authenticated
        }
    }
    
    func startDeviceFlow() async {
        self.state = .requestingCode
        
        guard let url = URL(string: "https://github.com/login/device/code") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "client_id": AuthManager.clientId,
            "scope": scopes
        ]
        request.httpBody = try? JSONEncoder().encode(body)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
            
            self.state = .waitingForUser(userCode: response.userCode, verificationUri: response.verificationUri)
            
            // Start polling
            Task {
                await pollForToken(deviceCode: response.deviceCode, interval: response.interval)
            }
            
        } catch {
            self.state = .error(error.localizedDescription)
        }
    }
    
    private func pollForToken(deviceCode: String, interval: Int) async {
        let url = URL(string: "https://github.com/login/oauth/access_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "client_id": AuthManager.clientId,
            "device_code": deviceCode,
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
        ]
        request.httpBody = try? JSONEncoder().encode(body)
        
        var isPolling = true
        var currentInterval = interval
        
        while isPolling {
            try? await Task.sleep(nanoseconds: UInt64(currentInterval) * 1_000_000_000)
            
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                if let errorResponse = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data) {
                    if errorResponse.error == "authorization_pending" {
                        continue // Keep polling
                    } else if errorResponse.error == "slow_down" {
                        currentInterval += 5 // Increase interval as requested by GitHub
                        continue
                    } else {
                        isPolling = false
                        self.state = .error(errorResponse.errorDescription ?? errorResponse.error)
                    }
                } else if let successResponse = try? JSONDecoder().decode(OAuthTokenResponse.self, from: data) {
                    KeychainHelper.shared.saveToken(successResponse)
                    self.state = .authenticated
                    isPolling = false
                }
            } catch {
                self.state = .error(error.localizedDescription)
                isPolling = false
            }
        }
    }
    
    func logout() {
        KeychainHelper.shared.deleteToken()
        self.state = .unauthenticated
    }
}

// MARK: - Models

struct DeviceCodeResponse: Codable {
    let deviceCode: String
    let userCode: String
    let verificationUri: String
    let expiresIn: Int
    let interval: Int
    
    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}

struct OAuthErrorResponse: Codable {
    let error: String
    let errorDescription: String?
    
    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

struct OAuthTokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let scope: String
    let refreshToken: String?
    let expiresIn: Int?
    let refreshTokenExpiresIn: Int?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case refreshTokenExpiresIn = "refresh_token_expires_in"
    }
}
