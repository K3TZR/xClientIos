//
//  CustomAlert.swift
//  xClientIos
//
//  Created by Douglas Adams on 12/31/20.
//

import SwiftUI
import UIKit

extension View {
    public func customAlert(isPresented: Binding<Bool>, _ alert: AlertParams) -> some View {
        CustomAlertWrapper(isPresented: isPresented, alert: alert, content: self)
    }
}

extension UIAlertController {
    
    convenience init(alert: AlertParams) {
        self.init(title: alert.title, message: alert.message, preferredStyle: .alert)
        
        for button in alert.buttons {
            let alertAction = UIAlertAction(title: button.text, style: button.text == "Cancel" ? .cancel : .default) { _ in
                button.action()
            }
            if button.color != nil { alertAction.setValue(button.color!, forKey: "titleTextColor") }
            addAction(alertAction)
        }
    }
}

// ----------------------------------------------------------------------------
// MARK: - Encapsulation of UIAlertController for SwiftUI

struct CustomAlertWrapper<Content: View>: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let alert: AlertParams
    let content: Content
    
    final class Coordinator {
        var alertController: UIAlertController?
        init(_ controller: UIAlertController? = nil) {
            self.alertController = controller
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<CustomAlertWrapper>) -> UIHostingController<Content> {
        UIHostingController(rootView: content)
    }
    
    func updateUIViewController(_ uiViewController: UIHostingController<Content>, context: UIViewControllerRepresentableContext<CustomAlertWrapper>) {
        uiViewController.rootView = content
        if isPresented && uiViewController.presentedViewController == nil {
            var alert = self.alert
            for (i, button) in alert.buttons.enumerated() {
                alert.buttons[i].action = {
                    self.isPresented = false
                    button.action()
                }
            }
            context.coordinator.alertController = UIAlertController(alert: alert)
            uiViewController.present(context.coordinator.alertController!, animated: true)
        }
        if !isPresented && uiViewController.presentedViewController == context.coordinator.alertController {
            uiViewController.dismiss(animated: true)
        }
    }
}
