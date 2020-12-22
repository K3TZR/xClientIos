//
//  LoggerHeader.swift
//  
//
//  Created by Douglas Adams on 12/19/20.
//

import SwiftUI

struct LoggerBottomButtons: View {
    @EnvironmentObject var logger: Logger

    var body: some View {
        HStack {
            Stepper("Font Size", value: $logger.fontSize, in: 8...24).frame(width: 175)
            Spacer()
            Text("Log View")
            Spacer()
            Button(action: {logger.delegate.showLogWindow.toggle() }) {Text("Back to Main")}
        }
    }
}

struct LoggerBottomButtons_Previews: PreviewProvider {
    static var previews: some View {
        LoggerBottomButtons()
    }
}
