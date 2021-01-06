//
//  TestButton.swift
//  xClientMac package
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
            let isEnabled = radioManager.delegate.enableSmartLink && radioManager.pickerSelection != nil && radioManager.pickerPackets[radioManager.pickerSelection!].type == .wan
            let alertText = "SmartLink Test \(radioManager.smartLinkTestStatus ? "SUCCESS" : "FAILURE")"
            let alertMessage = radioManager.smartLinkTestResults ?? ""
            
            Button(action: { radioManager.smartLinkTest() }) {Text("Test")}
                .disabled(isEnabled == false)
                .padding(.horizontal, 20)
                .alert(isPresented: $radioManager.smartLinkTestStatus ) {
                    Alert(title: Text(alertText), message: Text(alertMessage), dismissButton: .default(Text("Ok")))
                }

            Circle()
                .fill(radioManager.smartLinkTestStatus ? Color.green : Color.red)
                .frame(width: 20, height: 20)
                .padding(.trailing, 20)
        }
    }
}

struct TestButton_Previews: PreviewProvider {
    static var previews: some View {
        TestButton()
            .environmentObject(RadioManager(delegate: MockRadioManagerDelegate()))
    }
}
