//
//  AuthResponse.swift
//  Spotify
//
//  Created by Amar Choudhary on 19/4/25.
//

import Foundation

struct AuthResponse: Codable {
    let access_token: String
    let token_type: String
    let scope: String
    let expires_in: Int
    let refresh_token: String?
}
