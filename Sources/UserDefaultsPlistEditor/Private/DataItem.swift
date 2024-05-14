//
//  IADebugUserDefaultsModule.swift
//  UserDefaultsPlistEditor
//
//  Created by Luca Iaconis on 13.04.2024.
//

import SwiftUI

/// The data item representing a single entry in the Plist tree
struct DataItem: Identifiable {
	
	let id:Data
	let value: Any
	let type: ItemType
	let children: [DataItem]
	let title: AttributedString
	/// The source key path starting from the root, which leads to this item in the tree
	let paths:[String]
	
	/// In a dictionary structure, is the key which in the parent dictionary addresses this item
	var key: String? {
		guard let lastPath = paths.last?.trimmed else { return nil }
		return Self.key(for: lastPath)
	}
	
	/// The index of this item if represented within a `DataItem` of type `array`
	var index:Int? {
		guard let lastPath = paths.last?.trimmed else { return nil }
		return Self.index(for: lastPath)
	}
	
	/// Prefix used to distinguish a path which holds a dictionary key
	private static let prefixForKey = "___k_"
	
	/// Prefix used to distinguish a path which holds an array index
	private static let prefixForIndex = "___ix_"
	
	/// Indicates if this item can be edited.
	///
	/// For collections, it means that user can add key-value pairs (if a dictionary) or values (if an array).
	var editable:Bool { ![.data, .unknown].contains(type) }
	
	// MARK: Init
	
	init?(key:String?, value:Any, filterTxt:String, paths:[String] = [], index:Int? = nil) {
		self.value = value
		self.type = .init(from: value)
		var p = paths
		if let key {
			p.append("\(Self.prefixForKey)\(key.trimmed)")
		} else if let index {
			p.append("\(Self.prefixForIndex)\(index)")
		}
		self.paths = p
		
		self.children = Self.children(paths: self.paths, value: value, type: self.type, filterTxt: filterTxt)
		self.title = Self.title(key: key, value: value, type: self.type, filterTxt: filterTxt)
		self.id = "\(self.paths.joined(separator: "|"))_\(filterTxt)_\(self.value)".utf8Data!.sha256
		// filter out the item in case a search term is provided and there's no match in the title item iself or in his children (in case those exists and have been in turn filtered out)
		if !filterTxt.isEmpty,
		   !String(title.characters).trimmed.lowercased().contains(filterTxt.trimmed.lowercased()),
			self.children.isEmpty {
			return nil
		}
	}
	
	// MARK: Public
	
	/// Helper method to return the dictionary key from the given raw path string
	/// - Parameter path: the raw path string to be evaluated
	/// - Returns: the resulting key, or `nil` if not a valid key
	static func key(for path: String) -> String? {
		let parts = path.components(separatedBy: Self.prefixForKey)
		guard parts.count == 2, let lastPart = parts.last?.trimmed, !lastPart.isEmpty else { return nil }
		return lastPart
	}
	
	/// Helper method to return the array index from the given raw path string
	/// - Parameter path: the raw path string to be evaluated
	/// - Returns: the resulting index integer, or `nil` if not a valid one
	static func index(for path:String) -> Int? {
		let parts = path.components(separatedBy: Self.prefixForIndex)
		guard parts.count == 2, let lastPart = parts.last?.trimmed, !lastPart.isEmpty else { return nil }
		return Int(lastPart)
	}
	
	// MARK: Private
	
	/// Returns the string representation of the value for this item
	/// - Parameter value: the value to represent
	/// - Returns: the resulting string
	private static func representableValue(_ value:Any) -> String {
		let valStr:String
		if let d = value as? Date {
			valStr = "\(d.localReprestationWithLocale)\n(Timestamp: \(d.timeIntervalSince1970))"
		} else if let b = Self.boolValue(value) {
			valStr = b ? "true" : "false"
		} else { valStr = "\(value)" }
		return valStr
	}
	
	/// Returns the attributed text representation of this `DataItem`
	/// - Parameters:
	///   - key: If available, the key which is used in the `UserDefaults` to address this item
	///   - value: The actual value represented by this `DataItem`
	///   - type: The determined type of the `value`
	///   - filterTxt: If provided, is the searching terms to highlight in the `title`
	/// - Returns: the resulting attributed string title
	private static func title(key:String?, value:Any, type:ItemType, filterTxt:String ) -> AttributedString {
		let prefixStr = "(\(type.rawValue.capitalized)) | "

		var prefixAttr: AttributedString
		if let key {
			prefixAttr = AttributedString("\(prefixStr)\(key)")
		} else {
			prefixAttr = AttributedString("\(prefixStr)")
		}
		prefixAttr.foregroundColor = .init(.secondary)
		prefixAttr.font = .init(.callout)
		var result = prefixAttr
		if !type.isCollection {
			result += AttributedString("\n\(Self.representableValue(value))")
		}
		
		if !filterTxt.isEmpty { result.highlight(filterTxt) }
		return result
	}
	
	/// Generates and returns the tree of the children starting from the given `value`, IF the value is a collection
	/// - Parameters:
	///   - paths: If provided, the keys path associated to given item
	///   - value: The node to evaluate and, if a collection, to traverse
	///   - type: The determined type of the `value`
	///   - filterTxt: If provided, is the searching terms to use for filtering the items
	/// - Returns: the resulting array of children under the given `value`
	private static func children(paths:[String], value:Any, type:ItemType, filterTxt:String) -> [DataItem] {
		guard type.isCollection else { return [] }
		if let valArray = value as? Array<Any> {
			var ix = 0
			return valArray.compactMap {
				let item = DataItem(key: nil, value: $0, filterTxt: filterTxt, paths: paths, index: ix)
				ix += 1
				return item
			}
		} else if let valDict = value as? Dictionary<String, Any> {
			var result: [DataItem] = []
			result = valDict.compactMap({ (key: String, val: Any) in
				.init(key: key, value: val, filterTxt: filterTxt, paths: paths)
			})
			// sort the dataset by keys if possible
			result.sort { lhs, rhs in
				guard let k1 = lhs.key, let k2 = rhs.key else { return true }
				return k1 < k2
			}
			return result
		} else {
			return []
		}
	}
	
	/// Helper method which returns the bool value from the provided `Any` value. It makes sure that
	/// the NSNumber(1|0) won't get confused with True/False, checking the core foundation exact type
	/// - Parameter v: the value to evaluate
	/// - Returns: the bool value, or `nil` if cannot be processed as boolean
	fileprivate static func boolValue(_ v:Any) -> Bool? {
		guard let nV = v as? NSNumber else { return nil }
		guard nV === kCFBooleanTrue || nV === kCFBooleanFalse else { return nil }
		return v as? Bool
	}
}
	
// MARK: - ItemType

/// Set of supported `UserDefaults` types (Plist)
enum ItemType: String, CaseIterable {
   case string
   case number
   case boolean
   case data
   case date
   case array
   case dictionary
   case unknown
   
   /// Indicates if this type is a Dictionary or an Array
   var isCollection: Bool { [.dictionary, .array].contains(self) }
   
   init(from item:Any) {
	   switch item {
	   case is String: self = .string
	   case is any Numeric: self = .number
	   case is NSNumber: self = DataItem.boolValue(item) != nil ? .boolean : . number
	   case is Data: self = .data
	   case is Date: self = .date
	   case is Array<Any>: self = .array
	   case is Dictionary<String, Any>: self = .dictionary
	   default: self = .unknown
	   }
   }
}

