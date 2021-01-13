//
//  LoggerTrailer.swift
//  xClientIos
//
//  Created by Douglas Adams on 12/19/20.
//

import SwiftUI


struct LoggerTopButtons: View {
    @ObservedObject var logger: Logger

    var body: some View {

        
        HStack (spacing: 80) {
            Spacer()

            HStack {
                Text("Show Level")
                Picker(logger.level.rawValue, selection: $logger.level) {
                    ForEach(Logger.LogLevel.allCases, id: \.self) {
                        Text($0.rawValue)
                    }
                }.pickerStyle(MenuPickerStyle())
            }
            
            HStack {
                Text("Filter by")
                Picker(logger.filterBy.rawValue, selection: $logger.filterBy) {
                    ForEach(Logger.LogFilter.allCases, id: \.self) {
                        Text($0.rawValue)
                    }
                }.pickerStyle(MenuPickerStyle())
                
                TextField("Filter text", text: $logger.filterByText).frame(maxWidth: 300, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
            }
            
            Toggle("Show Timestamps", isOn: $logger.showTimestamps)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 210, alignment: .center)
            
            Spacer()
        }
    }
}

struct LoggerTopButtons_Previews: PreviewProvider {

    static var previews: some View {
        LoggerTopButtons(logger: Logger.sharedInstance)
    }
}
