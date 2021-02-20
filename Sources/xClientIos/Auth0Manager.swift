//
//  Auth.swift
//  TestAuth0
//
//  Created by Douglas Adams on 1/13/21.
//

import UIKit
import SwiftUI
import Auth0
import JWTDecode


public typealias IdToken = String

final class Auth0Manager : ObservableObject {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    @Published public var userImage = UIImage(systemName: "person.circle")!
    
    public var clientInfo: (clientId: String, domain: String)!
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private let kScope = "openid profile offline_access email given_name family_name picture"
    private let kRealm = "Username-Password-Authentication"
    private let kIssuer = "https://frtest.auth0.com/"
    private let kAudience = "4Y9fEIIsVYyQo5u6jr7yBWc4lV5ugC2m"
    
    private let kLoggingEnabled = false
    
    private lazy var _state = String.random(length: 16)
    private lazy var _credentialsManager = CredentialsManager(authentication: Auth0.authentication(bundle: Bundle.module))
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    init() {
        clientInfo = self.plistValues(bundle: Bundle.module)
        guard clientInfo != nil else { fatalError("Auth0.plist not found or invalid") }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    /// Attempt to retrieve a valid Id Token
    /// - Returns:      an ID Token or nil
    ///
    public func getIdToken() -> IdToken? {
        // try to use last known ID Token
        if let idToken = getValidIdToken() {
            return idToken
        } else
        // otherwise try to use the last known refreshToken
        if let idToken = authenticateWithRefreshToken() {
            return idToken
        }
        // unable to obtain an ID Token
        return nil
    }
    
    /// Obtain an Id Token from the Auth0 server using a UserId and a Password
    /// - Parameters:
    ///   - user:       user name
    ///   - pwd:        password
    /// - Returns:      an ID Token or nil
    ///
    public func authenticateWith(user: String, pwd: String, handler: @escaping (Auth0.Result<Credentials>) -> Void) {
        
        setUserImage()
        
        // log in with User ID & Password
        Auth0
            .authentication(bundle: Bundle.module)
            .logging(enabled: kLoggingEnabled)
            .login(usernameOrEmail: user,
                   password: pwd,
                   realm: kRealm,
                   scope: kScope,
                   parameters: ["state":_state])
            .start { [self] result in
                switch result {
                case .success(let credentials):
                    storeCredentials(credentials)
                    getUserImage(from: credentials.idToken)
                    
                case .failure:
                    clearCredentials()
                }
                handler(result)
            }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Retrieve a saved Id Token which has not yet expired (if any)
    ///
    private func getValidIdToken() -> IdToken? {

        let idToken = retrieveCredentials()?.idToken
        getUserImage(from: idToken)
        return isValid(idToken: idToken)
    }
    
    /// Obtain an Id Token from the Auth0 server using a Refresh Token
    /// - Returns:      an ID Token or nil
    ///
    private func authenticateWithRefreshToken() -> IdToken? {
        
        setUserImage()
        
        let refreshToken = retrieveCredentials()?.refreshToken
        guard refreshToken != nil else { return nil }

        // log in with RefreshTokend
        Auth0
            .authentication(bundle: Bundle.module)
            .logging(enabled: kLoggingEnabled)
            .renew(withRefreshToken: refreshToken!)
            .start { [self] result in
                switch result {
                case .success(let credentials):
                    storeCredentials(credentials)
                    getUserImage(from: credentials.idToken)
                    
                case .failure:
                    clearCredentials()
                }
            }
        return retrieveCredentials()?.idToken
    }
    
    /// Store Credentials
    /// - Parameter credentials: an Auth0.Credentials
    ///
    private func storeCredentials(_ credentials: Auth0.Credentials) {
        if !_credentialsManager.store(credentials: credentials) { fatalError("CredentialsManager: Unable to store Credentials") }
    }

    /// Retrieve all credentials
    /// - Returns:      a Credentials struct or nil
    ///
    private func retrieveCredentials() -> Auth0.Credentials? {
        var credentials : Auth0.Credentials? = nil

        _credentialsManager.credentials { error, creds in
            if let creds = creds {
                credentials = creds
            }
        }
        return credentials
    }
    
    /// Clear Credentials
    ///
    private func clearCredentials() {
        if !_credentialsManager.clear() { fatalError("CredentialsManager: Unable to store Credentials") }
    }

    /// Retrieve the user image from an Id Token
    /// - Parameter idToken: an Id Token
    ///
    private func getUserImage(from idToken: IdToken?) {
        if let idToken = idToken {
            
            if let jwt = try? decode(jwt: idToken) {
                
                if let urlString = jwt.body["picture"] as? String {
                    if let url = URL(string: urlString) {
                        
                        URLSession.shared.dataTask(with: url) { data, response, error in
                            if let data = data, data.count > 0 {
                                self.setUserImage( UIImage(data: data))
                            }
                        }.resume()
                    }
                }
            } else {
                setUserImage(nil)
            }
        } else {
            setUserImage(nil)
        }
    }

    /// Decode an IdToken and validate it
    /// - Parameter idToken:    an Id Token
    /// - Returns:              an IdToken or nil
    ///
    private func isValid(idToken: String?) -> IdToken? {
        guard idToken != nil else { return nil }
        
        if let jwt = try? decode(jwt: idToken!) {
            if isValid(jwt: jwt) { return idToken }
        }
        return nil
    }
    
    /// check if a JWT token is valid
    /// - Parameter jwt:        a JWT token
    /// - Returns:              valid / invalid
    ///
    private func isValid(jwt: JWT) -> Bool {
        // see: https://auth0.com/docs/tokens/id-token#validate-an-id-token
        // validate only the claims
        
        // 1.
        // Token expiration: The current date/time must be before the expiration date/time listed in the exp claim (which
        // is a Unix timestamp).
        guard let expiresAt = jwt.expiresAt, Date() < expiresAt else { return false }
        
        // 2.
        // Token issuer: The iss claim denotes the issuer of the JWT. The value must match the the URL of your Auth0
        // tenant. For JWTs issued by Auth0, iss holds your Auth0 domain with a https:// prefix and a / suffix:
        // https://YOUR_AUTH0_DOMAIN/.
        var claim = jwt.claim(name: "iss")
        guard let domain = claim.string, domain == clientInfo?.domain else { return false }
        
        // 3.
        // Token audience: The aud claim identifies the recipients that the JWT is intended for. The value must match the
        // Client ID of your Auth0 Client.
        claim = jwt.claim(name: "aud")
        guard let clientId = claim.string, clientId == clientInfo?.clientId else { return false }
        
        return true
    }
    
    /// Populate / reset the User image
    /// - Parameter image:      a UIImage (if any)
    ///
    private func setUserImage(_ image: UIImage? = nil) {
        DispatchQueue.main.async { [self] in
            if image == nil {
                userImage = UIImage(systemName: "person.circle")!
            } else {
                userImage = image!
            }
        }
    }
    
    /// Validate the Auth0.plist
    /// - Parameter bundle:     a bundle (defaults to main)
    /// - Returns:              clientInfo Tuple
    ///
    private func plistValues(bundle: Bundle = Bundle.main) -> (clientId: String, domain: String)? {
        guard
            let path = bundle.path(forResource: "Auth0", ofType: "plist"),
            let values = NSDictionary(contentsOfFile: path) as? [String: Any]
        else {
            return nil
        }

        guard
            let clientId = values["ClientId"] as? String,
            let domain = values["Domain"] as? String
        else {
            return nil
        }
        return (clientId: clientId, domain: domain)
    }
}

// ----------------------------------------------------------------------------
// MARK: - Extentions

//extension String {
//    
//    /// Retrun a random collection of character as a String
//    /// - Parameter length:     the desired number of characters
//    /// - Returns:              a String of the requested length
//    ///
//    static func random(length:Int)->String{
//        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
//        var randomString = ""
//        
//        while randomString.utf8.count < length{
//            let randomLetter = letters.randomElement()
//            randomString += randomLetter?.description ?? ""
//        }
//        return randomString
//    }
//}
