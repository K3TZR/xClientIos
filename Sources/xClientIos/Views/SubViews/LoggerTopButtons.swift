//
//  LoggerTrailer.swift
//  xClientIos
//
//  Created by Douglas Adams on 12/19/20.
//

import SwiftUI

struct LoggerTopButtons: View {
    @EnvironmentObject var logger: Logger
    
    var body: some View {
        HStack {
            Text("Show Level")
            Picker(logger.level.rawValue, selection: $logger.level) {
                ForEach(Logger.LogLevel.allCases, id: \.self) {
                    Text($0.rawValue)
                }
            }
            .frame(width: 175)
            
            Spacer()
            Text("Filter by")
            Picker(logger.filterBy.rawValue, selection: $logger.filterBy) {
                ForEach(Logger.LogFilter.allCases, id: \.self) {
                    Text($0.rawValue)
                }
            }.frame(width: 175)
            
            TextField("Filter text", text: $logger.filterByText).frame(maxWidth: 300, alignment: .leading)
                .background(Color(.separator))
            
            Spacer()
            Toggle(isOn: $logger.showTimestamps) {
                Text("Show Timestamps")
            }
        }
        .pickerStyle(MenuPickerStyle())
    }
}

struct LoggerTopButtons_Previews: PreviewProvider {
    static var previews: some View {
        LoggerTopButtons()
            .environmentObject(Logger.sharedInstance)
    }
}
