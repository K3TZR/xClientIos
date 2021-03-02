//
//  TestButton.swift
//  xClientIos
//
//  Created by Douglas Adams on 8/15/20.
//

import SwiftUI

/// Button with a red/green status indicator
///
struct TestButton: View {
    @EnvironmentObject var radioManager :RadioManager
    
    var body: some View {
                
        HStack {
            // only enable Test if a SmartLink connection is selected
            let testDisabled = !radioManager.delegate.smartlinkEnabled || radioManager.pickerSelection == nil || radioManager.pickerPackets[radioManager.pickerSelection!].type != .wan
            
            Button("Test") {
                    radioManager.smartlinkTest()
            }.disabled(testDisabled)

            Circle()
                .fill(radioManager.smartlinkTestStatus ? Color.green : Color.red)
                .frame(width: 20, height: 20)
        }
    }
}

struct TestButton_Previews: PreviewProvider {
    static var previews: some View {
        TestButton()
            .environmentObject(RadioManager(delegate: MockRadioManagerDelegate()))
    }
}
