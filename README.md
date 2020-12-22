### xClientIos [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://en.wikipedia.org/wiki/MIT_License)

#### iOS Client for use with xLib6000.

##### Built on:

*  macOS 11.1
*  Xcode 12.3 (12C33)
*  Swift 5.3

##### Runs on:
* iOS 13 and higher

##### Builds
Compiled  [RELEASE builds](https://github.com/K3TZR/xClientIos/releases) will be created at relatively stable points, please use them.  If you require a DEBUG build you will have to build from sources. 

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
##### 0.9.2 Release Notes
* changed SwiftyUserDefaults dependency  to "from 5.1.0" (new tag to fix iOS 8 warning)
* updated to xLib6000 v1.6.7 (for iOS v14 requirement)
* added KeychainItemAccessibility.swift & KeychainWrapper.swift (iOS keychain access)
* modified TokenStore.swift to use iOS Keychain
* changes in RadioManagerDelegate protocol to resolve SwiftUI issues
* changes in Logger.swift to supposrt iOS LogView
* numerous changes in RadioManager.swift to support iOS
* changes in WanManager to use iOS version of TokenStore
* lots of changes to view formatting
* added Email ability to LogView
* added (basic) App Icon
* many corrections throughout

##### 0.9.1 Release Notes
* uses newer xLIb6000 which uses newer CocoaAsyncSocket (7.6.5) to eliminate iOS 8 warning
* uses master branch of SwiftyUserDefaults to eliminate iOS 8 warning

##### 0.9.0 Release Notes
