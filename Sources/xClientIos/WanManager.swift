//
//  WanManager.swift
//  xClientIos
//
//  Created by Douglas Adams on 5/5/20.
//  Copyright © 2020 Douglas Adams. All rights reserved.
//

import UIKit
import xLib6000
import JWTDecode

public struct Token {
    var value         : String
    var expiresAt     : Date
    
    public func isValidAtDate(_ date: Date) -> Bool {
        return (date < self.expiresAt)
    }
}

public final class WanManager : WanServerDelegate {
    
    // ----------------------------------------------------------------------------
    // MARK: - Static properties
    
    static let kServiceName                   = ".oauth-token"
    static let testTimeout                    : TimeInterval = 0.1
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var auth0UrlString                        : String = ""
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private weak var _serverDelegate          : WanServerDelegate?
    private weak var _radioManager            : RadioManager?
    
    private var _appName                      = ""
    private let _log                          = Logger.sharedInstance.logMessage
    private var _wanServer                    : WanServer?
    private var _previousToken                : Token?
    private var _state                        : String {String.random(length: 16)}
//    private let _tokenStore                   : TokenStore
    
    // constants
    private let kApplicationJson              = "application/json"
    private let kAuth0Delegation              = "https://frtest.auth0.com/delegation"
    private let kClaimEmail                   = "email"
    private let kClaimPicture                 = "picture"
    private let kConnectTitle                 = "Connect"
    private let kDisconnectTitle              = "Disconnect"
    private let kGrantType                    = "urn:ietf:params:oauth:grant-type:jwt-bearer"
    private let kHttpHeaderField              = "content-type"
    private let kHttpPost                     = "POST"
    
    private let kKeyClientId                  = "client_id"                   // dictionary keys
    private let kKeyGrantType                 = "grant_type"
    private let kKeyIdToken                   = "id_token"
    private let kKeyRefreshToken              = "refresh_token"
    private let kKeyScope                     = "scope"
    private let kKeyTarget                    = "target"
    
    private let kPlatform                     = "iOS"
    private let kScope                        = "openid email given_name family_name picture"
    
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    init(radioManager: RadioManager) {
        _radioManager = radioManager
        _appName = (Bundle.main.infoDictionary!["CFBundleName"] as! String)
//        _tokenStore = TokenStore(service: _appName + WanManager.kServiceName)
        _wanServer = WanServer(delegate: self)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    /// SmartLink log in using an ID Token
    /// - Parameter idToken:     an Auth0 ID Token
    ///
    func smartLinkLogin(using idToken: String) -> Bool {
        
        return _wanServer!.connect(appName: _appName, platform: kPlatform, idToken: idToken, ping: true)
    }
    
    func smartLinkLogin() -> Bool {
        
        // TODO: remove email
        
        if let idToken = _radioManager!.auth0Manager?.getIdToken() {
            // have a token, try to connect
            return _wanServer!.connect(appName: _appName, platform: kPlatform, idToken: idToken, ping: true)
        }
        
        
        
        //        if let tokenValue = getToken(using: auth0Email) {
        //            DispatchQueue.main.async { [self] in _radioManager!.smartLinkImage = getUserImage(tokenValue: tokenValue) }
        //            // have a token, try to connect
        //            return _wanServer!.connectToSmartLinkServer(appName: _appName, platform: kPlatform, token: tokenValue, ping: true)
        //        }
        //        _log("Smartlink login: token NOT found", .debug,  #function, #file, #line)
        return false
    }
    
    /// SmartLink log out
    ///
    func smartLinkLogout() {
        _wanServer?.disconnect()
        _wanServer = nil
    }
    
    /// Show the Web page for Auth0Sheet validation
    ///
    func setupAuth0Credentials() {
        // clear all cookies to prevent falling back to earlier saved login credentials
//        let storage = HTTPCookieStorage.shared
//        if let cookies = storage.cookies {
//            for index in 0..<cookies.count {
//                let cookie = cookies[index]
//                storage.deleteCookie(cookie)
//            }
//        }
//        // build the URL string
//        auth0UrlString =    """
//                            \(RadioManager.kAuth0Domain)authorize?client_id=\(RadioManager.kAuth0ClientId)\
//                            &redirect_uri=\(RadioManager.kRedirect)\
//                            &response_type=\(RadioManager.kResponseType)\
//                            &scope=\(RadioManager.kScope)\
//                            &state=\(_state)\
//                            &device=\(_appName)
//                            """
//
//        auth0UrlString =    """
//                            https://frtest.auth0.com/authorize?client_id=4Y9fEIIsVYyQo5u6jr7yBWc4lV5ugC2m\
//                            &redirect_uri=https://frtest.auth0.com/mobile\
//                            &response_type=token\
//                            &scope=openid%20offline_access%20email%20given_name%20family_name%20picture\
//                            &state=\(_state)\
//                            &device=\(_appName)
//                            """
   }
    
    /// Establish a SmartLink connection to a Radio
    /// - Parameter packet:   the packet of the targeted Radio
    ///
    func validateWanRadio(_ packet: DiscoveryPacket) {
        _wanServer?.sendConnectMessage(for: packet.serialNumber, holePunchPort: packet.negotiatedHolePunchPort)
    }
    
    /// Close the SmartLink connection to a Radio
    /// - Parameter packet:   the packet of the targeted Radio
    ///
    func closeRadio(_ packet: DiscoveryPacket) {
        _wanServer?.sendDisconnectMessage(for: packet.serialNumber)
    }
    
    /// Test the SmartLink connection to a Radio
    /// - Parameter serialNumber:   the serial number of the targeted Radio
    ///
    func sendTestConnection(for serialNumber: String) {
        _wanServer?.sendTestConnection(for: serialNumber)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Obtain a token
    /// - Parameter auth0Email:     saved email (if any)
    /// - Returns:                  a Token (if any)
    ///
//    private func getToken(using auth0Email: String) -> String? {
//        var tokenValue : String? = nil
//
//        // is there a saved Auth0 token which has not expired?
//        if let previousToken = _previousToken, previousToken.isValidAtDate( Date()) {
//            // YES, we can log into SmartLink, use the saved token
//            tokenValue = previousToken.value
//
//            _log("Smartlink login: using unexpired previous token", .debug,  #function, #file, #line)
//
//        } else if auth0Email != "" {
//
//            // there is a saved email, is there is a saved Refresh Token?
//            if let refreshToken = _tokenStore.get(account: auth0Email) {
//
//                // YES, can we get a Token Value from the Refresh Token?
//                if let value = getTokenValue(from: refreshToken) {
//                    // YES, we can use the saved token to Log in
//                    tokenValue = value
//
//                    _log("Smartlink login: using token obtained from refresh token", .debug,  #function, #file, #line)
//
//                } else {
//                    // NO, the Refresh Token is no longer valid, delete it
//                    _ = _tokenStore.delete(account: auth0Email)
//
//                    _log("Smartlink login: refresh token is invalid", .debug,  #function, #file, #line)
//                }
//            } else {
//
//                _log("Smartlink login: refresh token not found", .debug,  #function, #file, #line)
//            }
//
//        } else {
//            _log("Smartlink login: saved email is empty", .debug,  #function, #file, #line)
//        }
//        return tokenValue
//    }
//
//    /// Given a Refresh Token attempt to get a Token
//    ///
//    /// - Parameter refreshToken:         a Refresh Token
//    /// - Returns:                        a Token (if any)
//    ///
//    private func getTokenValue(from refreshToken: String) -> String? {
//
//        // guard that the refresh token isn't empty
//        guard refreshToken != "" else { return nil }
//
//        // build a URL Request
//        let url = URL(string: kAuth0Delegation)
//        var urlRequest = URLRequest(url: url!)
//        urlRequest.httpMethod = kHttpPost
//        urlRequest.addValue(kApplicationJson, forHTTPHeaderField: kHttpHeaderField)
//
//        // guard that body data was created
//        guard let bodyData = createBodyData(refreshToken: refreshToken) else { return "" }
//
//        // update the URL Request and retrieve the data
//        urlRequest.httpBody = bodyData
//        let (responseData, _, error) = URLSession.shared.synchronousDataTask(with: urlRequest)
//
//        // guard that the data isn't empty and that no error occurred
//        guard let data = responseData, error == nil else {
//
//            _log("SmartLink login: error retrieving token, \(error?.localizedDescription ?? "")", .debug,  #function, #file, #line)
//            return nil
//        }
//
//        // is there a Token?
//        if let token = parseTokenResponse(data: data) {
//            do {
//
//                let jwt = try decode(jwt: token)
//
//                // validate id token; see https://auth0.com/docs/tokens/id-token#validate-an-id-token
//                if !isJWTValid(jwt) {
//                    // log the error
//                    _log("SmartLink login: token invalid", .debug,  #function, #file, #line)
//
//                    return nil
//                }
//
//            } catch let error as NSError {
//                // log the error
//                _log("SmartLink login: error decoding token, \(error.localizedDescription)", .debug,  #function, #file, #line)
//
//                return nil
//            }
//            return token
//        }
//        // NO token
//        return nil
//    }
//
//    /// Get the Logon Image
//    /// - Parameter token:    a token value
//    /// - Returns:            the image or nil
//    ///
//    private func getUserImage( tokenValue: String) -> UIImage? {
//
//        // try to get the JSON Web Token
//        if let jwt = try? decode(jwt: tokenValue) {
//
//            // get the Log On image (if any) from the token
//            let claim = jwt.claim(name: kClaimPicture)
//            if let gravatar = claim.string, let url = URL(string: gravatar) {
//                // get the image
//                if let data = try? Data(contentsOf: url) {
//                    return UIImage(data: data)
//                }
//            }
//        }
//        return nil
//    }
//
//    /// Create the Body Data for use in a URLSession
//    ///
//    /// - Parameter refreshToken:     a Refresh Token
//    /// - Returns:                    the Data (if created)
//    ///
//    private func createBodyData(refreshToken: String) -> Data? {
//
//        // guard that the Refresh Token isn't empty
//        guard refreshToken != "" else { return nil }
//
//        // create & populate the dictionary
//        var dict = [String : String]()
//        dict[kKeyClientId] = RadioManager.kAuth0ClientId
//        dict[kKeyGrantType] = kGrantType
//        dict[kKeyRefreshToken] = refreshToken
//        dict[kKeyTarget] = RadioManager.kAuth0ClientId
//        dict[kKeyScope] = kScope
//
//        // try to obtain the data
//        do {
//
//            let data = try JSONSerialization.data(withJSONObject: dict)
//            // success
//            return data
//
//        } catch _ {
//            // failure
//            return nil
//        }
//    }
//
//    /// Parse the URLSession data
//    ///
//    /// - Parameter data:               a Data
//    /// - Returns:                      a Token (if any)
//    ///
//    private func parseTokenResponse(data: Data) -> String? {
//
//        do {
//            // try to parse
//            let myJSON = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
//
//            // was something returned?
//            if let parseJSON = myJSON {
//
//                // YES, does it have a Token?
//                if let  idToken = parseJSON[kKeyIdToken] as? String {
//                    // YES, retutn it
//                    return idToken
//                }
//            }
//            // nothing returned
//            return nil
//
//        } catch _ {
//            // parse error
//            return nil
//        }
//    }
//
//    /// check if a JWT token is valid
//    ///
//    /// - Parameter jwt:                  a JWT token
//    /// - Returns:                        valid / invalid
//    ///
//    private func isJWTValid(_ jwt: JWT) -> Bool {
//        // see: https://auth0.com/docs/tokens/id-token#validate-an-id-token
//        // validate only the claims
//
//        // 1.
//        // Token expiration: The current date/time must be before the expiration date/time listed in the exp claim (which
//        // is a Unix timestamp).
//        guard let expiresAt = jwt.expiresAt, Date() < expiresAt else { return false }
//
//        // 2.
//        // Token issuer: The iss claim denotes the issuer of the JWT. The value must match the the URL of your Auth0
//        // tenant. For JWTs issued by Auth0, iss holds your Auth0 domain with a https:// prefix and a / suffix:
//        // https://YOUR_AUTH0_DOMAIN/.
//        var claim = jwt.claim(name: "iss")
//        guard let domain = claim.string, domain == RadioManager.kAuth0Domain else { return false }
//
//        // 3.
//        // Token audience: The aud claim identifies the recipients that the JWT is intended for. The value must match the
//        // Client ID of your Auth0 Client.
//        claim = jwt.claim(name: "aud")
//        guard let clientId = claim.string, clientId == RadioManager.kAuth0ClientId else { return false }
//
//        return true
//    }
//
//    // ----------------------------------------------------------------------------
//    // MARK: - Auth0Delegate methods
//
//    /// Receives the ID and Refresh token from the Auth0 login
//    ///
//    /// - Parameters:
//    ///   - idToken:        id Token string
//    ///   - refreshToken:   refresh Token string
//    ///
//    func processAuth0Tokens(idToken: String, refreshToken: String) {
//        var expireDate = Date()
//
//        do {
//            // try to get the JSON Web Token
//            let jwt = try decode(jwt: idToken)
//
//            // validate id token; see https://auth0.com/docs/tokens/id-token#validate-an-id-token
//            if !isJWTValid(jwt) {
//                _log("SmartLink login: token INVALID", .debug,  #function, #file, #line)
//                return
//            }
//            // save the Log On email (if any)
//            var claim = jwt.claim(name: kClaimEmail)
//            if let email = claim.string {
//
//                // YES, save it
//                _radioManager!.delegate.smartLinkAuth0Email = email
//
//                // save the Refresh Token
//                if _tokenStore.set(account: email, data: refreshToken) == false {
//                    // log the error & exit
//                    _log("SmartLink login: error saving token", .warning,  #function, #file, #line)
//                }
//            }
//            // save the Log On picture (if any)
//            claim = jwt.claim(name: kClaimPicture)
//            if let gravatar = claim.string, let url = URL(string: gravatar) {
//                // get the image
//                if let data = try? Data(contentsOf: url) {
//                    DispatchQueue.main.async { [self] in _radioManager!.smartLinkImage = UIImage(data: data) }
//                }
//            }
//            // get the expiry date (if any)
//            if let expiresAt = jwt.expiresAt {
//                expireDate = expiresAt
//            }
//
//        } catch let error as NSError {
//            // log the error & exit
//            _log("SmartLink login: error decoding token, \(error.localizedDescription)", .debug,  #function, #file, #line)
//            return
//        }
//        // save id token with expiry date
//        _previousToken = Token(value: idToken, expiresAt: expireDate)
//
//        //    _radioManager!.delegate.smartLinkLoginState(true)
//    }
//
//    /// Close the Auth0 sheet
//    ///
//    func closeAuth0LoginView() {
//        _radioManager!.showAuth0(false)
//
//        // use the saved tokens to do a SmartLink Login
//        _radioManager!.smartLinkLogin()
//
//        // display the RadioPicker
//        _radioManager!.showPicker()
//    }
    
    // ----------------------------------------------------------------------------
    // MARK: - WanServerDelegate methods
    
    /// Receives the SmartLink UserName and Callsign from the WanServer
    /// - Parameters:
    ///   - name:       the SmartLInk User name
    ///   - call:       the SmartLink Callsign
    ///
    public func wanUserSettings(name: String, call: String) {
        DispatchQueue.main.async{ [self] in
            _radioManager!.smartLinkName = name
            _radioManager!.smartLinkCallsign =  call
        }
    }
    
    /// Receives the Wan Handle from the WanServer
    /// - Parameters:
    ///   - handle:     the Wan handle
    ///   - serial:     the serial number of the Radio
    ///
    public func wanRadioConnectReady(handle: String, serial: String) {
        for (i, packet) in Discovery.sharedInstance.discoveryPackets.enumerated() where packet.serialNumber == serial && packet.isWan {
            Discovery.sharedInstance.discoveryPackets[i].wanHandle = handle
            _radioManager!.openRadio(_radioManager!.packets[i])
        }
    }
    
    /// Receives the SmartLink test results from the WanServer
    /// - Parameter results:    the test results
    ///
    public func wanTestResultsReceived(results: WanTestConnectionResults) {
        // assess the result
        let status = (results.forwardTcpPortWorking == true &&
                        results.forwardUdpPortWorking == true &&
                        results.upnpTcpPortWorking == false &&
                        results.upnpUdpPortWorking == false &&
                        results.natSupportsHolePunch  == false) ||
            
            (results.forwardTcpPortWorking == false &&
                results.forwardUdpPortWorking == false &&
                results.upnpTcpPortWorking == true &&
                results.upnpUdpPortWorking == true &&
                results.natSupportsHolePunch  == false)
        
        let msg =
                """
                Forward Tcp Port:  \(results.forwardTcpPortWorking)
                Forward Udp Port:  \(results.forwardUdpPortWorking)
                UPNP Tcp Port:     \(results.upnpTcpPortWorking)
                UPNP Udp Port:     \(results.upnpUdpPortWorking)
                Nat Hole Punch:    \(results.natSupportsHolePunch)
                """
        _radioManager!.smartLinkTestResults(status: status, msg: msg)
    }
}

