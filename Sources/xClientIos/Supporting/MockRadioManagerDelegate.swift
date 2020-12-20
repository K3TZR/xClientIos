//
//  MockRadioManagerDelegate.swift
//  xClientIos package
//
//  Created by Douglas Adams on 9/5/20.
//

import Foundation
import xLib6000

class MockRadioManagerDelegate : RadioManagerDelegate {
        
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var clientId              = UUID().uuidString
    var connectToFirstRadio   = false
    var defaultConnection     = ""
    var defaultGuiConnection  = ""
    var enableGui             = true
    var enableSmartLink       = true
    var kAppNameTrimmed       = "MockApp"
    var smartLinkAuth0Email   = ""
    var smartLinkIsLoggedIn   = false
    var smartLinkTestStatus   = false
    var stationName           = "MockStation"
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    func connectionState(_ connected: Bool, _ connection: String, _ msg: String) { /* stub */ }
    func disconnectionState(_ msg: String) { /* stub */ }
}
