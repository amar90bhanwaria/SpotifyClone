//  AuthManager.swift
//  Spotify
//
//  Created by Amar Choudhary on 17/4/25.
//

import Foundation
import Security

final class AuthManager {
    // MARK: - Shared Instance
    static let shared = AuthManager()
    private var isRefreshingToken = false
    private let tokenQueue = DispatchQueue(label: "com.spotify.auth.tokenQueue", attributes: .concurrent)
    
    // MARK: - Constants (Move sensitive data to secure storage)
    struct Constants {
        static let redirectURI = "https://spotifyclone.com/callback"
        static let tokenAPIURL = "https://accounts.spotify.com/api/token"
        static let authScopes = ["user-read-private", "playlist-read-private", "playlist-modify-private"]
        
        // Secure storage for credentials (Use Xcode environment variables or secure config)
        static var clientID: String {
            guard let id = ProcessInfo.processInfo.environment["SPOTIFY_CLIENT_ID"] else {
                fatalError("Missing SPOTIFY_CLIENT_ID in configuration")
            }
            return id
        }
        
        static var clientSecret: String {
            guard let secret = ProcessInfo.processInfo.environment["SPOTIFY_CLIENT_SECRET"] else {
                fatalError("Missing SPOTIFY_CLIENT_SECRET in configuration")
            }
            return secret
        }
    }
    
    // MARK: - Token Management
    private var accessToken: String? {
        KeychainHelper.shared.read(service: KeychainService.accessToken.rawValue)
    }
    
    private var refreshToken: String? {
        KeychainHelper.shared.read(service: KeychainService.refreshToken.rawValue)
    }
    
    private var tokenExpirationDate: Date? {
        KeychainHelper.shared.readDate(service: KeychainService.expirationDate.rawValue)
    }
    
    var isSignedIn: Bool {
        accessToken != nil && !shouldRefreshToken
    }
    
    private var shouldRefreshToken: Bool {
        guard let expirationDate = tokenExpirationDate else { return true }
        return Date().addingTimeInterval(300) >= expirationDate
    }
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Public Methods
    public var signInURL: URL? {
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")
        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: Constants.clientID),
            URLQueryItem(name: "scope", value: Constants.authScopes.joined(separator: " ")),
            URLQueryItem(name: "redirect_uri", value: Constants.redirectURI),
            URLQueryItem(name: "show_dialog", value: "TRUE")
        ]
        return components?.url
    }
    
    public func exchangeCodeForToken(
        code: String,
        completion: @escaping (Result<Bool, AuthError>) -> Void
    ) {
        guard let url = URL(string: Constants.tokenAPIURL) else {
            return completion(.failure(.invalidURL))
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(basicAuthHeader, forHTTPHeaderField: "Authorization")
        request.httpBody = tokenRequestBody(code: code)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                return completion(.failure(.networkError(error)))
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return completion(.failure(.invalidResponse))
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                return completion(.failure(.serverError(statusCode: httpResponse.statusCode)))
            }
            
            guard let data = data else {
                return completion(.failure(.noData))
            }
            
            do {
                let response = try JSONDecoder().decode(AuthResponse.self, from: data)
                self.cacheTokens(response: response)
                completion(.success(true))
            } catch {
                completion(.failure(.decodingError(error)))
            }
        }.resume()
    }
    
    // MARK: - Token Refresh
    private var onRefreshTokenBlocks = [(Result<String, AuthError>) -> Void]()
    
    public func withValidToken(completion: @escaping (Result<String, AuthError>) -> Void) {
        tokenQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            if self.isRefreshingToken {
                self.onRefreshTokenBlocks.append(completion)
                return
            }
            
            if self.shouldRefreshToken {
                self.refreshAccessToken { result in
                    switch result {
                    case .success(let token):
                        completion(.success(token))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            } else if let token = self.accessToken {
                completion(.success(token))
            } else {
                completion(.failure(.missingToken))
            }
        }
    }
    
    public func refreshAccessToken(completion: @escaping (Result<String, AuthError>) -> Void) {
        tokenQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            guard !self.isRefreshingToken else { return }
            self.isRefreshingToken = true
            
            guard let refreshToken = self.refreshToken else {
                self.isRefreshingToken = false
                return completion(.failure(.missingRefreshToken))
            }
            
            guard let url = URL(string: Constants.tokenAPIURL) else {
                self.isRefreshingToken = false
                return completion(.failure(.invalidURL))
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.setValue(self.basicAuthHeader, forHTTPHeaderField: "Authorization")
            request.httpBody = "grant_type=refresh_token&refresh_token=\(refreshToken)".data(using: .utf8)
            
            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                defer { self?.isRefreshingToken = false }
                
                if let error = error {
                    self?.handleRefreshCompletion(result: .failure(.networkError(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self?.handleRefreshCompletion(result: .failure(.invalidResponse))
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    self?.handleRefreshCompletion(result: .failure(.serverError(statusCode: httpResponse.statusCode)))
                    return
                }
                
                guard let data = data else {
                    self?.handleRefreshCompletion(result: .failure(.noData))
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(AuthResponse.self, from: data)
                    self?.cacheTokens(response: response)
                    self?.handleRefreshCompletion(result: .success(response.access_token))
                } catch {
                    self?.handleRefreshCompletion(result: .failure(.decodingError(error)))
                }
            }.resume()
        }
    }
    
    // MARK: - Private Helpers
    private var basicAuthHeader: String {
        guard let data = "\(Constants.clientID):\(Constants.clientSecret)".data(using: .utf8) else {
            return ""
        }
        return "Basic \(data.base64EncodedString())"
    }
    
    private func tokenRequestBody(code: String) -> Data? {
        let queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: Constants.redirectURI)
        ]
        var components = URLComponents()
        components.queryItems = queryItems
        return components.percentEncodedQuery?.data(using: .utf8)
    }
    
    private func cacheTokens(response: AuthResponse) {
        KeychainHelper.shared.save(response.access_token, service: KeychainService.accessToken.rawValue)
        
        if let refreshToken = response.refresh_token {
            KeychainHelper.shared.save(refreshToken, service: KeychainService.refreshToken.rawValue)
        }
        
        let expirationDate = Date().addingTimeInterval(TimeInterval(response.expires_in))
        KeychainHelper.shared.save(expirationDate, service: KeychainService.expirationDate.rawValue)
    }
    
    private func handleRefreshCompletion(result: Result<String, AuthError>) {
        tokenQueue.async(flags: .barrier) { [weak self] in
            self?.onRefreshTokenBlocks.forEach { $0(result) }
            self?.onRefreshTokenBlocks.removeAll()
        }
    }
}


extension TimeInterval {
    func bridgeToDate() -> Date {
        Date(timeIntervalSinceReferenceDate: self)
    }
}

// MARK: - Error Handling
enum AuthError: Error, LocalizedError {
    case invalidURL
    case noData
    case invalidResponse
    case serverError(statusCode: Int)
    case networkError(Error)
    case decodingError(Error)
    case missingToken
    case missingRefreshToken
    case tokenRefreshFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API endpoint URL"
        case .noData:
            return "No data received from server"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let code):
            return "Server error (status code: \(code))"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Data decoding error: \(error.localizedDescription)"
        case .missingToken:
            return "Authentication token is missing"
        case .missingRefreshToken:
            return "Refresh token is missing"
        case .tokenRefreshFailed:
            return "Failed to refresh access token"
        }
    }
}
