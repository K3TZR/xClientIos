### xClientIos [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://en.wikipedia.org/wiki/MIT_License)

#### Swift Package for use in an iOS Client. It provides the "boilerplate" capabilites needed by an iOS app communicating with a Flex 6000 radio using xLib6000.

##### Built on:

*  macOS 11.1
*  Xcode 12.3 (12C33)
*  Swift 5.3

##### Runs on:
* iOS 13 and higher/Users/doug/Dropbox/Code/xClientIos/Sources/xClientIos/Supporting/JWT.swift

##### Builds
This is a Swift Package, no executables are created.

##### Comments / Questions
Please send any bugs / comments / questions to support@k3tzr.net

##### Credits
[xLib6000](https://github.com/K3TZR/xLib6000.git)
[SwiftyUserDefaults](https://github.com/sunshinejr/SwiftyUserDefaults.git)
[XCGLogger](https://github.com/DaveWoodCom/XCGLogger.git)

##### Other software
[![DL3LSM](https://img.shields.io/badge/DL3LSM-xDAX,_xCAT,_xKey-informational)](https://dl3lsm.blogspot.com) Mac versions of DAX and/or CAT and a Remote CW Keyer.  
[![W6OP](https://img.shields.io/badge/W6OP-xVoiceKeyer,_xCW-informational)](https://w6op.com) A Mac-based Voice Keyer and a CW Keyer.  

---
##### 1.0.0 Release Notes
* initial release
* reworked to more closely resemble xClientMac

##### 0.9.10 Release Notes
* continuing development

##### 0.9.9 Release Notes
* continuing development

##### 0.9.8 Release Notes
* restored the use of a RadioManagerDelegate
* corrected the functioning of sheets, specifically the PickerView

##### 0.9.7 Release Notes
* continuing development

##### 0.9.6 Release Notes
* continuing development

##### 0.9.5 Release Notes
* continuing development

##### 0.9.4 Release Notes
* lots of changes to view formatting
* added Email ability to LoggerView
* added (basic) App Icon
* many corrections throughout

##### 0.9.3 Release Notes
* changed SwiftyUserDefaults dependency  to "from 5.1.0" (new tag to fix iOS 8 warning)
* updated to xLib6000 v1.6.7 (for iOS v14 requirement)
* added KeychainItemAccessibility.swift & KeychainWrapper.swift (iOS keychain access)
* modified TokenStore.swift to use iOS Keychain
* changes in RadioManagerDelegate protocol to resolve SwiftUI issues
* changes in Logger.swift to supposrt iOS LogView
* numerous changes in RadioManager.swift to support iOS
* changes in WanManager to use iOS version of TokenStore

##### 0.9.2 Release Notes
* changed SwiftyUserDefaults back to "from 5.0.0"

##### 0.9.1 Release Notes
* uses newer xLIb6000 which uses newer CocoaAsyncSocket (7.6.5) to eliminate iOS 8 warning
* uses master branch of SwiftyUserDefaults to eliminate iOS 8 warning

##### 0.9.0 Release Notes
