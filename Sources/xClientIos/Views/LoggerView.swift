//
//  LoggerView.swift
//  xClientIos
//
//  Created by Douglas Adams on 10/10/20.
//

import SwiftUI

/// A View to display the contents of the app's log
///
public struct LoggerView: View {
    @EnvironmentObject var logger : Logger
    
    public init() {}
    
    public var body: some View {
        
        VStack {
            LoggerTopButtons()
            Divider().frame(height: 2).background(Color(.separator))

            LoggerLines()
            Divider().frame(height: 2).background(Color(.separator))
            
            LoggerBottomButtons()
        }
        .frame(minWidth: 700)
        .padding(.horizontal)
        .padding(.vertical, 10)
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

