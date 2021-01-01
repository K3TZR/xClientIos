//
//  LogMiddleView.swift
//  xClientIos package
//
//  Created by Douglas Adams on 12/19/20.
//

import SwiftUI

struct LoggerLines: View {
    @EnvironmentObject var logger: Logger
    
    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            VStack(alignment: .leading) {
                ForEach(logger.logLines) { line in
                    Text(line.text)
                        .font(.system(size: CGFloat(logger.fontSize), weight: .regular, design: .monospaced))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct LoggerLines_Previews: PreviewProvider {

    static var previews: some View {
        LoggerLines()
            .environmentObject(Logger.sharedInstance)
    }
}
