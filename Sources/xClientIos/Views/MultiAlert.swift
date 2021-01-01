//
//  MultiAlert.swift
//  
//
//  Created by Douglas Adams on 12/31/20.
//

import SwiftUI
import UIKit

extension UIAlertController {
    convenience init(alert: MultiAlert) {
        self.init(title: alert.title, message: alert.message, preferredStyle: .alert)
        for (i, button) in alert.buttons.enumerated() {
            addAction(UIAlertAction(title: button, style: .default) { _ in
                alert.action(i)
            })
        }
    }
}


struct AlertWrapper<Content: View>: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let alert: MultiAlert
    let content: Content
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<AlertWrapper>) -> UIHostingController<Content> {
        UIHostingController(rootView: content)
    }
    
    final class Coordinator {
        var alertController: UIAlertController?
        init(_ controller: UIAlertController? = nil) {
            self.alertController = controller
        }
        
        
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    func updateUIViewController(_ uiViewController: UIHostingController<Content>, context: UIViewControllerRepresentableContext<AlertWrapper>) {
        uiViewController.rootView = content
        if isPresented && uiViewController.presentedViewController == nil {
            var alert = self.alert
            alert.action = {
                self.isPresented = false
                self.alert.action($0)
            }
            context.coordinator.alertController = UIAlertController(alert: alert)
            uiViewController.present(context.coordinator.alertController!, animated: true)
        }
        if !isPresented && uiViewController.presentedViewController == context.coordinator.alertController {
            uiViewController.dismiss(animated: true)
        }
    }
}

public struct MultiAlert {
    public var title        = ""
    public var message      = ""
    public var buttons      = [String]()
    public var action       : (Int) -> () = { _ in }
}

extension View {
    public func multiAlert(isPresented: Binding<Bool>, _ alert: MultiAlert) -> some View {
        AlertWrapper(isPresented: isPresented, alert: alert, content: self)
    }
}
