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
    @ObservedObject var radioManager: RadioManager

    public init(radioManager: RadioManager) {
        self.radioManager = radioManager
    }
    
    public var body: some View {
        ZStack {
//            EmptyView()
//                .sheet(isPresented: $radioManager.showPickerView) {
//                    PickerView().environmentObject(radioManager)
//                }
            EmptyView()
                .sheet(isPresented: $radioManager.showAuth0View ) {
                    Auth0View().environmentObject(radioManager)
                }
//            EmptyView()
//                .multiAlert(isPresented: $radioManager.showMultiAlert, radioManager.currentMultiAlert)
        }
    }
}

public struct StubView_Previews: PreviewProvider {
    public static var previews: some View {
        StubView(radioManager: RadioManager(delegate: MockRadioManagerDelegate()))
    }
}
