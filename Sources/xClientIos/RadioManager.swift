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

public typealias ButtonTuple = (text: String, action: ((UIAlertAction)->Void)?)
public enum AlertStyle {
    case informational
    case warning
    case error
}

public struct AlertParams {
    public var style : AlertStyle = .informational
    public var title = ""
    public var message = ""
    public var buttons = [ButtonTuple]()
    
    public init(style: AlertStyle, title: String, message: String, buttons: [ButtonTuple] = []) {
        self.style = style
        self.title = title
        self.message = message
        self.buttons = buttons
    }
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
    // MARK: - Published properties
    
    var useLowBw : Bool = false
    
    @Published public var activePacket           : DiscoveryPacket?
    @Published public var activeRadio            : Radio?
    @Published public var stations               = [Station]()
    
    @Published public var pickerSelection        = Set<Int>()
    @Published public var stationSelection       = 0
    
    @Published public var showAlertView          = false
    @Published public var showAuth0Sheet         = false
    
    @Published public var smartLinkName          = ""
    @Published public var smartLinkCallsign      = ""
    @Published public var smartLinkImage         : UIImage?
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    public var delegate : RadioManagerDelegate
    var pickerPackets   = [PickerPacket]()
    var wanManager      : WanManager?
    var packets         : [DiscoveryPacket] { Discovery.sharedInstance.discoveryPackets }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private var _api            = Api.sharedInstance          // initializes the API
    private var _appNameTrimmed = ""
    private var _autoBind       : Int? = nil
    private let _log            = LogProxy.sharedInstance.logMessage
    private let _domain         : String
    
    private let kAvailable      = "available"
    private let kInUse          = "in_use"
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    public init(delegate: RadioManagerDelegate, domain: String, appName: String) {
        self.delegate = delegate
        _domain = domain
        _appNameTrimmed = appName.replacingSpaces(with: "")
        
        // start Discovery
        let _ = Discovery.sharedInstance
        
        // start listening to notifications
        addNotifications()
        
        // if SmartLink enabled, attemp to Log in
        if delegate.enableSmartLink {
            smartLinkLogin()
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
        // anything to connect to?
        if packetsAvailable() {
            // YES, attempt a connection to the first
            connect(to: 0)
        }
    }
    
    /// Initiate a connection to the Radio with the specified connection string
    /// - Parameter connection:   a connection string (in the form <type>.<serialNumber>)
    ///
    public func connectTo(connectionString: String) {
        // YES, is it a valid connection string?
        if let connectionTuple = validConnection(connectionString) {
            // VALID, is there a match?
            if let connectionIndex = findMatching(connectionTuple) {
                // YES, attempt a connection to it
                connect(to: connectionIndex)
            } else {
                // NO, no match found
                let alertParams = AlertParams(style: .warning, title: "Connection failed",
                                          message:  """
                                                    No matching radio for:

                                                    \(connectionString)
                                                    """,
                                          buttons: [("Ok", nil)])
                NotificationCenter.default.post(name: Notification.Name("showAlert"), object: alertParams)
                delegate.connectionState(false, connectionString, "No matching radio")
            }
        } else {
            // NO, not a valid connection string
            let alertParams = AlertParams(style: .warning, title: "Connection failed",
                                      message:  """
                                                Invalid connection string:

                                                \(connectionString)
                                                """,
                                      buttons: [("Ok", nil)])
            NotificationCenter.default.post(name: Notification.Name("showAlert"), object: alertParams)
            delegate.connectionState(false, connectionString, "Invalid connection string")
        }
    }
    
    /// Check that one or more packets exist
    /// - Returns: yes / no
    ///
    func packetsAvailable() -> Bool {
        loadPickerPackets()
        if pickerPackets.count == 0 {
            // NO, no radios found
            let alertParams = AlertParams(style: .warning, title: "No \(delegate.enableGui ? "Radios" : "Stations") found",
                                      message:  "",
                                      buttons: [("Ok", nil)])
            NotificationCenter.default.post(name: Notification.Name("showAlert"), object: alertParams)
        }
        return (pickerPackets.count != 0)
    }
    
    /// Initiate a connection to a Radio using the RadioPicker
    ///
    public func showPicker() {
        if packetsAvailable() {
            var buttons = [ButtonTuple]()
            for (_, packet) in pickerPackets.enumerated() {
                if delegate.enableGui {
                    if packet.nickname != "" {
                        var item = ButtonTuple(text: packet.nickname + ", " + (packet.type == .wan ? "SmartLink" : "Local"), action: { [self] action in connectTo(connectionString: packet.connectionString) })
                        if packet.connectionString == delegate.defaultGuiConnection { item.text = "--> " + item.text + " <--"}
                        buttons.append(item)
                    }
                } else {
                    if packet.stations != "" {
                        var item = ButtonTuple(text: packet.stations + ", " + (packet.type == .wan ? "SmartLink" : "Local"), action: { [self] action in connectTo(connectionString: packet.connectionString)})
                        if packet.connectionString == delegate.defaultConnection { item.text = "--> " + item.text + " <--"}
                        buttons.append(item)
                    }
                }
            }
            buttons.append(ButtonTuple(text: "Cancel", action: { _ in }))
            let alertParams = AlertParams(style: .warning, title: delegate.enableGui ? "Available Radios" : "Available Stations",
                                          message:  """
                                            Choose one or Cancel

                                            """,
                                          buttons: buttons)
            NotificationCenter.default.post(name: Notification.Name("showAlert"), object: alertParams)
        }
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
            stations.removeAll()            
        }
        // if anything unusual, tell the delegate
        if reason != RadioManager.kUserInitiated {
            let alertParams = AlertParams(style: .warning,
                                      title: "Radio was disconnected",
                                      message: reason,
                                      buttons: [("Ok", nil)])
            NotificationCenter.default.post(name: Notification.Name("showAlert"), object: alertParams)
            delegate.disconnectionState( reason)
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    public func chooseDefault() {
        if packetsAvailable() {
            var buttons = [ButtonTuple]()
            for (_, packet) in pickerPackets.enumerated() {
                var item = ButtonTuple(text: packet.nickname + ", " + (packet.type == .wan ? "SmartLink" : "Local"), action: { [self] action in setDefault(packet.connectionString) })
                if delegate.enableGui {
                    if packet.connectionString == delegate.defaultGuiConnection { item.text = "--> " + item.text + " <--"}
                    if packet.nickname != "" { buttons.append(item) }
                } else {
                    if packet.connectionString == delegate.defaultConnection { item.text = "--> " + item.text + " <--"}
                    if packet.stations != "" { buttons.append(ButtonTuple(text: packet.stations + ", " + (packet.type == .wan ? "SmartLink" : "Local"), action: { [self] action in setDefault(packet.connectionString) })) }
                }
            }
            buttons.append(ButtonTuple(text: delegate.connectToFirstRadio ? "--> First Found <--" : "First Found", action: { [self] _ in setFirstFound()} ))
            buttons.append(ButtonTuple(text: "Reset Default", action: { [self] _ in resetDefault()} ))
            buttons.append(ButtonTuple(text: "Cancel", action: { _ in }))
            let alertParams = AlertParams(style: .warning, title: "Available Defaults",
                                          message:  """
                                            Choose one or Cancel

                                            """,
                                          buttons: buttons)
            NotificationCenter.default.post(name: Notification.Name("showAlert"), object: alertParams)
        }
    }
    
    func setDefault(_ connectionString: String) {
        delegate.connectToFirstRadio = false
        if delegate.enableGui {
            delegate.defaultGuiConnection = connectionString
        } else {
            delegate.defaultConnection = connectionString
        }
    }

    func setFirstFound() {
        resetDefault()
        delegate.connectToFirstRadio = true
    }

    func resetDefault() {
        delegate.connectToFirstRadio = false
        if delegate.enableGui {
            delegate.defaultGuiConnection = ""
        } else {
            delegate.defaultConnection = ""
        }
    }

    /// Initiate a Login to the SmartLink server
    ///
    public func smartLinkLogin() {
        // start the WanManager
        wanManager = WanManager(radioManager: self, appNameTrimmed: _appNameTrimmed)
        
        // did SmartLink Login with saved credentials succeed?
        if wanManager!.smartLinkLogin(using: delegate.smartLinkAuth0Email) {
            // YES
            DispatchQueue.main.async { [self] in
                delegate.smartLinkIsLoggedIn = true
//                showPicker()
            }
        } else {
            // NO, show the Auth0View to allow the user to enter SmartLink credentials
            wanManager!.setupAuth0Credentials()
            // cause the sheet to appear
            DispatchQueue.main.async { [self] in
                showAuth0Sheet = true
            }
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
    
    /// Receives the results of a SmartLink test
    /// - Parameters:
    ///   - status:     pass / fail
    ///   - msg:        a summary of the results
    ///
    func smartLinkTestResults(status: Bool, msg: String) {
        DispatchQueue.main.async { [self] in
            delegate.smartLinkTestStatus = status    // set the indicator

            if status == false {
                let alertParams = AlertParams(style: .error, title: "SmartLink test failed", message: msg, buttons: [("Ok", nil)])
                NotificationCenter.default.post(name: Notification.Name("showAlert"), object: alertParams)
            }
        }
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
            let button1: (UIAlertAction)->Void = { [self] _ in
                connectRadio(packet, isGui: delegate.enableGui, pendingDisconnect: .oldApi, station: delegate.stationName)
                sleep(1)
                _api.disconnect()
                sleep(1)
                showPicker()
            }
            let button2: (UIAlertAction)->Void = { _ in }
            let alertParams = AlertParams(style: .informational,
                                          title: "Radio is connected to another Client",
                                          message: "Close the other Client?",
                                          buttons: [
                                            ("Close the other Client", button1),
                                            ("Cancel", button2),
                                          ])
            NotificationCenter.default.post(name: Notification.Name("showAlert"), object: alertParams)
            
        case (true, kAvailable, 0):           // newApi, not connected to another client
            connectRadio(packet, station: delegate.stationName)
            
        case (true, kAvailable, _):           // newApi, connected to another client
            let button1: (UIAlertAction)->Void = { [self] _ in connectRadio(packet, isGui: delegate.enableGui, pendingDisconnect: .newApi(handle: packet.guiClients[0].handle), station: delegate.stationName)}
            let button2: (UIAlertAction)->Void = { [self] _ in connectRadio(packet, isGui: delegate.enableGui, station: delegate.stationName) }
            let button3: (UIAlertAction)->Void = { _ in }
            let alertParams = AlertParams(style: .informational,
                                          title: "Radio is connected to Station: \(packet.guiClients[0].station)",
                                          message: "Choose one of the following",
                                          buttons: [
                                            ("Close \(packet.guiClients[0].station)", button1),
                                            ("Multiflex connect", button2),
                                            ("Cancel", button3),
                                          ])
            NotificationCenter.default.post(name: Notification.Name("showAlert"), object: alertParams)
            
        case (true, kInUse, 2):               // newApi, connected to 2 clients
            let button1: (UIAlertAction)->Void = { [self] _ in connectRadio(packet, isGui: delegate.enableGui, pendingDisconnect: .newApi(handle: packet.guiClients[0].handle), station: delegate.stationName)}
            let button2: (UIAlertAction)->Void = { [self] _ in connectRadio(packet, isGui: delegate.enableGui, pendingDisconnect: .newApi(handle: packet.guiClients[1].handle), station: delegate.stationName)}
            let button3: (UIAlertAction)->Void = { _ in }
            let alertParams = AlertParams(style: .informational,
                                          title: "Radio is connected to multiple Stations",
                                          message: "Close one of the Station",
                                          buttons: [
                                            ("Close \(packet.guiClients[0].station)", button1),
                                            ("Close \(packet.guiClients[1].station)", button2),
                                            ("Cancel", button3),
                                          ])
            NotificationCenter.default.post(name: Notification.Name("showAlert"), object: alertParams)
            
        default:
            break
        }
    }
    
    /// Determine the state of the Radio being closed and allow the user to choose how to proceed
    /// - Parameter packet:     the packet describing the Radio to be opened
    ///
    func closeRadio(_ packet: DiscoveryPacket) {
        
        guard delegate.enableGui else {
            disconnect()
            return
        }
        
        // CONNECT, is the selected radio connected to another client?
        switch (Version(packet.firmwareVersion).isNewApi, packet.status.lowercased(),  packet.guiClients.count) {
        
        case (false, _, _):                   // oldApi
            self.disconnect()
            
        case (true, kAvailable, 1):           // newApi, 1 client
            // am I the client?
            if packet.guiClients[0].handle == _api.connectionHandle {
                // YES, disconnect me
                self.disconnect()
                
            } else {
                // FIXME: don't think this code can ever be executed???
                let button1: (UIAlertAction)->Void = { [self] _ in clientDisconnect( packet: packet, handle: packet.guiClients[0].handle)}
                let button2: (UIAlertAction)->Void = { [self] _ in clientDisconnect( packet: packet, handle: packet.guiClients[1].handle)}
                let alertParams = AlertParams(style: .informational,
                                              title: "Radio is connected to multiple Stations",
                                              message: "Close one of the Station",
                                              buttons: [
                                                ( "Close \(packet.guiClients[0].station)", button1 ),
                                                ( "Disconnect " + _appNameTrimmed, button2),
                                              ])
                NotificationCenter.default.post(name: Notification.Name("showAlert"), object: alertParams)
            }
            
        case (true, kInUse, 2):           // newApi, 2 clients
            let button1: (UIAlertAction)->Void = { [self] _ in clientDisconnect( packet: packet, handle: packet.guiClients[0].handle)}
            let button2: (UIAlertAction)->Void = { [self] _ in clientDisconnect( packet: packet, handle: packet.guiClients[1].handle)}
            let button3: (UIAlertAction)->Void = { [self] _ in disconnect()}
            let alertParams = AlertParams(style: .informational,
                                          title: "Radio is connected to multiple Stations",
                                          message: "Close one of the Station",
                                          buttons: [
                                            ( (packet.guiClients[0].station == _appNameTrimmed ? "---" : "Close \(packet.guiClients[0].station)"), button1 ),
                                            ( (packet.guiClients[0].station == _appNameTrimmed ? "---" : "Close \(packet.guiClients[1].station)"), button2 ),
                                            ( "Disconnect " + _appNameTrimmed, button3),
                                          ])
            NotificationCenter.default.post(name: Notification.Name("showAlert"), object: alertParams)
            
        default:
            self.disconnect()
        }
    }
    // ----------------------------------------------------------------------------
    // MARK: - Picker actions
    
    /// Called when the Picker's Close button is clicked
    ///
//    func closePicker() {
//        DispatchQueue.main.async { self.showPickerSheet = false }
//    }
    
    /// Called when the Picker's Test button is clicked
    ///
    public func smartLinkTest() {
        var buttons = [ButtonTuple]()
        buttons.append(ButtonTuple(text: "Cancel", action: nil))
        for packet in pickerPackets where packet.type == .wan {
            buttons.append( ButtonTuple(text: packet.nickname, action: { [self] _ in wanManager?.sendTestConnection(for: packet.serialNumber) }))
        }
        let alertParams = AlertParams(style: .informational,
                                      title: "SmartLink connections",
                                      message: "Choose one or Cancel",
                                      buttons: buttons)
        NotificationCenter.default.post(name: Notification.Name("showAlert"), object: alertParams)
    }
    
    /// Called when the Picker's Select button is clicked
    ///
//    func connect(to selection: Set<Int>) {
//        if let i = selection.first {
//            // remove the selection highlight
//            pickerSelection = Set<Int>()
//            connect(to: i)
//        }
//    }
    
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
    private func connect(to index: Int) {
        
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
                     program           : _appNameTrimmed,
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
        self.pickerPackets = newPackets
//        self.stations = newStations
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
