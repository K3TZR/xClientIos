//
//  PickerButtonsView.swift
//  xClientIos
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
        HStack(spacing: 40){
            TestButton()
            Button("Cancel") {
                radioManager.pickerSelection = nil
                presentationMode.wrappedValue.dismiss()
            }
            Button("Connect") {
                presentationMode.wrappedValue.dismiss()
            }
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
