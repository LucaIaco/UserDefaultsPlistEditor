//
//  MainViewModel.swift
//  UserDefaultsPlistEditor
//
//  Created by Luca Iaconis on 14.04.2024.
//

import SwiftUI

	
struct EditView: View {
	
	// MARK: Properties
	
	@StateObject private var viewModel: EditView.ViewModel
	
	@State private var hasPendingChanges = false
	
	@State private var keyErrorMsg:String?
	
	/// Indicates if the toolbar save button should be enabled or not
	private var saveBtnDisabled: Bool {
		if viewModel.item.type == .dictionary {
			guard !viewModel.fieldKey.trimmed.isEmpty else { return true }
			guard !viewModel.keyAlreadyExists else { return true }
            guard !viewModel.keyIsExcluded else { return true }
		}
		return !hasPendingChanges
	}
	
	// MARK: Init
	
	init(mainViewModel: MainViewModel, item: DataItem) {
		_viewModel = StateObject(wrappedValue: .init(mainViewModel: mainViewModel, item: item))
	}
	
	// MARK: Body view
	
	var body: some View {
		Form {
			introSection
			typeSection
			keySection
			valueSection
		}
		.textSelection(.enabled).textInputAutocapitalization(.never).autocorrectionDisabled()
		.toolbar {
			Button {
				self.hasPendingChanges = false
				Task(priority: .background) { await viewModel.applyChanges() }
			} label: { Text("Save") }
				.disabled(self.saveBtnDisabled)
		}.onChange(of: viewModel.fieldsHash) { _ in
            if viewModel.keyAlreadyExists {
                self.keyErrorMsg = "This key is already used in this dictionary"
            } else if viewModel.keyIsExcluded {
                self.keyErrorMsg = "This key is among the `excludedKeys` set and cannot be used"
            } else { self.keyErrorMsg = nil }
            
			self.hasPendingChanges = true
		}.onChange(of: viewModel.fieldType) { _ in
			if viewModel.isAddingChild {
				viewModel.fieldValue = viewModel.fallbackValue
			}
	   }
	}
	
	// MARK: Private
	
	private var introSection: some View {
		let introTxt:LocalizedStringKey
		switch viewModel.item.type {
		case .dictionary:
			if let key = viewModel.item.key {
				introTxt = "Add a new key-value pair to this **Dictionary** referred by the key **\(key)**"
			} else if let index = viewModel.item.index {
				introTxt = "Add a new key-value pair to this **Dictionary**, whose index in his parent array is **\(index)**"
			} else {
				introTxt = "Add a new key-value pair to this root **Dictionary**"
			}
		case .array:
			if let key = viewModel.item.key {
				introTxt = "Add a new child value to this **Array** referred by the key **\(key)**"
			} else if let index = viewModel.item.index {
				introTxt = "Add a new child value to this **Array**, whose index in his parent array is **\(index)**"
			} else {
				introTxt = "Add a new child value to this root **Array**"
			}
		default: introTxt = "Edit the value for this item"
		}
		return SwiftUI.Section {
			Text(introTxt)
		}
	}
	
	private var typeSection: some View {
		Group {
			if viewModel.isAddingChild {
				Picker(selection: $viewModel.fieldType, label: Text("Type") ) {
					let types = ItemType.allCases
						.filter({ ![.data, .unknown].contains($0) })
						.sorted(by: { $0.rawValue < $1.rawValue })
					ForEach(types, id: \.self) { Text($0.rawValue.capitalized) }
				}.pickerStyle(.menu)
			} else {
				SwiftUI.Section("Type") {
					Text(viewModel.fieldType.rawValue.capitalized)
				}
			}
		}
	}
	
	private var keySection: some View {
		Group {
			if viewModel.item.type == .array || (!viewModel.isAddingChild && viewModel.item.index != nil) {
				EmptyView()
			} else {
				SwiftUI.Section(viewModel.item.type == .dictionary ? "Key (Modifiable)" : "Key") {
					if viewModel.item.type == .dictionary {
						TextField("Enter a key", text: $viewModel.fieldKey)
						if let keyErrorMsg {
							Text(keyErrorMsg).font(.callout).foregroundStyle(Color.red)
						}
					} else {
						Text(viewModel.fieldKey)
					}
				}
			}
		}
	}
	
	private var valueSection: some View {
		SwiftUI.Section("Value\(viewModel.fieldType.isCollection ? "" : " (Modifiable)")") {
			if !viewModel.fieldType.isCollection {
				switch viewModel.fieldType {
				case .string:
					let bindString = Binding {
						(viewModel.fieldValue as? String) ?? ""
					} set: { newVal in viewModel.fieldValue = newVal }
					TextEditor(text: bindString)
						.frame(maxHeight: 300, alignment: .leading)
				case .boolean:
					let bindBool = Binding {
						(viewModel.fieldValue as? Bool) ?? false
					} set: { newVal in viewModel.fieldValue = newVal }
					Toggle("State", isOn: bindBool)
				case .number:
					let bindNumber = Binding {
						let number = (viewModel.fieldValue as? NSNumber) ?? NSNumber(value: 0)
						return number.stringValue
					} set: { newVal in
						guard !newVal.trimmed.isEmpty else { viewModel.fieldValue = nil; return }
						let formatter = NumberFormatter()
						formatter.numberStyle = .decimal
						let number = formatter.number(from: newVal)
						viewModel.fieldValue = number
					}
					TextField("Enter a number", text: bindNumber)
				case .date:
					let bindNumber = Binding {
						let number = NSNumber(value: (viewModel.fieldValue as? Date)?.timeIntervalSince1970 ?? Date().timeIntervalSince1970)
						return number.stringValue
					} set: { newVal in
						guard !newVal.trimmed.isEmpty else { viewModel.fieldValue = nil; return }
						let formatter = NumberFormatter()
						formatter.numberStyle = .decimal
						let number = formatter.number(from: newVal)
						if let ts = number?.doubleValue {
							viewModel.fieldValue = Date(timeIntervalSince1970: ts)
						} else {
							viewModel.fieldValue = nil
						}
					}
					let bindDate = Binding(get: { viewModel.fieldValue as? Date ?? Date() }, set: { newDate in viewModel.fieldValue = newDate })
					DatePicker("", selection: bindDate, displayedComponents: [.date, .hourAndMinute] ).labelsHidden()
					
					TextField("Enter a timestamp (since 1970)", text: bindNumber)
				default:
					EmptyView()
				}
			} else {
				Text("Setting the value for a new item of type **\(viewModel.fieldType.rawValue.capitalized)** is not supported in this step. Once created, you can go back and add a \(viewModel.fieldType == .dictionary ? "key-value pair" : "child value" ) to this newly created item")
			}
		}
	}
	
}

// MARK: - EditView.ViewModel
extension EditView {
	
	/// The view model for the `EditView`
	@MainActor
	final class ViewModel: ObservableObject {
		
		// MARK: Properties
		
		@Published
		var fieldKey: String
		
		@Published
		var fieldValue: Any?
		
		@Published
		var fieldType: ItemType = .string
		
		/// Indicates if the user is attempting to add a new key-value pair to this `item` as `dictionary` or a new value to this `item` as `array`
		var isAddingChild: Bool { item.type.isCollection }
		
		/// Indicates if the currently inserted key already exists in the addressed viewModel item, in case this is of type `dictionary`
		var keyAlreadyExists:Bool {
			guard item.type == .dictionary else { return false }
			guard let dictItem = item.value as? [String: Any] else { return true }
			return dictItem.keys.contains(fieldKey.trimmed)
		}
        
        /// Indicates if the currently inserted key is among the set of excluded keys, and therefore cannot be used (in case this is of type `dictionary`)
        var keyIsExcluded:Bool {
            guard item.type == .dictionary else { return false }
            return mainViewModel?.excludedKeys.contains(fieldKey.trimmed) ?? false
        }
		
		/// Hash represantation of the fieldd constellation
		fileprivate var fieldsHash:Data? { "\(fieldKey)\(String(describing: fieldValue))\(fieldType)".utf8Data }
		
		private(set) var item: DataItem
		
		private weak var mainViewModel: MainViewModel?
		
		/// Returns the fallback (empty) value for the current `fieldType`
		var fallbackValue: Any? {
			switch fieldType {
			case .string: return ""
			case .number: return 0
			case .boolean: return false
			case .date: return Date()
			default: return nil
			}
		}
		
		// MARK: Init
		
		init(mainViewModel: MainViewModel, item: DataItem) {
			self.mainViewModel = mainViewModel
			self.item = item
			self.fieldKey = ""
			self.fieldValue = fallbackValue
			if !self.isAddingChild {
				self.fieldKey = item.key ?? ""
				self.fieldValue = item.value
				self.fieldType = item.type
			}
		}
		
		// MARK: Public
		
		func applyChanges() async {
			if self.isAddingChild {
				// Perform 'fallback' value validation
				let newValue = fieldValue ?? fallbackValue
				let newKey = fieldKey.trimmed.isEmpty ? nil : fieldKey.trimmed
				await mainViewModel?.addOrEditItem(item, newValue: newValue,
												   addingKey: newKey, addingType: fieldType)
			} else {
				switch fieldType {
				case .string, .boolean, .number, .date:
					await mainViewModel?.addOrEditItem(item, newValue: fieldValue)
				default: break
				}
			}
		}
		
	}
		
}
