//
//  Config.swift
//  UserDefaultsPlistEditor
//
//  Created by Luca Iaconis on 13.04.2024.
//

import Foundation

/// The set of possible configurations to be used for displaying the module
public enum Config: Equatable {
	/// This option indicates that the module will operates on the UserDefaults
	case userDefaults
	/// This option indicates that the module will operates on the addresses Plist files from the provided `URL` array
	case plists([URL])
	
	public static func == (lhs: Self, rhs: Self) -> Bool {
		switch (lhs, rhs) {
		case (.userDefaults, .userDefaults), (.plists, .plists): return true
		default: return false
		}
	}
}
