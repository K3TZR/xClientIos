//
//  Keychain.swift
//  xClientIos
//
//  Created by Mario Illgen on 12.02.18.
//  Copyright © 2018 Mario Illgen. All rights reserved.
//

import Foundation
import Security

// ----------------------------------------------------------------------------
// MARK: - Class definition
// ----------------------------------------------------------------------------

final class TokenStore {
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private var _wrapper : KeychainWrapper
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    init(service: String) {
        _wrapper = KeychainWrapper(serviceName: service)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    public func set(account: String, data: String) {
        _wrapper.set(data, forKey: account)
    }
    
    public func get(account: String) -> String? {
        return _wrapper.string(forKey: account)
    }
    
    public func delete(account: String) -> Bool{
        return _wrapper.removeObject(forKey: account)
    }
}

//    static func set(_ service: String, account: String, data: String) {
//        var item: SecKeychainItem? = nil
//
//        var status = SecKeychainFindGenericPassword(
//            nil,
//            UInt32(service.utf8.count),
//            service,
//            UInt32(account.utf8.count),
//            account,
//            nil,
//            nil,
//            &item)
//
//        if status != noErr && status != errSecItemNotFound {
//            Logger.sharedInstance.logMessage("Error finding keychain item to modify: \(status), \(SecCopyErrorMessageString(status, nil) ?? "" as CFString)", .debug,  #function, #file, #line)
//            return
//        }
//
//        if item != nil {
//            status = SecKeychainItemModifyContent(item!, nil, UInt32(data.utf8.count), data)
//        } else {
//            status = SecKeychainAddGenericPassword(
//                nil,
//                UInt32(service.utf8.count),
//                service,
//                UInt32(account.utf8.count),
//                account,
//                UInt32(data.utf8.count),
//                data,
//                nil)
//        }
//
//        if status != noErr {
//            Logger.sharedInstance.logMessage("Error setting keychain item: \(SecCopyErrorMessageString(status, nil) ?? "" as CFString)", .debug,  #function, #file, #line)
//        }
//    }
//
//    static func get(_ service: String, account: String) -> String? {
//        var passwordLength: UInt32 = 0
//        var password: UnsafeMutableRawPointer? = nil
//
//        let status = SecKeychainFindGenericPassword(
//            nil,
//            UInt32(service.utf8.count),
//            service,
//            UInt32(account.utf8.count),
//            account,
//            &passwordLength,
//            &password,
//            nil)
//
//        if status == errSecSuccess {
//            guard password != nil else { return nil }
//            let result = NSString(bytes: password!, length: Int(passwordLength), encoding: String.Encoding.utf8.rawValue) as String?
//            SecKeychainItemFreeContent(nil, password)
//            return result
//        }
//
//        return nil
//    }
//
//    static func delete(_ service: String, account: String) {
//        var item: SecKeychainItem? = nil
//
//        var status = SecKeychainFindGenericPassword(
//            nil,
//            UInt32(service.utf8.count),
//            service,
//            UInt32(account.utf8.count),
//            account,
//            nil,
//            nil,
//            &item)
//
//        if status == errSecItemNotFound {
//            return
//        }
//
//        if status != noErr {
//            Logger.sharedInstance.logMessage("Error finding keychain item to delete: \(SecCopyErrorMessageString(status, nil) ?? "" as CFString)", .debug,  #function, #file, #line)
//        }
//
//        if item != nil {
//            status = SecKeychainItemDelete(item!)
//        }
//
//        if status != noErr {
//            Logger.sharedInstance.logMessage("Error deleting keychain item: \(SecCopyErrorMessageString(status, nil) ?? "" as CFString)", .debug,  #function, #file, #line)
//        }
//    }
//}
