//
//  RadioManager.swift
//  xClientIos
//
//  Created by Douglas Adams on 8/23/20.
//

import Foundation
import SwiftUI
import xLib6000
import WebKit
import JWTDecode

public struct PickerPacket : Identifiable, Equatable {
    public var id         = 0
    var packetIndex       = 0
    var type: ConnectionType = .local
    var nickname          = ""
    var status: ConnectionStatus = .available
    public var stations   = ""
    var serialNumber      = ""
    var isDefault         = false
    var connectionString: String { "\(type == .wan ? "wan" : "local").\(serialNumber)" }
    
    public static func ==(lhs: PickerPacket, rhs: PickerPacket) -> Bool {
        guard lhs.serialNumber != "" else { return false }
        return lhs.connectionString == rhs.connectionString
    }
}

public enum ConnectionType: String {
    case wan
    case local
}

public enum ConnectionStatus: String {
    case available
    case inUse = "in_use"
}

public struct Station: Identifiable {
    public var id        = 0
    public var name      = ""
    public var clientId: String?
    
    public init(id: Int, name: String, clientId: String?) {
        self.id = id
        self.name = name
        self.clientId = clientId
    }
}

public struct AlertButton {
    var text = ""
    var color: UIColor?
    var action: ()->Void
    
    public init(_ text: String, _ action: @escaping ()->Void, color: UIColor? = nil) {
        self.text = text
        self.action = action
        self.color = color
    }
}

public struct AlertParams {
    public var title    = ""
    public var message  = ""
    public var buttons  = [AlertButton]()
}

public enum SheetType: Hashable, Identifiable {
    case radioPicker
    case smartlinkAuthorization
    case smartlinkStatus

    public var id: Int {
        return self.hashValue
    }
}

public protocol RadioManagerDelegate {
    var clientId: String?               {get set}
    var connectToFirstRadio: Bool       {get set}
    var defaultConnection: String?      {get set}
    var defaultGuiConnection: String?   {get set}
    var enableGui: Bool                 {get}
    var smartlinkAuth0Email: String?    {get set}
    var smartlinkEnabled: Bool          {get set}
    var smartlinkUserImage: UIImage?    {get set}
    var stationName: String             {get set}

    func willConnect()
    func willDisconnect()
    
    var activePacket: DiscoveryPacket?  {get set}
}

public final class RadioManager: ObservableObject {
    typealias connectionTuple = (type: String, serialNumber: String, station: String)
    
    // ----------------------------------------------------------------------------
    // MARK: - Static properties
    
    public static let kUserInitiated = "User initiated"
        
    // ----------------------------------------------------------------------------
    // MARK: - Public properties

    
    @Published public var defaultSelection: Int?

    
    
    @Published public var activeRadio: Radio?
    @Published public var activeSheet: SheetType?
    @Published public var alertParams = AlertParams()
    @Published public var isConnected = false
    @Published public var pickerHeading = ""
    @Published public var pickerMessages = [String]()
    @Published public var pickerSelection: Int?
    @Published public var showAlert = false
    @Published public var smartlinkCallsign = ""
    @Published public var smartlinkImage: UIImage = UIImage( systemName: "person.fill")!
    @Published public var smartlinkIsLoggedIn = false
    @Published public var smartlinkName = ""
    @Published public var smartlinkTestStatus = false
    @Published public var stationSelection = 0
    @Published public var useLowBw = false

    var auth0UrlString = ""
    public var pickerPackets = [PickerPacket]()
    public var wkWebView: WKWebView?
    
    public var currentAlert = AlertParams(title: "MultiAlert", message: "message", buttons: [AlertButton("Button", {})])
    public var delegate: RadioManagerDelegate!
    public var sheetType: SheetType = .radioPicker
    public var smartlinkTestResults: String?
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var wanManager: WanManager?
    var packets: [DiscoveryPacket] { Discovery.sharedInstance.discoveryPackets }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private var _api = Api.sharedInstance          // initializes the API
    private var _autoBind: Int? = nil
    private let _log = LogProxy.sharedInstance.logMessage
    
    private let kAvailable = "available"
    private let kInUse = "in_use"

    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    public init(delegate: RadioManagerDelegate) {
        self.delegate = delegate
        
        // start Discovery
        let _ = Discovery.sharedInstance
        
        // start listening to notifications
        addNotifications()

        // if non-Gui, is there a saved Client ID?
        if delegate.enableGui == false && delegate.clientId == "" {
            // NO, assign one
            self.delegate.clientId = UUID().uuidString
        }
        // if SmartLink enabled, are we logged in?
        if delegate.smartlinkEnabled && smartlinkIsLoggedIn == false {
            // NO, attempt to log in
            smartlinkLogin(showPicker: false)
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    /// SmartLink menu choice was clicked
    /// - Parameter enabled: enable / disable SmartLInk selected
    ///
    public func smartlink(enabled: Bool) {
        _log("Tester: SmartLink \(enabled ? "enabled" : "disabled")", .debug,  #function, #file, #line)
        delegate.smartlinkEnabled = enabled
        if enabled && !smartlinkIsLoggedIn {
            _log("Tester: SmartLink login initiated", .debug,  #function, #file, #line)
            smartlinkLogin(showPicker: false)
        } else if !enabled && smartlinkIsLoggedIn {
            _log("Tester: SmartLink logout initiated", .debug,  #function, #file, #line)
            smartlinkLogout()
        }
    }

    /// Start / Stop a connection to a Radio
    ///
    public func start() {
        // DISCONNECTED, start connection
        delegate.willConnect()
        connect()
    }
    
    public func stop() {
        // CONNECTED, Stop connection
        delegate.willDisconnect()
        disconnect()
    }

    /// Initiate a connection to a Radio in priority order
    ///
    public func connect() {
        //    Order of connection attempts:
        //      1. connect to the default (if a default is non-blank)
        //      2. otherwise, show picker
        
        // connect to default?
        if delegate.enableGui && delegate.defaultGuiConnection != nil {
            _log("RadioManager, connecting to Gui default: \(delegate.defaultGuiConnection!)", .info,  #function, #file, #line)
            connect(to: delegate.defaultGuiConnection!)
        } else if delegate.enableGui == false && delegate.defaultConnection != nil {
            _log("RadioManager, connecting to non-Gui default: \(delegate.defaultConnection!)", .info,  #function, #file, #line)
            connect(to: delegate.defaultConnection!)
        } else {
            showSheet(.radioPicker)
        }
    }

    /// Send a command to the Radio
    ///
    public func send(command: String) {
        guard command != "" else { return }
        
        // send the command to the Radio via TCP
        _api.radio!.sendCommand( command )
    }
    
    /// Initiate a connection to the Radio with the specified connection string
    /// - Parameter connection:   a connection string (in the form <type>.<serialNumber>)
    ///
    public func connect(to connectionString: String) {
        // is it a valid connection string?
        if let connectionTuple = parseConnectionString(connectionString) {
            // VALID, is there a match?
            if let index = findMatching(connectionTuple) {
                // YES, attempt a connection to it
                connect(to: index)
            } else {
                // NO, no match found
                showSheet(.radioPicker, messages: ["No match found for:", connectionString])
            }
        } else {
            // NOT VALID
            showSheet(.radioPicker, messages: [connectionString, "is an invalid connection"])        }
    }
    
    /// Initiate a connection to the Radio with the specified index
    ///   This method is called by the Picker when a selection is made and the Connect button is pressed
    ///
    /// - Parameter index:    an index into the PickerPackets array
    ///
    public func connect(to index: Int?) {
        if let index = index {
            guard delegate.activePacket == nil else { disconnect() ; return }
            
            let packetIndex = delegate.enableGui ? index : pickerPackets[index].packetIndex
            
            if packets.count - 1 >= packetIndex {
                let packet = packets[packetIndex]
                
                // if Non-Gui, schedule automatic binding
                _autoBind = delegate.enableGui ? nil : index
                
                if packet.isWan {
                    wanManager?.validateWanRadio(packet)
                } else {
                    openRadio(packet)
                }
            }
        }
    }
    
    public func showSheet(_ type: SheetType, messages: [String] = [String]()) {
        switch type {
        
        case .radioPicker:
            loadPickerPackets()
            smartlinkTestStatus = false
            pickerSelection = nil
            pickerMessages = messages
            pickerHeading = "Select a \(delegate.enableGui ? "Radio" : "Station") and click Connect"

        case .smartlinkAuthorization:
            // configure a web view (prevent token retention)
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
            wkWebView = WKWebView(frame: .zero, configuration: configuration)
            
            let state = String.random(length: 16)
            let appName = (Bundle.main.infoDictionary!["CFBundleName"] as! String)
            auth0UrlString =    """
                                \(WanManager.kDomain)authorize?client_id=\(WanManager.kClientId)\
                                &redirect_uri=\(WanManager.kRedirect)\
                                &response_type=\(WanManager.kResponseType)\
                                &scope=\(WanManager.kScope)\
                                &state=\(state)\
                                &device=\(appName)
                                """
        case .smartlinkStatus:
            break
        }
        DispatchQueue.main.async { [self] in activeSheet = type }
    }

    public func showCustomAlert(_ params: AlertParams) {
        currentAlert = params
        DispatchQueue.main.async { [self] in showAlert = true }
    }
    
    public func removeSmartLinkRadios() {
        Discovery.sharedInstance.removeSmartLinkRadios()
    }
    
    /// Disconnect the current connection
    /// - Parameter msg:    explanation
    ///
    public func disconnect(reason: String = RadioManager.kUserInitiated) {
        _log("RadioManager, disconnect: \(reason)", .info,  #function, #file, #line)
        
        // tell the library to disconnect
        _api.disconnect(reason: reason)
        
        DispatchQueue.main.async { [self] in
            // remove all Client Id's
            for (i, _) in delegate.activePacket!.guiClients.enumerated() {
                delegate.activePacket!.guiClients[i].clientId = nil
            }
            delegate.activePacket = nil
            activeRadio = nil
            stationSelection = 0
            isConnected = false
        }
        // if anything unusual, tell the user
        if reason != RadioManager.kUserInitiated {
            currentAlert = AlertParams(title: "Radio was disconnected",
                                      message: reason,
                                      buttons: [AlertButton( "Ok", {})])
            showCustomAlert(currentAlert)
        }
    }
    
    /// Show the Default Picker sheet
    ///
    public func chooseDefaults() {
        loadPickerPackets()
        var buttons = [AlertButton]()
        for packet in pickerPackets {
            let listLine = packet.nickname + " - " + packet.type.rawValue + (delegate.enableGui == false ? " - " + packet.stations : "")
            buttons.append(AlertButton(listLine, { self.selectDefault(packet) }, color: packet.isDefault ? .red : nil))
        }
        buttons.append(AlertButton( "Clear", { self.selectDefault(nil) }))
        buttons.append(AlertButton( "Cancel", {}))
        currentAlert = AlertParams(title: "Select a Default",
                                   message: "current default shown in red",
                                   buttons: buttons)
        showCustomAlert(currentAlert)
    }
    
    public func clearDefaults() {
        if delegate.enableGui {
            delegate.defaultGuiConnection = nil
        } else {
            delegate.defaultConnection = nil
        }
    }
       
    public func selectDefault(_ packet: PickerPacket?) {
        switch (packet, delegate.enableGui) {
        
        case (nil, true):   delegate.defaultGuiConnection = nil
        case (nil, false):  delegate.defaultConnection = nil
        case (_, true):     delegate.defaultGuiConnection = packet!.connectionString
        case (_, false):    delegate.defaultConnection = packet!.connectionString + "." + packet!.stations
        }
    }
    
    public func toggleSmartlink() {
        if delegate.smartlinkEnabled && smartlinkIsLoggedIn { smartlinkLogout() }
        delegate.smartlinkEnabled.toggle()
    }
    
    public func forceLogin() {
        delegate.smartlinkAuth0Email = nil
        wanManager?.previousIdToken = ""
        smartlinkLogout()
    }
    
    public func smartlinkLogin(showPicker: Bool = true) {
        // instantiate the WanManager
        if wanManager == nil { wanManager = WanManager(radioManager: self) }

        // attempt a SmartLink login using existing credentials
        if wanManager!.smartlinkLogin( delegate.smartlinkAuth0Email) {
            smartlinkIsLoggedIn = true
            if showPicker { showSheet(.radioPicker) }

        } else {
            // obtain new credentials
            showSheet(.smartlinkAuthorization)
        }
    }
    
    public func smartlinkLogout() {
        Discovery.sharedInstance.removeSmartLinkRadios()
        wanManager?.smartlinkLogout()
        wanManager = nil
        smartlinkName = ""
        smartlinkCallsign = ""
        smartlinkImage = UIImage( systemName: "person.fill")!
        smartlinkIsLoggedIn = false
    }

    /// Called when the Picker's Test button is clicked
    ///
    public func smartlinkTest() {
        guard pickerSelection != nil else { return }
        wanManager?.sendTestConnection(for: pickerPackets[pickerSelection!].serialNumber)
    }

    // ----------------------------------------------------------------------------
    // MARK: - Internal methods

    /// Receives the results of a SmartLink test
    /// - Parameters:
    ///   - status:     pass / fail
    ///   - msg:        a summary of the results
    ///
    func smartlinkTestResults(status: Bool, msg: String) {
        smartlinkTestResults = msg
        // set the indicator
        DispatchQueue.main.async { self.smartlinkTestStatus = status }
    }
    
    /// Ask the Api to disconnect a specific Client
    /// - Parameters:
    ///   - packet:         a packet describing the Client
    ///   - handle:         the Client's connection handle
    ///
    func clientDisconnect(packet: DiscoveryPacket, handle: Handle) {
        _api.requestClientDisconnect( packet: packet, handle: handle)
    }
    
    /// Determine the state of the Radio being opened and allow the user to choose how to proceed
    /// - Parameter packet:     the packet describing the Radio to be opened
    ///
    func openRadio(_ packet: DiscoveryPacket) {
        guard delegate.enableGui else {
            connectRadio(packet, isGui: delegate.enableGui, station: delegate.stationName)
            return
        }
        
        switch (Version(packet.firmwareVersion).isNewApi, packet.status.lowercased(), packet.guiClients.count) {
        
        case (false, kAvailable, _):          // oldApi, not connected to another client
            connectRadio(packet, isGui: delegate.enableGui, station: delegate.stationName)
            
        case (false, kInUse, _):              // oldApi, connected to another client
            let firstButtonAction = { [self] in
                connectRadio(packet, isGui: delegate.enableGui, pendingDisconnect: .oldApi, station: delegate.stationName)
                sleep(1)
                _api.disconnect()
                sleep(1)
                showSheet(.radioPicker)
            }
            currentAlert = AlertParams(title: "Radio is connected to another Client",
                                      message: "",
                                      buttons: [
                                        AlertButton( "Close this client", firstButtonAction ),
                                        AlertButton( "Cancel", {})
                                      ])
            showCustomAlert(currentAlert)

        case (true, kAvailable, 0):           // newApi, not connected to another client
            connectRadio(packet, station: delegate.stationName)
            
        case (true, kAvailable, _):           // newApi, connected to another client
            let firstButtonAction = { [self] in
                connectRadio(packet, isGui: delegate.enableGui, pendingDisconnect: .newApi(handle: packet.guiClients[0].handle), station: delegate.stationName)
            }
            let secondButtonAction = { [self] in
                connectRadio(packet, isGui: delegate.enableGui, station: delegate.stationName)
            }
            currentAlert = AlertParams(title: "Radio is connected to Station",
                                      message: packet.guiClients[0].station,
                                      buttons: [
                                        AlertButton( "Close \(packet.guiClients[0].station)", firstButtonAction ),
                                        AlertButton( "Multiflex Connect", secondButtonAction),
                                        AlertButton( "Cancel", {})
                                      ])
            showCustomAlert(currentAlert)

        case (true, kInUse, 2):               // newApi, connected to 2 clients
            let firstButtonAction = { [self] in
                connectRadio(packet, isGui: delegate.enableGui, pendingDisconnect: .newApi(handle: packet.guiClients[0].handle), station: delegate.stationName)      }
            let secondButtonAction = { [self] in
                connectRadio(packet, isGui: delegate.enableGui, pendingDisconnect: .newApi(handle: packet.guiClients[1].handle), station: delegate.stationName)      }
            currentAlert = AlertParams(title: "Radio is connected to multiple Stations",
                                      message: "",
                                      buttons: [
                                        AlertButton( "Close \(packet.guiClients[0].station)", firstButtonAction ),
                                        AlertButton( "Close \(packet.guiClients[1].station)", secondButtonAction),
                                        AlertButton( "Cancel", {})
                                      ])
            showCustomAlert(currentAlert)

        default:
            break
        }
    }
        
    // ----------------------------------------------------------------------------
    // MARK: - Auth0 actions
    
    /// Called when the SmartLinkAuthorizationView Cancel button is clicked
    ///
    func cancelButton() {
        wkWebView = nil
        _log("RadioManager, Auth0 cancel button", .debug,  #function, #file, #line)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private
        
    /// Given aTuple find a match in PickerPackets
    /// - Parameter conn: a Connection Tuple
    /// - Returns: the index into Packets (if any) of a match
    ///
    private func findMatching(_ conn: connectionTuple) -> Int? {
        for (i, packet) in pickerPackets.enumerated() {
            if packet.serialNumber == conn.serialNumber && packet.type.rawValue == conn.type {
                if delegate.enableGui {
                    return i
                } else if packet.stations == conn.station {
                    return i
                }
            }
        }
        return nil
    }
    
    /// Cause a bind command to be sent
    /// - Parameter id:     a Client Id
    ///
    private func bind(to id: String) {
        activeRadio?.boundClientId = id
    }
    
    /// Attempt to open a connection to the specified Radio
    /// - Parameters:
    ///   - packet:             the packet describing the Radio
    ///   - pendingDisconnect:  a struct describing a pending disconnect (if any)
    ///
    private func connectRadio(_ packet: DiscoveryPacket, isGui: Bool = true, pendingDisconnect: Api.PendingDisconnect = .none, station: String = "") {
        // station will be "Mac" if not passed
        let stationName = (station == "" ? "Mac" : station)
        
        // attempt a connection
        _api.connect(packet,
                     station           : stationName,
                     program           : Bundle.main.infoDictionary!["CFBundleName"] as! String,
                     clientId          : isGui ? delegate.clientId : nil,
                     isGui             : isGui,
                     wanHandle         : packet.wanHandle,
                     logState: .none,
                     pendingDisconnect : pendingDisconnect)
    }
    
    /// Create a subset of DiscoveryPackets for use by the RadioPicker
    /// - Returns:                an array of PickerPacket
    ///
    public func loadPickerPackets() {
        var newPackets = [PickerPacket]()
        var newStations = [Station]()
        var i = 0
        var p = 0
        
        if delegate.enableGui {
            // GUI connection
            for packet in packets {
                newPackets.append( PickerPacket(id: p,
                                                packetIndex: p,
                                                type: packet.isWan ? .wan : .local,
                                                nickname: packet.nickname,
                                                status: ConnectionStatus(rawValue: packet.status.lowercased()) ?? .inUse,
                                                stations: packet.guiClientStations,
                                                serialNumber: packet.serialNumber,
                                                isDefault: packet.connectionString == delegate.defaultGuiConnection))
                for client in packet.guiClients {
                    if delegate.activePacket?.isWan == packet.isWan {
                        newStations.append( Station(id: i,
                                                    name: client.station,
                                                    clientId: client.clientId) )
                        i += 1
                    }
                }
                p += 1
            }
            
        } else {
            
            func findStation(_ name: String) -> Bool {
                for station in newStations where station.name == name {
                    return true
                }
                return false
            }
            
            // Non-Gui connection
            for packet in packets {
                for client in packet.guiClients where client.station != "" {
                    newPackets.append( PickerPacket(id: p,
                                                    packetIndex: p,
                                                    type: packet.isWan ? .wan : .local,
                                                    nickname: packet.nickname,
                                                    status: ConnectionStatus(rawValue: packet.status.lowercased()) ?? .inUse,
                                                    stations: client.station,
                                                    serialNumber: packet.serialNumber,
                                                    isDefault: packet.connectionString + "." + client.station == delegate.defaultConnection))
                    if findStation(client.station) == false  {
                        newStations.append( Station(id: i,
                                                    name: client.station,
                                                    clientId: client.clientId) )
                        i += 1
                    }
                }
                p += 1
            }
        }
        pickerPackets = newPackets
    }
    
    /// Parse the components of a connection string
    /// - Parameter connectionString:   a string of the form <type>.<serialNumber>
    /// - Returns:                      a tuple containing the parsed values (if any)
    ///
    private func parseConnectionString(_ connectionString: String) -> (type: String, serialNumber: String, station: String)? {
        // A Connection is stored as a String in the form:
        //      "<type>.<serial number>"  OR  "<type>.<serial number>.<station>"
        //      where:
        //          <type>            "local" OR "wan", (wan meaning SmartLink)
        //          <serial number>   a serial number, e.g. 1234-5678-9012-3456
        //          <station>         a Station name e.g "Windows" (only used for non-Gui connections)
        //
        // If the Type and period separator are omitted. "local" is assumed
        //
        
        // split by the "." (if any)
        let parts = connectionString.components(separatedBy: ".")
        
        switch parts.count {
        case 3:
            // <type>.<serial number>
            return (parts[0], parts[1], parts[2])
        case 2:
            // <type>.<serial number>
            return (parts[0], parts[1], "")
        case 1:
            // <serial number>, type defaults to local
            return (parts[0], "local", "")
        default:
            // unknown, not a valid connection string
            return nil
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Notification methods
    
    private func addNotifications() {
        NotificationCenter.makeObserver(self, with: #selector(reload(_:)),   of: .discoveredRadios)
        NotificationCenter.makeObserver(self, with: #selector(clientDidConnect(_:)),   of: .clientDidConnect)
        NotificationCenter.makeObserver(self, with: #selector(clientDidDisconnect(_:)),   of: .clientDidDisconnect)
        NotificationCenter.makeObserver(self, with: #selector(reload(_:)),   of: .guiClientHasBeenAdded)
        NotificationCenter.makeObserver(self, with: #selector(guiClientHasBeenUpdated(_:)), of: .guiClientHasBeenUpdated)
        NotificationCenter.makeObserver(self, with: #selector(reload(_:)), of: .guiClientHasBeenRemoved)
    }
    
    @objc private func reload(_ note: Notification) {
        loadPickerPackets()
    }
    
    @objc private func clientDidConnect(_ note: Notification) {
        if let radio = note.object as? Radio {
            DispatchQueue.main.async { [self] in
                delegate.activePacket = radio.packet
                activeRadio = radio
                isConnected = true
            }
        }
    }
    
    @objc private func clientDidDisconnect(_ note: Notification) {
        DispatchQueue.main.async { [self] in
            isConnected = false
            if let reason = note.object as? String {
                disconnect(reason: reason)
            }
        }
    }
    
    @objc private func guiClientHasBeenUpdated(_ note: Notification) {
        loadPickerPackets()
        
        if let guiClient = note.object as? GuiClient {
            // ClientId has been populated
            DispatchQueue.main.async { [self] in
                
                if _autoBind != nil {
                    if guiClient.station == pickerPackets[_autoBind!].stations && guiClient.clientId != nil {
                        bind(to: guiClient.clientId!)
                    }
                }
            }
        }
    }
}

