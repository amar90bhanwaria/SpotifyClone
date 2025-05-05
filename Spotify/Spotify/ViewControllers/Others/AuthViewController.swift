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
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        return WKWebView(frame: .zero, configuration: configuration)
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    // MARK: - Properties
    public var completionHandler: ((Result<Bool, AuthError>) -> Void)?
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        loadSignInPage()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        webView.frame = view.bounds
        loadingIndicator.center = view.center
    }
}

// MARK: - Setup Methods
private extension AuthViewController {
    func setupView() {
        view.backgroundColor = .systemBackground
        title = "Sign In"
        configureWebView()
        setupLoadingIndicator()
    }
    
    func configureWebView() {
        webView.navigationDelegate = self
        view.addSubview(webView)
    }
    
    func setupLoadingIndicator() {
        view.addSubview(loadingIndicator)
        loadingIndicator.startAnimating()
    }
    
    func loadSignInPage() {
        guard let url = AuthManager.shared.signInURL else {
            presentErrorAlert(message: "Failed to create authentication URL")
            return
        }
        
        webView.load(URLRequest(url: url))
    }
}

// MARK: - WKNavigationDelegate
extension AuthViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        if isRedirectURL(url) {
            handleAuthorizationRedirect(url: url)
            decisionHandler(.cancel)
            return
        }
        
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadingIndicator.stopAnimating()
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        loadingIndicator.stopAnimating()
        handleNavigationError(error)
    }
}

// MARK: - Authorization Handling
private extension AuthViewController {
    
    func isRedirectURL(_ url: URL) -> Bool {
        guard let redirectURL = URL(string: AuthManager.Constants.redirectURI),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let redirectComponents = URLComponents(url: redirectURL, resolvingAgainstBaseURL: true) else {
            return false
        }
        
        return components.scheme == redirectComponents.scheme &&
        components.host == redirectComponents.host &&
        components.path == redirectComponents.path
    }
    
    
    func handleAuthorizationRedirect(url: URL) {
        guard let code = extractAuthorizationCode(from: url) else {
            completionHandler?(.failure(.invalidURL))
            dismissViewController()
            return
        }
        
        startTokenExchange(code: code)
    }
    
    func extractAuthorizationCode(from url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: true)?
            .queryItems?
            .first { $0.name == "code" }?
            .value
    }
    
    func startTokenExchange(code: String) {
        loadingIndicator.startAnimating()
        
        // Delay hiding to give WebView time to clean up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.webView.isHidden = true
        }
        
        AuthManager.shared.exchangeCodeForToken(code: code) { [weak self] result in
            DispatchQueue.main.async {
                self?.loadingIndicator.stopAnimating()
                self?.handleTokenExchangeResult(result)
            }
        }
    }
    
    func handleTokenExchangeResult(_ result: Result<Bool, AuthError>) {
        switch result {
        case .success:
            completionHandler?(.success(true))
        case .failure(let error):
            presentErrorAlert(message: error.localizedDescription)
            completionHandler?(.failure(error))
        }
        
        // Add a short delay before dismissing to prevent WKWebView cleanup crashes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.dismissViewController()
        }
    }
}

// MARK: - UI Helpers
private extension AuthViewController {
    func dismissViewController() {
        navigationController?.popViewController(animated: true)
    }
    
    func presentErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "Authentication Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    func handleNavigationError(_ error: Error) {
        let nsError = error as NSError
        guard nsError.code != NSURLErrorCancelled else { return }
        
        presentErrorAlert(message: "Failed to load authentication page. Please check your internet connection.")
        completionHandler?(.failure(.noData))
        dismissViewController()
    }
}
