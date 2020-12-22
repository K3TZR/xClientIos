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
    
    public init() {}
    
    public var body: some View {
        
        VStack {
            LoggerTopButtons()
            Divider().frame(height: 2).background(Color(.opaqueSeparator))

            LoggerLines()
            Divider().frame(height: 2).background(Color(.opaqueSeparator))
            
            LoggerBottomButtons()
        }
        .onAppear() {
            // initialize Logger with the default log
            let defaultLogUrl = URL(fileURLWithPath: URL.appSupport.path + "/" + logger.domain + "." + logger.appName + "/Logs/" + logger.appName + ".log")
            Logger.sharedInstance.loadLog(at: defaultLogUrl)
        }
    }
}

public struct LoggerView_Previews: PreviewProvider {
    public static var previews: some View {
        LoggerView()
            .environmentObject( Logger.sharedInstance)
    }
}

