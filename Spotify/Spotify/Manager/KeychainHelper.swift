//
//  KeychainHelper.swift
//  Spotify
//
//  Created by Amar Choudhary on 19/4/25.
//

import Foundation

// MARK: - Keychain Handling
enum KeychainService: String {
    case accessToken = "SpotifyAccessToken"
    case refreshToken = "SpotifyRefreshToken"
    case expirationDate = "SpotifyTokenExpiration"
}

// MARK: - Keychain Helper
final class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}
    
    func save(_ data: String, service: String) {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecValueData: data.data(using: .utf8)!
        ] as CFDictionary
        
        SecItemDelete(query)
        SecItemAdd(query, nil)
    }
    
    func save(_ date: Date, service: String) {
        let dateData = withUnsafeBytes(of: date.timeIntervalSinceReferenceDate) { Data($0) }
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecValueData: dateData
        ] as CFDictionary
        
        SecItemDelete(query)
        SecItemAdd(query, nil)
    }
    
    func read(service: String) -> String? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecReturnData: kCFBooleanTrue!,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary
        
        var result: AnyObject?
        SecItemCopyMatching(query, &result)
        
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func readDate(service: String) -> Date? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecReturnData: kCFBooleanTrue!,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary
        
        var result: AnyObject?
        SecItemCopyMatching(query, &result)
        
        guard let data = result as? Data else { return nil }
        return data.withUnsafeBytes { $0.load(as: TimeInterval.self) }.bridgeToDate()
    }
}
