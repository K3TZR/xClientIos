//
//  SmartLinkView.swift
//  xClientIos
//
//  Created by Douglas Adams on 8/13/20.
//

import SwiftUI

/// Image, textfields and button for the SmartLink portion of the Picker
///   only shown if SmartLink is enabled
///
public struct SmartLinkView: View {
    @EnvironmentObject var radioManager : RadioManager
    @Environment(\.presentationMode) var presentationMode
    
    public init() {}
        
    public var body: some View {
        
        VStack {
            HStack (spacing: 30) {
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                    if radioManager.smartLinkImage != nil {
                        Image(uiImage: radioManager.smartLinkImage!)
                            .resizable()
                    }
                }
                .frame(width: 60, height: 60)
                .aspectRatio(8/8, contentMode: .fit)
                .cornerRadius(8)
                
                VStack (alignment: .leading, spacing: 10) {
                    Text("Name")
                        .frame(width: 70, alignment: .leading)
                    Text("Callsign")
                        .frame(width: 70, alignment: .leading)
                }
                
                VStack (alignment: .leading, spacing: 10) {
                    Text(radioManager.smartLinkName)
                        .frame(width: 150, alignment: .leading)
                        .border(Color(.placeholderText))
                    
                    Text(radioManager.smartLinkCallsign)
                        .frame(width: 150, alignment: .leading)
                        .border(Color(.placeholderText))
                }.disabled(true)
                
                Button(radioManager.smartLinkIsLoggedIn ? "Logout" : "Login", action: {
                    presentationMode.wrappedValue.dismiss()
                    DispatchQueue.main.async { [self] in
                        if radioManager.smartLinkIsLoggedIn {radioManager.smartLinkLogout() } else {radioManager.smartLinkLogin()}
                    }
                }).disabled(!radioManager.delegate.enableSmartLink)
            }
            Divider()
        }
    }
}

struct SmartLinkView_Previews: PreviewProvider {
    static var previews: some View {
        SmartLinkView()
            .environmentObject(RadioManager(delegate: MockRadioManagerDelegate()))
    }
}
