//
//  StubView.swift
//  xClientIos package
//
//  Created by Douglas Adams on 8/25/20.
//

import SwiftUI

/// A view to be inserted into the app's ContentView
///     allows display of the Picker and Auth0 sheets (supplied by xLibClient)
///
public struct StubView: View {
//    let radioManager: RadioManager
    
    public init() {
    }
    
    public var body: some View {
        VStack {
            EmptyView()
//                .sheet(isPresented: $radioManager.showPickerView, onDismiss: { radioManager.connect(to: radioManager.pickerSelection) }) {
//                    PickerView().environmentObject(radioManager)
//                }
            
            
            //            EmptyView()
            //                .sheet(isPresented: $radioManager.showAuth0View ) {
            //                    Auth0View().environmentObject(radioManager)
            //                }
            EmptyView()
//                .alert(isPresented: $radioManager.showCurrentAlert, content: {
//                    Alert(title: Text("Alert Title"))
//                })
        }
    }
}

public struct StubView_Previews: PreviewProvider {
    public static var previews: some View {
        StubView()
        
    }
}
