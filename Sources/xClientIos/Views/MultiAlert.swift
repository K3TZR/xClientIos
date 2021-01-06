//
//  MultiAlert.swift
//  
//
//  Created by Douglas Adams on 12/31/20.
//

import SwiftUI
import UIKit

extension UIAlertController {
    
    convenience init(alert: MultiAlertParams) {
        self.init(title: alert.title, message: alert.message, preferredStyle: .alert)
        
        for button in alert.buttons {
            let alertAction = UIAlertAction(title: button.text, style: button.text == "Cancel" ? .cancel : .default) { _ in
                button.method()
            }
            alertAction.setValue(button.color, forKey: "titleTextColor")
            addAction(alertAction)
        }
    }
}

struct MultiAlertWrapper<Content: View>: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let alert: MultiAlertParams
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
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<MultiAlertWrapper>) -> UIHostingController<Content> {
        UIHostingController(rootView: content)
    }
    
    func updateUIViewController(_ uiViewController: UIHostingController<Content>, context: UIViewControllerRepresentableContext<MultiAlertWrapper>) {
        uiViewController.rootView = content
        if isPresented && uiViewController.presentedViewController == nil {
            var alert = self.alert
            for (i, button) in alert.buttons.enumerated() {
                alert.buttons[i].method = {
                    self.isPresented = false
                    button.method()
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



public typealias MultiAlertButton = (text: String, color: UIColor, method: () -> Void )

public struct MultiAlertParams {
    public var title        = ""
    public var message      = ""
    public var buttons      = [MultiAlertButton]()
}

extension View {
    public func multiAlert(isPresented: Binding<Bool>, _ alert: MultiAlertParams) -> some View {
        MultiAlertWrapper(isPresented: isPresented, alert: alert, content: self)
    }
}
