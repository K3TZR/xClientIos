//
//  WanManager.swift
//  xClientIos
//
//  Created by Douglas Adams on 5/5/20.
//  Copyright © 2020 Douglas Adams. All rights reserved.
//

import UIKit
import SwiftUI
import xLib6000
import JWTDecode

public final class WanManager: WanServerDelegate {
    // ----------------------------------------------------------------------------
    // MARK: - Static properties
    
    static let kServiceName = ".oauth-token"
    static let testTimeout: TimeInterval = 0.1

    static let kDomain          = "https://frtest.auth0.com/"
    static let kClientId        = "4Y9fEIIsVYyQo5u6jr7yBWc4lV5ugC2m"
    static let kRedirect        = "https://frtest.auth0.com/mobile"
    static let kResponseType    = "token"
    static let kScope           = "openid%20offline_access%20email%20given_name%20family_name%20picture"

    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private weak var _serverDelegate: WanServerDelegate?
    private weak var _radioManager: RadioManager?
    
    private var _appName            = ""
    private let _log                = Logger.sharedInstance.logMessage
    private var _wanServer: WanServer?
    public var previousIdToken: IdToken?
    private var _requestDict = [String: String]()
    private var _state: String {String.random(length: 16)}
    private let _tokenStore: TokenStore

    // constants
    private let kApplicationJson    = "application/json"
    private let kAuth0Delegation    = "https://frtest.auth0.com/delegation"
    private let kClaimEmail         = "email"
    private let kClaimPicture       = "picture"
    private let kGrantType          = "urn:ietf:params:oauth:grant-type:jwt-bearer"
    private let kHttpHeaderField    = "content-type"
    private let kHttpPost           = "POST"
    private let kScope              = "openid email given_name family_name picture"
    
    private let kKeyClientId        = "client_id"       // dictionary keys
    private let kKeyGrantType       = "grant_type"
    private let kKeyIdToken         = "id_token"
    private let kKeyRefreshToken    = "refresh_token"
    private let kKeyScope           = "scope"
    private let kKeyTarget          = "target"
    
    private let kPlatform           = "macOS"

    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    init(radioManager: RadioManager) {
        _radioManager = radioManager
        _appName = (Bundle.main.infoDictionary!["CFBundleName"] as! String)
        _tokenStore = TokenStore(service: _appName + WanManager.kServiceName)
        _wanServer = WanServer(delegate: self)
    
        _requestDict = [kKeyClientId: WanManager.kClientId,
                        kKeyGrantType: kGrantType,
                        kKeyRefreshToken: "",
                        kKeyTarget: WanManager.kClientId,
                        kKeyScope: kScope]
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    /// Open a connection to the SmartLink server using existing credentials
    /// - Parameter auth0Email:     saved email (if any)
    ///
    public func smartlinkLogin(_ userEmail: String?) -> Bool {
        // is there an Id Token available?
        if let idToken = getIdToken(userEmail) {
            // YES, save the ID Token
            previousIdToken = idToken
            
            if isValidIdToken(idToken) {
                _log("WanManager, SmartlinkLogin: ID Token found", .debug, #function, #file, #line)
                
                // try to connect
                return _wanServer!.connect(appName: _appName, platform: kPlatform, idToken: idToken)
            }
        }
        // NO, user will need to reenter Auth0 user/pwd to authenticate (i.e. obtain credentials)
        _log("WanManager, SmartlinkLogin: ID Token NOT found", .debug, #function, #file, #line)
        return false
    }
    
    /// Close the connection to the SmartLink server
    ///
    public func smartlinkLogout() {
        _wanServer?.disconnect()
        _wanServer = nil
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - INternal methods
    
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
    /// - Parameter packet:   the packet of the targeted Radio
    ///
    func sendTestConnection(for serialNumber: String) {
        _wanServer?.sendTestConnection(for: serialNumber)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Obtain an Id Token from previous credentials
    /// - Parameter userEmail:      saved email (if any)
    /// - Returns:                  an ID Token (if any)
    ///
    private func getIdToken(_ userEmail: String?) -> IdToken {
        // is there a saved Auth0 token which has not expired?
        if let previousToken = previousIdToken, isValidIdToken(previousToken) {
            // YES, use the saved token
            return previousToken
            
        } else if userEmail != nil {
            // use it to obtain a refresh token from Keychain
            if let refreshToken = _tokenStore.get(account: userEmail!) {
                // can we get an ID Token using the Refresh Token?
                if let idToken = requestIdToken(from: refreshToken) {
                    // YES,
                    return idToken
                    
                } else {
                    // NO, the Keychain entry is no longer valid, delete it
                    _ = _tokenStore.delete(account: userEmail!)
                }
            }
        }
        return nil
    }
    
    /// Give a claim, retrieve the gravatar image
    /// - Parameter claimString:    a "picture" claim string
    /// - Returns:                  the image
    ///
    private func getImage(_ claimString: String?) -> UIImage {
        if let urlString = claimString, let url = URL(string: urlString) {
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                return image
            }
        }
        return UIImage( systemName: "person.fill")!
    }
    
    /// Validate an Id Token
    /// - Parameter idToken:        the Id Token
    /// - Returns:                  nil if valid, else a ValidationError
    ///
    private func isValidIdToken(_ idToken: IdToken) -> Bool {
        guard idToken != nil else { return false }
        
        do {
            // attempt to decode it
            let jwt = try decode(jwt: idToken!)
            // is it valid?
            let result = IDTokenValidation(issuer: WanManager.kDomain, audience: WanManager.kClientId).validate(jwt)
            if result == nil {
                _radioManager?.delegate.smartlinkAuth0Email = jwt.claim(name: kClaimEmail).string!
                _radioManager?.smartlinkImage = getImage(jwt.claim(name: kClaimPicture).string)
                return true
                
            } else {
                var explanation = ""
                
                switch result {
                case .expired:                  explanation = "expired"
                case .invalidClaim(let claim):  explanation = "invalid claim - \(claim)"
                case .nonce:                    explanation = "nonce"
                case .none:                     explanation = "nil token"
                }
                _log("WanManager, isValidIdToken: Id Token INVALID - \(explanation)", .error, #function, #file, #line)
                return false
            }
        } catch {
            _log("WanManager, isValidIdToken: error decoding Id Token", .error, #function, #file, #line)
            return false
        }
    }

    /// Given a Refresh Token, perform a URLRequest for an ID Token
    /// - Parameter refreshToken:     a Refresh Token
    /// - Returns:                    the Data (if created)
    ///
    private func requestIdToken(from refreshToken: String) -> IdToken {
        // build a URL Request
        var urlRequest = URLRequest(url: URL(string: kAuth0Delegation)!)
        urlRequest.httpMethod = kHttpPost
        urlRequest.addValue(kApplicationJson, forHTTPHeaderField: kHttpHeaderField)
                
        // add the Refresh Token to the dictionary
        _requestDict[kKeyRefreshToken] = refreshToken
        
        // try to obtain the data
        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: _requestDict)
            // update the URL Request and retrieve the data
            let (responseData, error) = URLSession.shared.synchronousDataTask(with: urlRequest)
            
            guard let jsonData = responseData, error == nil else {
                _log("WanManager, Error retrieving ID Token from Refresh Token: \(error?.localizedDescription ?? "")", .error, #function, #file, #line)
                return nil
            }
            do {
                // try to parse
                if let object = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                    // YES, does it have a Token?
                    if let  idToken = object[kKeyIdToken] as? String {
                        // YES, validate it
                        if isValidIdToken(idToken) { return idToken }
                        return nil  // invalid token
                    }
                }
                _log("WanManager, Unable to parse Refresh Token response", .error, #function, #file, #line)
                return nil          // unable to parse
            } catch _ {
                _log("WanManager, Unable to parse Refresh Token response", .error, #function, #file, #line)
                return nil          // parse error
            }
        } catch {
            fatalError("WanManager: failed to create JSON data")
        }
    }
    
    /// Given a Refresh Token attempt to get a Token
    /// - Parameter refreshToken:         a Refresh Token
    /// - Returns:                        a Token (if any)
    ///
    private func getTokenValue(from refreshToken: String) -> IdToken? {
        guard refreshToken != "" else { return nil }
        
        // build a URL Request
        let url = URL(string: kAuth0Delegation)
        var urlRequest = URLRequest(url: url!)
        urlRequest.httpMethod = kHttpPost
        urlRequest.addValue(kApplicationJson, forHTTPHeaderField: kHttpHeaderField)
        
        // guard that body data was created
        guard let bodyData = createBodyData(refreshToken: refreshToken) else { return "" }
        
        // update the URL Request and retrieve the data
        urlRequest.httpBody = bodyData
        let (responseData, error) = URLSession.shared.synchronousDataTask(with: urlRequest)
        
        // guard that the data isn't empty and that no error occurred
        guard let data = responseData, error == nil else {
            _log("WanManager, getTokenValue: error retrieving Id Token from Refresh Token - \(error?.localizedDescription ?? "")", .debug,  #function, #file, #line)
            return nil
        }
        do {
            // was something returned?
            if let parseJSON = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                // YES, does it have a Token?
                if let  idToken = parseJSON[kKeyIdToken] as? String {
                    // YES, retutn it
                    return idToken
                }
            }
            // nothing returned
            return nil
            
        } catch _ {
            // parse error
            return nil
        }
    }
    
    /// Create the Body Data for use in a URLSession
    /// - Parameter refreshToken:     a Refresh Token
    /// - Returns:                    the Data (if created)
    ///
    private func createBodyData(refreshToken: String) -> Data? {
        guard refreshToken != "" else { return nil }
        
        // create & populate the dictionary
        var dict = [String : String]()
        dict[kKeyClientId] = WanManager.kClientId
        dict[kKeyGrantType] = kGrantType
        dict[kKeyRefreshToken] = refreshToken
        dict[kKeyTarget] = WanManager.kClientId
        dict[kKeyScope] = WanManager.kScope
        
        // try to obtain the data
        do {
            let data = try JSONSerialization.data(withJSONObject: dict)
            // success
            return data
            
        } catch _ {
            // failure
            return nil
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Auth0Delegate methods
    
    /// Receives the ID and Refresh token from the Auth0 login
    /// - Parameters:
    ///   - idToken:        id Token string
    ///   - refreshToken:   refresh Token string
    ///
    func processAuth0Tokens(idToken: IdToken, refreshToken: String) {
        if isValidIdToken(idToken) {
            // save the Refresh Token
            if _tokenStore.set(account: _radioManager!.delegate.smartlinkAuth0Email!, data: refreshToken) == false {
                // log the error & exit
                _log("WanManager, processAuth0Tokens: error saving token", .warning,  #function, #file, #line)
            }
            // save id token
            previousIdToken = idToken
        } else {
            _log("WanManager, processAuth0Tokens: token INVALID", .debug,  #function, #file, #line)
            return
        }
    }
    
    /// Close the Auth0 sheet
    ///
    func closeAuth0LoginView() {
        _radioManager!.wkWebView = nil
        
        // use the saved tokens to do a SmartLink Login
        _radioManager!.smartlinkLogin()
   }
    
    // ----------------------------------------------------------------------------
    // MARK: - WanServerDelegate methods
    
    /// Receives the SmartLink UserName and Callsign from the WanServer
    /// - Parameters:
    ///   - name:       the SmartLInk User name
    ///   - call:       the SmartLink Callsign
    ///
    public func wanUserSettings(name: String, call: String) {
        DispatchQueue.main.async{ [self] in
            _radioManager!.smartlinkName = name
            _radioManager!.smartlinkCallsign =  call
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
        _radioManager!.smartlinkTestResults(status: status, msg: msg)
    }
}

