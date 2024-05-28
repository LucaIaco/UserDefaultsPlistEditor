//
//  Config.swift
//  UserDefaultsPlistEditor
//
//  Created by Luca Iaconis on 13.04.2024.
//

import Foundation

/// The set of possible configurations to be used for displaying the module
public enum Config: Identifiable {
	/// This option indicates that the module will operates on the UserDefaults.
    /// - hideReservedKeys: if `true` **it will try** to hide the runtime reserved root keys which are added by the OS. If `false`, you'll get the whole root dataset. **Note**: reserved keys might not be practically editable
    case userDefaults(hideReservedKeys:Bool)
	/// This option indicates that the module will operates on the addresses Plist files from the provided `URL` array
	case plists([URL])
    
    public var id: String {
        switch self {
        case .userDefaults: "userDefaults"
        case .plists: "plists"
        }
    }
}
