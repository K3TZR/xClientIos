//
//  LoggerTrailer.swift
//  
//
//  Created by Douglas Adams on 12/19/20.
//

import SwiftUI
import MessageUI


struct LoggerTopButtons: View {
    @EnvironmentObject var logger: Logger

    @State private var result: Result<MFMailComposeResult, Error>? = nil
    @State private var isShowingMailView = false

    var body: some View {
        HStack {
            Text("Show Level")
            Picker(logger.level.rawValue, selection: $logger.level) {
                ForEach(Logger.LogLevel.allCases, id: \.self) {
                    Text($0.rawValue)
                }
            }.pickerStyle(MenuPickerStyle())
            
            Spacer()
            
            Text("Filter by")
            Picker(logger.filterBy.rawValue, selection: $logger.filterBy) {
                ForEach(Logger.LogFilter.allCases, id: \.self) {
                    Text($0.rawValue)
                }
            }.pickerStyle(MenuPickerStyle())
            
            TextField("Filter text", text: $logger.filterByText).frame(maxWidth: 300, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                  
            Spacer()
            
            Toggle(isOn: $logger.showTimestamps) {
                Text("Show Timestamps")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }.frame(maxWidth: 160, alignment: .center)
            
            Spacer()
            
            HStack (spacing: 20) {
                Button("Email", action: {
                    if MFMailComposeViewController.canSendMail() {
                        self.isShowingMailView.toggle()
                    } else {
                        print("Can't send emails from this device")
                    }
                    if result != nil {
                        print("Result: \(String(describing: result))")
                    }
                }).disabled(logger.openFileUrl == nil)
                .sheet(isPresented: $isShowingMailView) {
                    MailView(result: $result) { composer in
                        composer.setSubject("\(logger.appName) Log")
                        composer.setToRecipients([logger.supportEmail])
                        composer.addAttachmentData(logger.getLogData()!, mimeType: "txt/plain", fileName: "\(logger.appName)Log.txt")
                    }
                }
                
                Button("Refresh", action: {logger.refresh() })
            }
        }
    }
}

struct LoggerTopButtons_Previews: PreviewProvider {
    static var previews: some View {
        LoggerTopButtons()
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
