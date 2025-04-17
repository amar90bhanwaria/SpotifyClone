//
//  AuthViewController.swift
//  Spotify
//
//  Created by Amar Choudhary on 17/4/25.
//

import UIKit
import WebKit

class AuthViewController: UIViewController {

    // MARK: - UI Components
    private let webView: WKWebView = {
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true // Enable JavaScript for OAuth flow
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences = preferences
        return WKWebView(frame: .zero, configuration: configuration)
    }()
    
    // MARK: - Properties
    public var completionHandler: ((Bool) -> Void)?
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        loadSignInPage()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        webView.frame = view.bounds
    }
}

// MARK: - Setup Methods
extension AuthViewController {
    private func setupView() {
        view.backgroundColor = .systemBackground
        title = "Sign In"
        webView.navigationDelegate = self
        view.addSubview(webView)
    }
    
    private func loadSignInPage() {
        guard let url = AuthManager.shared.signInURL else {
            return
        }
        
        webView.load(URLRequest(url: url))
    }
}

// MARK: - WKNavigationDelegate
extension AuthViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        guard let url = webView.url else { return }
        handlePotentialRedirect(url: url)
    }
    
    private func handlePotentialRedirect(url: URL) {
        // Ensure this is our redirect URL
        guard url.absoluteString.hasPrefix(AuthManager.Constants.redirectURI) else { return }
        
        // Extract authorization code from URL query parameters
        let components = URLComponents(string: url.absoluteString)
        guard let code = components?.queryItems?.first(where: { $0.name == "code" })?.value else {
            completionHandler?(false)
            return
        }
        
        // Exchange authorization code for access token
        AuthManager.shared.exchangeCodeForToken(code: code) { [weak self] success in
            DispatchQueue.main.async {
                self?.completionHandler?(success)
                self?.navigationController?.popViewController(animated: true)
            }
        }
    }
}
