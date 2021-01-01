//
//  LoggerHeader.swift
//  xClientIos package
//
//  Created by Douglas Adams on 12/19/20.
//

import SwiftUI
import MessageUI

struct LoggerBottomButtons: View {
    @EnvironmentObject var logger: Logger

    @State private var result: Result<MFMailComposeResult, Error>? = nil
    @State private var isShowingMailView = false
    
    @State private var mailFailed = false

    var body: some View {
        HStack {
            Stepper("Font Size", value: $logger.fontSize, in: 8...24).frame(width: 175)
            
            Spacer()
            
            Button("Email", action: {
                if MFMailComposeViewController.canSendMail() {
                    self.isShowingMailView.toggle()
                } else {
                    mailFailed = true
                }
            })
            .disabled(logger.openFileUrl == nil)
            .alert(isPresented: $mailFailed) {
                Alert(title: Text("Unable to send Mail"),
                      message:  Text(result == nil ? "" : String(describing: result)),
                      dismissButton: .cancel(Text("Cancel")))
            }
            .sheet(isPresented: $isShowingMailView) {
                MailView(result: $result) { composer in
                    composer.setSubject("\(logger.appName) Log")
                    composer.setToRecipients([logger.supportEmail])
                    composer.addAttachmentData(logger.getLogData()!, mimeType: "txt/plain", fileName: "\(logger.appName)Log.txt")
                }
            }
            
            Spacer()
            
            HStack (spacing: 20) {
                Button("Refresh", action: {logger.refreshLog() })
                Button("Load", action: {logger.loadLog() })
                    .alert(isPresented: $logger.showLoadLogAlert) {
                        Alert(title: Text("Unable to load Log file"),
                              message:  Text(""),
                              dismissButton: .cancel(Text("Cancel")))
                    }
            }
            
            Spacer()
            
            Button("Clear", action: {logger.clearLog() })
            
            Spacer()
            
            Button(action: {logger.backToMain() }) {Text("Back to Main")}
        }
    }
}

struct LoggerBottomButtons_Previews: PreviewProvider {
    
    static var previews: some View {
        LoggerBottomButtons()
            .environmentObject(Logger.sharedInstance)
    }
}

// https://stackoverflow.com/questions/56784722/swiftui-send-email
public struct MailView: UIViewControllerRepresentable {

    @Environment(\.presentationMode) var presentation
    @Binding var result: Result<MFMailComposeResult, Error>?
    public var configure: ((MFMailComposeViewController) -> Void)?

    public class Coordinator: NSObject, MFMailComposeViewControllerDelegate {

        @Binding var presentation: PresentationMode
        @Binding var result: Result<MFMailComposeResult, Error>?

        init(presentation: Binding<PresentationMode>,
             result: Binding<Result<MFMailComposeResult, Error>?>) {
            _presentation = presentation
            _result = result
        }

        public func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            defer {
                $presentation.wrappedValue.dismiss()
            }
            guard error == nil else {
                self.result = .failure(error!)
                return
            }
            self.result = .success(result)
        }
    }

    public func makeCoordinator() -> Coordinator {
        return Coordinator(presentation: presentation,
                           result: $result)
    }

    public func makeUIViewController(context: UIViewControllerRepresentableContext<MailView>) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        configure?(vc)
        return vc
    }

    public func updateUIViewController(
        _ uiViewController: MFMailComposeViewController,
        context: UIViewControllerRepresentableContext<MailView>) {

    }
}

