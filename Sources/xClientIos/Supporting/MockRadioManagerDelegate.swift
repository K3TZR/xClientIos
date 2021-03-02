//
//  MockRadioManagerDelegate.swift
//  xClientIos
//
//  Created by Douglas Adams on 9/5/20.
//

import UIKit
import xLib6000

class MockRadioManagerDelegate: RadioManagerDelegate {
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var clientId: String?
    var connectToFirstRadio   = false
    var defaultConnection: String?
    var defaultGuiConnection: String?
    var enableGui             = true
    var smartlinkAuth0Email: String?
    var smartlinkEnabled      = true
    var smartlinkIsLoggedIn   = true
    var smartlinkUserImage: UIImage?
    var stationName           = "MockStation"

    var activePacket: DiscoveryPacket?
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    func willConnect() {}
    func willDisconnect() {}
}
