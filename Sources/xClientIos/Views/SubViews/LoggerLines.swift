//
//  LogMiddleView.swift
//  xClientIos
//
//  Created by Douglas Adams on 12/19/20.
//

import SwiftUI

struct LoggerLines: View {
    @ObservedObject var logger: Logger
    
    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            ScrollViewReader { scrollView in
                VStack(alignment: .leading) {
                    ForEach(logger.logLines) { line in
                        Text(line.text)
                            .font(.system(size: CGFloat(logger.fontSize), weight: .regular, design: .monospaced))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: logger.logLines.count, perform: { _ in
                    if logger.logLines.count > 0 {
                        scrollView.scrollTo(logger.logLines.last!.id, anchor: .bottomLeading)
                    }
                })
            }
        }
    }
}

struct LoggerLines_Previews: PreviewProvider {
    
    static var previews: some View {
        LoggerLines(logger: Logger.sharedInstance)
    }
}
