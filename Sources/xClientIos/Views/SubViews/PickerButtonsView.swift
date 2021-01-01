//
//  PickerButtonsView.swift
//  xClientIos package
//
//  Created by Douglas Adams on 8/13/20.
//

import SwiftUI

/// Picker buttons to Test, Close or Select
///
struct PickerButtonsView: View {
    @EnvironmentObject var radioManager : RadioManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        HStack (spacing: 120){
            TestButton()
                .environmentObject(radioManager)
            
            Button("Cancel", action: {
                presentationMode.wrappedValue.dismiss()
                radioManager.closePicker()
            })
            
            Button("Connect", action: {
                presentationMode.wrappedValue.dismiss()
                radioManager.connect( to: radioManager.pickerSelection!)
            })
            .disabled(radioManager.pickerSelection == nil)
        }
    }
}

struct PickerButtonsView_Previews: PreviewProvider {
    static var previews: some View {
        PickerButtonsView()
            .environmentObject(RadioManager(delegate: MockRadioManagerDelegate()))
    }
}
