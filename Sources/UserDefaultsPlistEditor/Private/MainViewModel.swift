//
//  MainViewModel.swift
//  UserDefaultsPlistEditor
//
//  Created by Luca Iaconis on 13.04.2024.
//

import SwiftUI

@MainActor
final class MainViewModel: ObservableObject {
	
	// MARK: Propeties (Misc)
	
	@Published
	var dataset:[DataItem] = []
	
	@Published
	var filterText:String = ""
	
	let config:Config
	
	/// Indicates if the configuration for this module allows to Add / Edit / Delete fields or if is just read-only
	private(set) var isReadOnly = false
	
	/// Creates and return a `DataItem` which represent itself the selected source
	///
	/// This is used to create a new key-value directly to the source rather than a child node
	var symbolicRootItem:DataItem { .init(key: nil, value: selectedSource, filterTxt: "")! }
	
	/// The selected source data (eg. UserDefaults or Plist file root dictionary or array)
	private var selectedSource: Any {
		switch config {
		case .userDefaults:
			return selectedUserDefaults?.dictionaryRepresentation() ?? [:]
		case .plists:
			guard let selectedPlistURL else { return [:] }
			guard let result = plistContent(selectedPlistURL) else { return [:] }
			return result
		}
	}
	
	// MARK: Properties (UserDefaults)
	
	/// The currently selected user default domain, used to retrieve the UserDefaults when config is `userDefaults`
	@Published
	var selectedUserDefaultsDomain:String = MainViewModel.standardUserDefaultsString
	
	/// The key used to identify the `UserDefaults.standard`
	private static let standardUserDefaultsString = "Standard"
	
	/// The available list of `UserDefaults` domain strings
	private(set) var userDefaultsDomains = [MainViewModel.standardUserDefaultsString]
	
	/// The `UserDefaults` instance associated to the `selectedUserDefaultsDomain`
	private var selectedUserDefaults:UserDefaults? {
		guard selectedUserDefaultsDomain != MainViewModel.standardUserDefaultsString else { return .standard }
		return UserDefaults(suiteName: selectedUserDefaultsDomain)
	}
	
	// MARK: Properties (Plists)
	
	@Published
	var selectedPlistURL:URL?
	
	// MARK: Initializer
	
	/// Initializes the view model
	/// - Parameters:
	///   - config: the configuration to be adopted
	///   - readOnly: whether the module should be used in read-only or allow add/edit/delete
	init(config: Config, readOnly:Bool) {
		self.config = config
		self.isReadOnly = readOnly
		switch config {
		case .plists(let array): selectedPlistURL = array.first
		case .userDefaults: userDefaultsDomains = retrieveUserDefaultsDomains()
		}
	}
	
	// MARK: Public
	
	/// Updates the dataset displayed in the view from the currently selected source
	func updateDataset() async {
		self.dataset = await withCheckedContinuation({ continuation in
			Task(priority: .background) { [weak self] in
				guard let self else {
					continuation.resume(returning: [])
					return
				}
				// get the representation from the current user defaults, and populate the dataset
				var result:[DataItem] = []
				if let sourceDict = selectedSource as? [String: Any] {
					result = sourceDict.compactMap { (key: String, value: Any) in
						.init(key: key, value: value, filterTxt: self.filterText.trimmed)
					}
					// sort the dataset by keys if possible
					result.sort { lhs, rhs in
						guard let k1 = lhs.key, let k2 = rhs.key else { return true }
						return k1 < k2
					}
				} else if let sourceArray = selectedSource as? [Any] {
					var ix = 0
					result = sourceArray.compactMap({ value in
						let item = DataItem(key: nil, value: value, filterTxt: self.filterText.trimmed, index: ix)
						ix += 1
						return item
					})
				}
				continuation.resume(returning: result)
			}
		})
	}
	
	/// If NOT readOnly, deletes the given item from the selected user defaults and refreshes the list
	///
	/// Note: some keys are OS reserved and attempting to delete them might simply not affect
	/// the UserDefaults
	///
	/// - Parameter item: the referred item to delete
	func deleteItem(_ item:DataItem) async {
		guard !self.isReadOnly else { return }
		guard let rootPath = item.paths.first else { return }
		// If the addressed item is a direct item in the source, just remove it
		guard item.paths.count > 1 else {
			sourceRemoveObject(from: rootPath)
			await updateDataset()
			return
		}
		let updatedObj = self.traverseTree(source: selectedSource, paths: item.paths) { parentNode, key, index in
			if var mParentDict = parentNode as? [String: Any], let key {
				// Remove the value at the given key path
				mParentDict.removeValue(forKey: key)
				return mParentDict
			} else if var mParentArray = parentNode as? [Any], let index {
				// Remove the value at the given index
				mParentArray.remove(at: index)
				return mParentArray
			} else {
				return parentNode
			}
		}
		// Update the root node owning that path
		if let updDict = updatedObj as? [String: Any], let rootKey = DataItem.key(for: rootPath) {
			guard let updatedRootObj = updDict[rootKey] else { return }
			sourceSet(updatedRootObj, key: rootKey)
		} else if let updArray = updatedObj as? [Any], let rootIx = DataItem.index(for: rootPath) {
			sourceSet(updArray[rootIx], index: rootIx)
		}
		
		await updateDataset()
	}
	
	/// If NOT readOnly, adds a new node under a given item or updates the given item directly, in the user defaults,
	/// and refreshes the list
	/// - Parameters:
	///   - item: the referred item to update
	///   - newValue: the new value to set. This is ignored if `addingType` is equal to `dictionary` or `array`
	///   - addingKey: if we aim to add a new node to the addressed `item` node, this will be the key which identifies it, if the value behind `item` is itself a dictionary
	///   - addingType: if we aim to add a new node to the addressed `item` note, this will be the type of the new object which will be created and added
	func addOrEditItem(_ item:DataItem, newValue:Any?, addingKey:String? = nil, addingType:ItemType? = nil) async {
		guard !self.isReadOnly else { return }
		// Check if the add/edit is intended to happen to any child of the source tree, or instead is
		// intended to be applied to the source tree root itself
		guard let rootPath = item.paths.first else {
			var valueToAdd: Any?
			if let newValue {
				valueToAdd = newValue
			} else if let addingType, addingType.isCollection {
				switch addingType {
				case .array: valueToAdd = [Any]()
				case .dictionary: valueToAdd = [String:Any]()
				default: break
				}
			}
			// If a key is provided, we aim to set the value in the root source dictionary for the given key
			// otherwise, we aim to add/append the value in the root source array
			if let addingKey {
				sourceSet(valueToAdd, key: addingKey)
			} else {
				sourceSet(valueToAdd)
			}
			
			await updateDataset()
			return
		}
		
		// local closure for handling the addition/update of a sub array
		let handleSubArray = { (subArray:[Any]) in
			var mSubArr = subArray
			if let addingType {
				// Add a new object of type `addingType` to the identified node array
				switch addingType {
				case .array: mSubArr.append([Any]())
				case .dictionary: mSubArr.append([String:Any]())
				default: if let newValue { mSubArr.append(newValue) }
				}
			} else if let newValue, let index = item.index {
				// Update the value at the given index
				mSubArr[index] = newValue
			}
			return mSubArr
		}
		
		// local closure for handling the addition/update of a sub dictionary
		let handlSubDict = { (subDict:[String: Any]) in
			var mSubDict = subDict
			// Add a new object of type `addingType` to the identified node dictionary
			guard let addingType, let aKey = addingKey?.trimmed, !aKey.isEmpty else { return subDict }
			switch addingType {
			case .array: mSubDict[aKey] = [Any]()
			case .dictionary: mSubDict[aKey] = [String:Any]()
			default: if let newValue { mSubDict[aKey] = newValue }
			}
			return mSubDict
		}
		
		let updatedObj = self.traverseTree(source: selectedSource, paths: item.paths) { parentNode, key, index in
			if var mParentDict = parentNode as? [String: Any], let key {
				if let subArr = mParentDict[key] as? [Any] {
					mParentDict[key] = handleSubArray(subArr)
				} else if let subDict = mParentDict[key] as? [String:Any] {
					mParentDict[key] = handlSubDict(subDict)
				} else if let newValue {
					// Update the value at the given key path
					mParentDict[key] = newValue
				}
				return mParentDict
			} else if var mParentArray = parentNode as? [Any], let index {
				if let subArr = mParentArray[index] as? [Any] {
					mParentArray[index] = handleSubArray(subArr)
				} else if let subDict = mParentArray[index] as? [String:Any] {
					mParentArray[index] = handlSubDict(subDict)
				} else if let newValue {
					// Update the value at the given key path
					mParentArray[index] = newValue
				}
				return mParentArray
			} else {
				return parentNode
			}
		}
		
		// Update the root node owning that path
		if let updDict = updatedObj as? [String: Any], let rootKey = DataItem.key(for: rootPath) {
			guard let updatedRootObj = updDict[rootKey] else { return }
			sourceSet(updatedRootObj, key: rootKey)
		} else if let updArray = updatedObj as? [Any], let rootIx = DataItem.index(for: rootPath) {
			sourceSet(updArray[rootIx], index: rootIx)
		}
		
		await updateDataset()
	}
	
	// MARK: Private
	
	/// Traverses the tree-structure in the node based on the given `paths`, and executes the via the `onLeafAction` closure when found (Recursive function)
	/// - Parameters:
	///   - source: the source (node) to traverse
	///   - paths: the path to follow in order to traverse the tree
	///   - onLeafAction: the closure to execute when we reach the end of the path (leaf)
	/// - Returns: the resulting full dictionary after having performed any change in the `onLeafAction`
	private func traverseTree(source: Any, paths:[String], onLeafAction:(Any, String?, Int?) -> Any ) -> Any {
		var p = paths
		guard !p.isEmpty else { return source }
		let path = p.removeFirst()
		// If this was the last path, execute the final action on the found leaf
		guard !p.isEmpty else {
			return onLeafAction(source, DataItem.key(for: path), DataItem.index(for: path))
		}
		
		if let srcAsDict = source as? [String: Any], let key = DataItem.key(for: path) {
			var mDict = srcAsDict
			guard let subSource = mDict[key] else { return source }
			mDict[key] = traverseTree(source: subSource, paths: p, onLeafAction: onLeafAction)
			return mDict
		} else if let srcAsArray = source as? [Any], let ix = DataItem.index(for: path) {
			var mArray = srcAsArray
			guard ix < mArray.count else { return source }
			let subSource = mArray[ix]
			mArray[ix] = traverseTree(source: subSource, paths: p, onLeafAction: onLeafAction)
			return mArray
		} else {
			return source
		}
	}
	
	/// This method removes the object for the given key, in the currently selected source
	/// - Parameter path: The path to refer to in order to extract the key or the index needed to perform the action
	private func sourceRemoveObject(from path: String) {
		switch config {
		case .userDefaults:
			guard let key = DataItem.key(for: path) else { return }
			selectedUserDefaults?.removeObject(forKey: key)
		case .plists:
			guard let selectedPlistURL else { return }
			let srcObj = selectedSource
			if var srcDict = srcObj as? [String: Any], let key = DataItem.key(for: path) {
				srcDict.removeValue(forKey: key)
				writePlist(srcDict, url: selectedPlistURL)
			} else if var srcArray = srcObj as? [Any], let ix = DataItem.index(for: path) {
				srcArray.remove(at: ix)
				writePlist(srcArray, url: selectedPlistURL)
			}
		}
	}
	
	/// This method stores/set a value for the given key in the currently selected source
	/// - Parameters:
	///   - value: The object to store in the source
	///   - key: If provided, is the explicit key with which to associate the value in the parent dictionary
	///   - index: If provided, is the explicity index at which to store the value in the parent array. In case the source is an array, and no index is provided, then the value will be appended to the array
	private func sourceSet(_ value: Any?, key: String? = nil, index: Int? = nil) {
		switch config {
		case .userDefaults:
			guard let key else { return }
			selectedUserDefaults?.set(value, forKey: key)
		case .plists:
			guard let selectedPlistURL else { return }
			guard let value else { return }
			let srcObj = selectedSource
			if var srcDict = srcObj as? [String: Any], let key {
				srcDict[key] = value
				writePlist(srcDict, url: selectedPlistURL)
			} else if var srcArray = srcObj as? [Any] {
				if let index {
					srcArray[index] = value
				} else {
					srcArray.append(value)
				}
				writePlist(srcArray, url: selectedPlistURL)
			}
		}
	}
	
	/// Retrieves the list of `UserDefaults` domains, by fetching the content of '/Libary/Preferences' in the app
	/// - Returns: the resulting list of preferences domains
	private func retrieveUserDefaultsDomains() -> [String] {
		var result:[String] = [MainViewModel.standardUserDefaultsString]
		guard let appId = Bundle.main.bundleIdentifier else { return result }
		guard var path = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else { return result }
		if #available(iOS 16.0, *) {
			path.append(path: "Preferences")
		} else {
			path = path.appendingPathComponent("Preferences")
		}
		// get all the plist files except for the `standard` which we already have
		guard let plists = try? FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) else { return result }
		let domains:[String] = plists.compactMap({ plistURL in
			guard plistURL.pathExtension == "plist", plistURL.lastPathComponent != "\(appId).plist" else { return nil }
			var cmp = plistURL.lastPathComponent.components(separatedBy: ".")
			cmp.removeLast()
			return cmp.joined(separator: ".")
		}).sorted()
		result.append(contentsOf: domains)
		return result
	}
	
	/// Reads and return the Plist content of the file at the given `url`
	/// - Parameter url: the url to the Plist file to load
	/// - Returns: the Plist content (Dictionary or Array) or `nil` on error
	private func plistContent(_ url:URL) -> Any? {
		do {
			let data = try Data(contentsOf: url)
			return try PropertyListSerialization.propertyList(from: data, format: nil)
		} catch {
			return nil
		}
	}
	
	/// Writes the Plist content on disk at the given `url`
	/// - Parameters:
	///   - rootNode: the data structure content to be persisted on disk
	///   - url: the destination file url
	/// - Returns: `true` on success, `false` otherwise
	@discardableResult private func writePlist(_ rootNode: Any, url:URL) -> Bool {
		do {
			let writeData = try PropertyListSerialization.data(fromPropertyList: rootNode, format: .xml, options:0)
			try writeData.write(to: url)
			return true
		} catch {
			return false
		}
	}
	
}

