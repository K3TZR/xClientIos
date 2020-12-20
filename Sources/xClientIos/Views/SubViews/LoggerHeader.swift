//
//  LoggerHeader.swift
//  
//
//  Created by Douglas Adams on 12/19/20.
//

import SwiftUI

struct LoggerHeader: View {
    @EnvironmentObject var logger: Logger

    var body: some View {
        HStack {
            Spacer()
            Text("Log View")
            Spacer()
            Button(action: {logger.delegate.showLogWindow.toggle() }) {Text("Close")}
        }
        .padding(.trailing, 20)
    }
}

struct LoggerHeader_Previews: PreviewProvider {
    static var previews: some View {
        LoggerHeader()
    }
}
