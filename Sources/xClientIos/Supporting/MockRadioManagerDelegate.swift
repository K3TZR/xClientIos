//
//  MockRadioManagerDelegate.swift
//  xClientIos
//
//  Created by Douglas Adams on 9/5/20.
//

import Foundation
import SwiftUI

class MockRadioManagerDelegate : RadioManagerDelegate {
        
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var clientId              = UUID().uuidString
    var connectToFirstRadio   = false
    var defaultConnection     = ""
    var defaultGuiConnection  = ""
    var enableGui             = true
    var enableSmartLink       = true
    var smartLinkAuth0Email   = ""
    var stationName           = "MockStation"

    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    func willConnect() {}
    func willDisconnect() {}
}

