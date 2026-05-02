import Foundation
import Security

class KeychainHelper {
    static let shared = KeychainHelper()
    
    private let account = "OctoBell"
    private let service = "com.zigastrgar.octobell"
    
    func saveToken(_ tokenResponse: OAuthTokenResponse) {
        guard let data = try? JSONEncoder().encode(tokenResponse) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service
        ]
        
        // Remove existing item before saving new one
        SecItemDelete(query as CFDictionary)
        
        var newQuery = query
        newQuery[kSecValueData as String] = data
        
        let status = SecItemAdd(newQuery as CFDictionary, nil)
        if status != errSecSuccess {
            AppLogger.log("Error saving to Keychain: \(status)")
        }
    }
    
    func fetchToken() -> OAuthTokenResponse? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
        } catch {
            deleteToken()
            return nil
        }
    }
    
    func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }
}
