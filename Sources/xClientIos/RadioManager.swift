//
//  RadioManager.swift
//  xClientIos package
//
//  Created by Douglas Adams on 8/23/20.
//

import Foundation
import SwiftUI
import xLib6000

public struct PickerPacket : Identifiable, Equatable {
    public var id         = 0
    var packetIndex       = 0
    var type              : ConnectionType = .local
    var nickname          = ""
    var status            : ConnectionStatus = .available
    public var stations          = ""
    var serialNumber      = ""
    var isDefault         = false
    var connectionString  : String { "\(type == .wan ? "wan" : "local").\(serialNumber)" }
    
    public static func ==(lhs: PickerPacket, rhs: PickerPacket) -> Bool {
        guard lhs.serialNumber != "" else { return false }
        return lhs.connectionString == rhs.connectionString
    }
}

public enum ConnectionType : String {
    case wan
    case local
}

public enum ConnectionStatus : String {
    case available
    case inUse = "in_use"
}

public struct Station : Identifiable {
    public var id        = 0
    public var name      = ""
    public var clientId  : String?
    
    public init(id: Int, name: String, clientId: String?) {
        self.id = id
        self.name = name
        self.clientId = clientId
    }
}

public typealias AlertButton = (text: String, action: (()->Void)?)
public enum AlertStyle {
    case informational
    case warning
    case error
}

public struct AlertParams {
    public var style : AlertStyle = .informational
    public var title    = ""
    public var message  = ""
    public var buttons  = [AlertButton]()
    
//    public init(style: AlertStyle, title: String, message: String, buttons: [AlertButton] = []) {
//        self.style = style
//        self.title = title
//        self.message = message
//        self.buttons = buttons
//    }
}


// ----------------------------------------------------------------------------
// RadioManagerDelegate protocol definition
// ----------------------------------------------------------------------------

public protocol RadioManagerDelegate {
    
    /// Called asynchronously by RadioManager to indicate success / failure for a Radio connection attempt
    /// - Parameters:
    ///   - state:          true if connected
    ///   - connection:     the connection string attempted
    ///
    func connectionState(_ state: Bool, _ connection: String, _ msg: String)
    
    /// Called  asynchronously by RadioManager when a disconnection occurs
    /// - Parameter msg:      explanation
    ///
    func disconnectionState(_ msg: String)
    
    var clientId                : String  {get}         // the app's ClientId
    var connectToFirstRadio     : Bool    {get set}
    var defaultConnection       : String  {get set}     // the default Non-Gui connection string
    var defaultGuiConnection    : String  {get set}     // the default Gui connection string
    var enableGui               : Bool    {get}         // whether to connect as a Gui client
    var enableSmartLink         : Bool    {get}         // whether SmartLink should be initialized
    var smartLinkAuth0Email     : String  {get set}     // the saved email address
    var smartLinkIsLoggedIn     : Bool    {get set}
    var smartLinkTestStatus     : Bool    {get set}
    var stationName             : String  {get}         // the name of the Station
}

// ----------------------------------------------------------------------------
// RadioManager class implementation
// ----------------------------------------------------------------------------

public final class RadioManager : ObservableObject {
    
    typealias connectionTuple = (type: String, serialNumber: String, station: String)
    
    // ----------------------------------------------------------------------------
    // MARK: - Static properties
    
    public static let kUserInitiated      = "User initiated"
    
    static let kAuth0Domain               = "https://frtest.auth0.com/"
    static let kAuth0ClientId             = "4Y9fEIIsVYyQo5u6jr7yBWc4lV5ugC2m"
    static let kRedirect                  = "https://frtest.auth0.com/mobile"
    static let kResponseType              = "token"
    static let kScope                     = "openid%20offline_access%20email%20given_name%20family_name%20picture"
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties

    
    
    @Published public var showMultiAlert  = false
    public var currentMultiAlert = MultiAlert()
    
    
    
    
    @Published public var activePacket          : DiscoveryPacket?
    @Published public var activeRadio           : Radio?
    @Published public var alertParams           = AlertParams()
    @Published public var pickerHeading         = ""
    @Published public var pickerMessage         = ""
    @Published public var pickerPackets         = [PickerPacket]()
    @Published public var pickerSelection       : Int?
    @Published public var showActionSheet       = false
    @Published public var showAlertView         = false
    @Published public var showAuth0View         = false
    @Published public var showPickerView        = false
    @Published public var smartLinkCallsign     = ""
    @Published public var smartLinkImage        : UIImage?
    @Published public var smartLinkIsLoggedIn   = false
    @Published public var smartLinkName         = ""
    @Published public var smartLinkTestStatus   = false
//    @Published public var stations              = [Station]()
    @Published public var stationSelection      = 0
    @Published public var useLowBw              : Bool = false

    public var delegate                         : RadioManagerDelegate
    public var smartLinkTestResults             : String?

    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var wanManager      : WanManager?
    var packets         : [DiscoveryPacket] { Discovery.sharedInstance.discoveryPackets }

    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private var _api            = Api.sharedInstance          // initializes the API
    private var _autoBind       : Int? = nil
    private let _log            = LogProxy.sharedInstance.logMessage
    
    private let kAvailable      = "available"
    private let kInUse          = "in_use"
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    public init(delegate: RadioManagerDelegate) {
        self.delegate = delegate
        
        // start Discovery
        let _ = Discovery.sharedInstance
        
        // start listening to notifications
        addNotifications()
        
        // if SmartLink enabled, attemp to Log in
        if delegate.enableSmartLink {
            smartLinkLogin(suppressPicker: true)
        } else {
            smartLinkName = ""
            smartLinkCallsign = ""
            smartLinkImage = nil
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    /// Initiate a connection to the first Radio found
    ///
    public func connectToFirstFound() {
        // NO, were one or more radios found?
        if pickerPackets.count > 0 {
            // YES, attempt a connection to the first
            connect(to: 0)
        } else {
            // NO, no radios found
            showPicker()
        }
    }
    
    /// Initiate a connection to the Radio with the specified connection string
    /// - Parameter connection:   a connection string (in the form <type>.<serialNumber>)
    ///
    public func connect(to connectionString: String) {
        // is it a valid connection string?
        if let connectionTuple = validConnection(connectionString) {
            // VALID, is there a match?
            if let connectionIndex = findMatching(connectionTuple) {
                // YES, attempt a connection to it
                connect(to: connectionIndex)
            } else {
                // NO, no match found
                delegate.connectionState(false, connectionString, "No matching \(delegate.enableGui ? "Radio" : "Station")")
            }
        } else {
            // NOT VALID
            delegate.connectionState(false, connectionString, "Invalid connection string")
        }
    }
    
    /// Initiate a connection to a Radio using the RadioPicker
    ///
    public func showPicker(message: String? = nil) {
        loadPickerPackets()
        delegate.smartLinkTestStatus = false
        pickerSelection = nil
        DispatchQueue.main.async { [self] in
            pickerMessage = (message != nil ? message! : "")
            pickerHeading = "Select a \(delegate.enableGui ? "Radio" : "Station") and touch Connect"

            showPickerView = true
        }
    }
    
    public func showAuth0(_ state: Bool = true) {
        DispatchQueue.main.async { self.showAuth0View = state }
    }
    
    public func removeSmartLinkRadios() {
        Discovery.sharedInstance.removeSmartLinkRadios()
    }
    
    /// Disconnect the current connection
    /// - Parameter msg:    explanation
    ///
    public func disconnect(reason: String = RadioManager.kUserInitiated) {        
        _log("RadioManager: Disconnect - \(reason)", .info,  #function, #file, #line)
        
        // tell the library to disconnect
        _api.disconnect(reason: reason)
        
        DispatchQueue.main.async { [self] in
            // remove all Client Id's
            for (i, _) in activePacket!.guiClients.enumerated() {
                activePacket!.guiClients[i].clientId = nil
            }
            activePacket = nil
            activeRadio = nil
            stationSelection = 0
        }
        // if anything unusual, tell the delegate
        if reason != RadioManager.kUserInitiated {
//            NotificationCenter.default.post(name: Notification.Name("showAlert"), object: AlertParams(style: .warning,
//                                                                                                      title: "Radio was disconnected",
//                                                                                                      message: reason,
//                                                                                                      buttons: [("Ok", nil)]))
            delegate.disconnectionState( reason)
        }
    }
    
    public func setDefault(_ defaultPacket: PickerPacket) {
        clearDefaults(suppressAlert: true)
        for (i, packet) in pickerPackets.enumerated() where packet == defaultPacket {
            DispatchQueue.main.async { self.pickerPackets[i].isDefault = true }
        }
        if delegate.enableGui {
            delegate.defaultGuiConnection = defaultPacket.connectionString
        } else {
            delegate.defaultConnection = defaultPacket.connectionString + "." + defaultPacket.stations
        }
    }
    
    public func setFirstFound() {
        clearDefaults(suppressAlert: true)
        delegate.connectToFirstRadio = true
    }
    
    public func clearDefaults(suppressAlert: Bool = false) {
        for (i, packet) in pickerPackets.enumerated() where packet.isDefault {
            DispatchQueue.main.async { self.pickerPackets[i].isDefault = false }
        }
        delegate.connectToFirstRadio = false
        if delegate.enableGui {
            delegate.defaultGuiConnection = ""
        } else {
            delegate.defaultConnection = ""
        }
    }

    /// Initiate a Login to the SmartLink server
    ///
    public func smartLinkLogin(suppressPicker: Bool = false) {
        // start the WanManager
        wanManager = WanManager(radioManager: self)
        
        // did SmartLink Login with saved credentials succeed?
        if wanManager!.smartLinkLogin(using: delegate.smartLinkAuth0Email) {
            // YES
            DispatchQueue.main.async { [self] in
                delegate.smartLinkIsLoggedIn = true
                if suppressPicker == false { showPicker() }
            }
        } else {
            // NO, show the Auth0View to allow the user to enter SmartLink credentials
            wanManager!.setupAuth0Credentials()
            // cause the sheet to appear
            showAuth0()
        }
    }
    
    
    /// Initiate a Logout from the SmartLink server
    ///
    public func smartLinkLogout() {
        // remove any SmartLink radios from Discovery
        Discovery.sharedInstance.removeSmartLinkRadios()
        
        // close out the connection
        wanManager?.smartLinkLogout()
        wanManager = nil
        
        DispatchQueue.main.async { [self] in
            // remember the current state
            delegate.smartLinkIsLoggedIn = false
            
            // remove the current user info
            smartLinkName = ""
            smartLinkCallsign = ""
            smartLinkImage = nil
        }
    }

    /// Called when the Picker's Test button is clicked
    ///
    public func smartLinkTest() {
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
    func smartLinkTestResults(status: Bool, msg: String) {
        smartLinkTestResults = msg
        // set the indicator
        DispatchQueue.main.async { self.smartLinkTestStatus = status }
    }

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
            let button1: ()->Void = { [self] in
                connectRadio(packet, isGui: delegate.enableGui, pendingDisconnect: .oldApi, station: delegate.stationName)
                sleep(1)
                _api.disconnect()
                sleep(1)
                showPicker()
            }
            let button2: ()->Void = { }
            showAlert( AlertParams(style: .informational,
                                   title: "Radio is connected to another Client",
                                   message: "Close the other Client?",
                                   buttons: [
                                    ("Close the other Client", button1),
                                    ("Cancel", button2),
                                   ]))
            
        case (true, kAvailable, 0):           // newApi, not connected to another client
            connectRadio(packet, station: delegate.stationName)
            
        case (true, kAvailable, _):           // newApi, connected to 1 client
//            let button0 = { [self] in connectRadio(packet, isGui: delegate.enableGui, pendingDisconnect: .newApi(handle: packet.guiClients[0].handle), station: delegate.stationName)}
//            let button1 = { [self] in self.connectRadio(packet, isGui: delegate.enableGui, station: delegate.stationName) }
            
            showMultiAlert( MultiAlert(title: "Radio is connected to Station:",
                                       message: packet.guiClients[0].station,
                                       buttons: ["Close \(packet.guiClients[0].station)",
                                                 "Multiflex connect",
                                                 "Cancel"],
                                       action: { [self] action in
                                        switch action {
                                        
                                        case 0:   do { connectRadio(packet, isGui: delegate.enableGui, pendingDisconnect: .newApi(handle: packet.guiClients[0].handle), station: delegate.stationName)}
                                        case 1:   do { connectRadio(packet, isGui: delegate.enableGui, station: delegate.stationName) }
                                        case 2:   break
                                        default:  do { print("Unknown response") }
                                        }
                                       }))

            
        case (true, kInUse, 2):               // newApi, connected to 2 clients
            let button1: ()->Void = { [self] in connectRadio(packet, isGui: delegate.enableGui, pendingDisconnect: .newApi(handle: packet.guiClients[0].handle), station: delegate.stationName)}
            let button2: ()->Void = { [self] in connectRadio(packet, isGui: delegate.enableGui, pendingDisconnect: .newApi(handle: packet.guiClients[1].handle), station: delegate.stationName)}
            let button3: ()->Void = { }
            showAlert( AlertParams(style: .informational,
                                   title: "Radio is connected to multiple Stations",
                                   message: "Close one of the Station",
                                   buttons: [
                                    ("Close \(packet.guiClients[0].station)", button1),
                                    ("Close \(packet.guiClients[1].station)", button2),
                                    ("Cancel", button3),
                                   ]))
        default:
            break
        }
    }
    
    private func showAlert(_ params: AlertParams) {
        alertParams = params
        DispatchQueue.main.async { [self] in showAlertView = true }
    }
    
    private func showMultiAlert(_ alert: MultiAlert) {
        currentMultiAlert = alert
        DispatchQueue.main.async { [self] in showMultiAlert = true }
    }
    
    
    // ----------------------------------------------------------------------------
    // MARK: - Picker actions
    
    /// Called when the Picker's Close button is clicked
    ///
    func closePicker() {
        DispatchQueue.main.async { self.showPickerView = false }
    }
    
    /// Called when the Picker's Select button is clicked
    ///
    func connect(to selection: Int?) {
        if let i = selection {
            // remove the selection highlight
            pickerSelection = nil
            connect(to: i)
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Auth0 actions
    
    /// Called when the Auth0 Login Cancel button is clicked
    ///
    func cancelButton() {
        _log("RadioManager: Auth0 cancel button", .debug,  #function, #file, #line)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private
        
    /// Given aTuple find a match in Packets
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
        //
        activeRadio?.boundClientId = id
    }
    
    /// Connect to the Radio found at the specified index in the Discovered Radios
    /// - Parameter index:    an index into the discovered radios array
    ///
    public func connect(to index: Int) {
        
        guard activePacket == nil else { disconnect() ; return }
        
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
    
    /// Attempt to open a connection to the specified Radio
    /// - Parameters:
    ///   - packet:             the packet describing the Radio
    ///   - pendingDisconnect:  a struct describing a pending disconnect (if any)
    ///
    private func connectRadio(_ packet: DiscoveryPacket, isGui: Bool = true, pendingDisconnect: Api.PendingDisconnect = .none, station: String = "") {
        // station will be computer name if not passed
        let stationName = (station == "" ? delegate.stationName : station)
        
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
                    if activePacket?.isWan == packet.isWan {
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
        DispatchQueue.main.async { self.pickerPackets = newPackets }
    }
    
    /// Parse the Type and Serial Number in a connection string
    ///
    /// - Parameter connectionString:   a string of the form <type>.<serialNumber>
    /// - Returns:                      a tuple containing the parsed values (if any)
    ///
    private func validConnection(_ connectionString: String) -> (type: String, serialNumber: String, station: String)? {
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
    
    /// Setup notification observers
    ///
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
                activePacket = radio.packet
                activeRadio = radio
            }
            let connection = (radio.packet.isWan ? "wan" : "local") + "." + radio.packet.serialNumber
            delegate.connectionState(true, connection, "")
        }
    }
    
    @objc private func clientDidDisconnect(_ note: Notification) {
        if let reason = note.object as? String {
            disconnect(reason: reason)
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

