//
//  LoggerTrailer.swift
//  
//
//  Created by Douglas Adams on 12/19/20.
//

import SwiftUI

struct LoggerTrailer: View {
    @EnvironmentObject var logger: Logger

    var body: some View {
        HStack(alignment: .center, spacing: 30) {
            Text("Level")
            Picker(logger.level.rawValue, selection: $logger.level) {
                ForEach(Logger.LogLevel.allCases, id: \.self) {
                    Text($0.rawValue)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(width: 75, alignment: .leading)
            
            Text("Filter by")
            Picker(logger.filterBy.rawValue, selection: $logger.filterBy) {
                ForEach(Logger.LogFilter.allCases, id: \.self) {
                    Text($0.rawValue)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(width: 75, alignment: .leading)

            TextField("Filter text", text: $logger.filterByText)
                .background(Color(.secondarySystemBackground))
            
            Toggle("Timestamps", isOn: $logger.showTimestamps).fixedSize(horizontal: true, vertical: true)
            
            HStack {
                Button("Load", action: {logger.loadLog() })
                Spacer()
                Button("Save", action: {logger.saveLog() })                
                Spacer()
                Button("Refresh", action: {logger.refresh() })
            }
        }
        .padding(.horizontal, 20)
    }
}

struct LoggerTrailer_Previews: PreviewProvider {
    static var previews: some View {
        LoggerTrailer()
    }
}
