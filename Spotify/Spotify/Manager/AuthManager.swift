//
//  AuthManager.swift
//  Spotify
//
//  Created by Amar Choudhary on 17/4/25.
//

import Foundation

final class AuthManager {
    
    static let shared = AuthManager()
    
    struct Constants {
        static let clientID = "46c1bdd1fe8e4433bc4c091277e0cccb"
        static let clientSecret = "a7bb10052f79472c97acdaa22d8a8d2d"
        static let redirectURI = "https://www.google.com"

    }
    
    public var signInURL: URL? {
        let scopes = "user-read-private"
        let base = "https://accounts.spotify.com/authorize"
        let redirectURIUnCoded = Constants.redirectURI.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed)
        let string = "\(base)?response_type=code&client_id=\(Constants.clientID)&scope=\(scopes)&redirect_uri=\(redirectURIUnCoded!)&show_dialog=TRUE"
        return URL(string: string)
    }
    
    private init() {}
    
    var isSignedIn: Bool { return false }
    
    private var accessToken: String? { return nil }
    
    private var refreshToken: String? { return nil }
    
    private var tokenExpirationDate: Date? { return nil }
    
    private var shouldRefreshToken: Bool { return false }
    
    public func exchangeCodeForToken(code: String, completion: @escaping (Bool) -> Void) {
        
        
    }
}
