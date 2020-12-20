//
//  LoggerView.swift
//  xClientIos package
//
//  Created by Douglas Adams on 10/10/20.
//

import SwiftUI

/// A View to display the contents of the app's log
///
public struct LoggerView: View {
    @EnvironmentObject var logger: Logger
    
//    let width : CGFloat = 1000
    
    public init() {}
    
    public var body: some View {
        
        VStack {
            LoggerHeader()
            Divider().frame(height: 2).background(Color(.opaqueSeparator))

            LogLines()
            Divider().frame(height: 2).background(Color(.opaqueSeparator))

            LoggerTrailer()
        }
        .onAppear() {
            // initialize Logger with the default log
            let defaultLogUrl = URL(fileURLWithPath: URL.appSupport.path + "/" + "net.k3tzr" + "." + "TestIos" + "/Logs/" + "TestIos" + ".log")
            Logger.sharedInstance.loadLog(at: defaultLogUrl)
        }
//        .frame(minWidth: width, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
    }
}

public struct LoggerView_Previews: PreviewProvider {
    public static var previews: some View {
        LoggerView()
            .environmentObject( Logger.sharedInstance)
    }
}
