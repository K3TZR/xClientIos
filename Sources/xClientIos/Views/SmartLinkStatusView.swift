//
//  SmartLinkStatusView.swift
//  xClientMac package
//
//  Created by Douglas Adams on 8/13/20.
//

import SwiftUI

public struct SmartlinkStatusView: View {
    @EnvironmentObject var radioManager : RadioManager
    @Environment(\.presentationMode) var presentationMode
    
    public init() {}
        
    public var body: some View {
        
        VStack {
            Text("Smartlink User").font(.title)
            Divider()
            
            Spacer()
            HStack (spacing: 20) {
                ZStack {
                    Rectangle()
                        
                    Image(uiImage: radioManager.smartlinkImage)
                        .resizable()
                        .scaledToFill()
                }
                .frame(width: 120, height: 120)
                .cornerRadius(16)

                VStack (alignment: .leading, spacing: 40) {
                    Text("Name").bold()
                    Text("Callsign").bold()
                    Text("Email").bold()
                }.frame(width: 70, alignment: .leading)
                
                VStack (alignment: .leading, spacing: 40) {
                    Text(radioManager.smartlinkName)
                    Text(radioManager.smartlinkCallsign)
                    Text(radioManager.delegate.smartlinkAuth0Email ?? "")
                }.frame(width: 200, alignment: .leading)
            }
            Spacer()
            
            Divider()
            HStack(spacing: 40) {
                Button(radioManager.delegate.smartlinkEnabled ? "Disable" : "Enable") {
                    radioManager.toggleSmartlink()
                    presentationMode.wrappedValue.dismiss()
                }
                Button("Force Login") {
                    radioManager.forceLogin()
                    presentationMode.wrappedValue.dismiss()
                }
                Button("Close") { presentationMode.wrappedValue.dismiss() }
            }
        }
        .padding()
    }
}

struct SmartLinkView_Previews: PreviewProvider {
    static var previews: some View {
        SmartlinkStatusView()
            .environmentObject(RadioManager(delegate: MockRadioManagerDelegate()))
    }
}
