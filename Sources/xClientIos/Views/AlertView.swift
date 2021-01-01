//
//  AlertView.swift
//  xClientMac
//
//  Created by Douglas Adams on 12/5/20.
//

import SwiftUI

struct AlertView: View {
    @Environment(\.presentationMode) var presentation
    
    let params : AlertParams
    
    var body: some View {
        
        VStack (spacing: 50) {
            Text(params.title).font(.title2)
                        
            if params.message != "" {
                Text(params.message)
                    .multilineTextAlignment(.center)
                    .font(.title3)
            } else {
                EmptyView()
            }
            Divider()
            VStack (spacing: 30) {
                ForEach(params.buttons.indices) { i in
                    Button(action: {
                            params.buttons[i].action?() ?? {}()
                            self.presentation.wrappedValue.dismiss()}) {
                        Text(params.buttons[i].text).frame(width: 175)
                    }
                    
                }.frame(width: 250)
            }

            Spacer()

        }.padding()
    }
}

struct AlertView_Previews: PreviewProvider {
    static var previews: some View {
        AlertView(params: AlertParams(style: .warning,
                                      title: "Sample Title",
                                      message:
                                        """
                                        A sample Message
                                        with 2 lines and 3 buttons
                                        """,
                                      buttons: [
                                        AlertButton("Button1", nil),
                                        AlertButton("Button2", nil),
                                        AlertButton("Button3", nil)]
        ))
    }
}
