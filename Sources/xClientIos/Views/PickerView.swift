//
//  PickerView.swift
//  xClientIos package
//
//  Created by Douglas Adams on 8/15/20.
//

import SwiftUI

/// A View to allow the user to select a Radio / Station for connection
///
public struct PickerView: View {
  @EnvironmentObject var radioManager: RadioManager
  
  public init() {
  }
    
    public var body: some View {
        VStack {
            
            if radioManager.pickerMessage != "" {
                Text(radioManager.pickerMessage).foregroundColor(.red)
                Text("")
            } else {
                EmptyView()
            }
            
            Text(radioManager.pickerHeading)

            Divider()
            
            if radioManager.delegate.enableSmartLink { SmartLinkView() }
            
            RadioListView()
            
            Divider()
            
            PickerButtonsView()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }
}

struct PickerView_Previews: PreviewProvider {

    static var previews: some View {
      PickerView().environmentObject(RadioManager(delegate: MockRadioManagerDelegate()))
    }
}