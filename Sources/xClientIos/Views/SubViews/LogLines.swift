//
//  LogMiddleView.swift
//  
//
//  Created by Douglas Adams on 12/19/20.
//

import SwiftUI

struct LogLines: View {
    @EnvironmentObject var logger: Logger
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                ForEach(logger.logLines) { line in
                    Text(line.text)
                        .font(.system(size: CGFloat(logger.fontSize), weight: .regular, design: .monospaced))
                    //                    .frame(minWidth: width, maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

struct LogLines_Previews: PreviewProvider {
    static var previews: some View {
        LogLines()
    }
}
