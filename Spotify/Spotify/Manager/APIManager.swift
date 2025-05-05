//
//  APIManager.swift
//  Spotify
//
//  Created by Amar Choudhary on 17/4/25.
//

import Foundation
import Security

final class APIManager {
    
    static let shared = APIManager()
    
    private init() {}
    
    struct Constants {
        static let baseAPIURL = "https://api.spotify.com/v1"
    }
    
    public func getCurrentUserProfile(completion: @escaping (Result<UserProfileModel, Error>) -> Void) {
        createRequest(with: URL(string: Constants.baseAPIURL + "/me"),
                     type: .GET) { baseRequest in
           
       }
    }
    
    enum HTTPMethod: String {
        case GET
        case POST
    }
    
    private func createRequest(with url: URL?,
                               type: HTTPMethod,
                               completion: @escaping (URLRequest) -> Void) {
        AuthManager.shared.withValidToken { token in
            guard let apiURL = url else {
                return
            }
            var request = URLRequest(url: apiURL)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.httpMethod = type.rawValue
            request.timeoutInterval = 30
            completion(request)
        }
    }
}
