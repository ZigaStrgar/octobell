import Foundation

struct GHRepository: Codable, Identifiable {
    let id: Int
    let name: String
    let fullName: String
    let `private`: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case fullName = "full_name"
        case `private`
    }
}

struct GHInstallationResponse: Codable {
    let installations: [GHInstallation]
}

struct GHInstallation: Codable {
    let id: Int
}

struct GHInstallationRepositoriesResponse: Codable {
    let repositories: [GHRepository]
}

struct GHWorkflowRunResponse: Codable {
    let totalCount: Int
    let workflowRuns: [GHWorkflowRun]
    
    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case workflowRuns = "workflow_runs"
    }
}




struct GHActor: Codable {
    let login: String
    let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case login
        case avatarUrl = "avatar_url"
    }
}

struct GHWorkflowRun: Codable, Identifiable {
    let id: Int
    let name: String
    let workflowId: Int
    let runNumber: Int
    let runAttempt: Int
    let headBranch: String
    let headSha: String
    let status: String
    let conclusion: String?
    let repository: GHRepository
    let actor: GHActor?
    let htmlUrl: String
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, status, conclusion, repository, actor
        case workflowId = "workflow_id"
        case runNumber = "run_number"
        case runAttempt = "run_attempt"
        case headBranch = "head_branch"
        case headSha = "head_sha"
        case htmlUrl = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Helper to determine active status
    var isRunning: Bool {
        return status == "in_progress" || status == "queued"
    }
}
