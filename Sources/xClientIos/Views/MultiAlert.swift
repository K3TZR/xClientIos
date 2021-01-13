//
//  MultiAlert.swift
//  xClientIos
//
//  Created by Douglas Adams on 12/31/20.
//

import SwiftUI
import UIKit

//public typealias MultiAlertButton = (text: String, color: UIColor?, method: () -> Void )

public struct MultiParams {
    public var title        = ""
    public var message      = ""
    public var buttons      = [MultiButton]()
}

public struct MultiButton {
    public var text     : String
    public var color    : UIColor?
    public var perform  : () -> Void
    
    init(text: String, method: @escaping () -> Void = {}, color: UIColor? = nil) {
        self.text = text
        self.color = color
        self.perform = method
    }
}

extension View {
    public func multiAlert(isPresented: Binding<Bool>, _ alert: MultiParams) -> some View {
        MultiAlertWrapper(isPresented: isPresented, alert: alert, content: self)
    }
}

extension UIAlertController {
    
    convenience init(alert: MultiParams) {
        self.init(title: alert.title, message: alert.message, preferredStyle: .alert)
        
        for button in alert.buttons {
            let alertAction = UIAlertAction(title: button.text, style: button.text == "Cancel" ? .cancel : .default) { _ in
                button.perform()
            }
            if button.color != nil { alertAction.setValue(button.color!, forKey: "titleTextColor") }
            addAction(alertAction)
        }
    }
}

// ----------------------------------------------------------------------------
// MARK: - Encapsulation of UIAlertController for SwiftUI

struct MultiAlertWrapper<Content: View>: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let alert: MultiParams
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
                alert.buttons[i].perform = {
                    self.isPresented = false
                    button.perform()
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
