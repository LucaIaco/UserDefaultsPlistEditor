//
//  MainView.swift
//  UserDefaultsPlistEditor
//
//  Created by Luca Iaconis on 13.04.2024.
//

import SwiftUI

/// The `UserDefaultsPlistEditor` root component view editor
public struct MainView: View {
	
	// MARK: Properties
	
	@StateObject private var viewModel:MainViewModel
	
	/// The item which is being edited and causes the `EditView` to be pushed
	@State private var editingItem: DataItem?
	
	/// The navigaiton bar title
	private var mainViewTitle: String {
		switch viewModel.config {
		case .userDefaults: return "UserDefaults mode"
		case .plists: return "Plist mode"
		}
	}
	
	// MARK: Initializer
    
    /// Initializes the `UserDefaultsPlistEditor` SwiftUI main view
    /// - Parameters:
    ///   - config: the configuration to be used. Default is `.userDefaults`
    ///   - readOnly: whether the component should be used in read only or allow modifications. Defaults is `false` (allow all)
	public init(config: Config = .userDefaults, readOnly:Bool = false) {
		_viewModel = StateObject(wrappedValue: .init(config: config, readOnly: readOnly))
	}
	
	// MARK: Body view
	
	public var body: some View {
		NavigationView {
			VStack(alignment: .leading, spacing: 5) {
				if !viewModel.dataset.isEmpty {
					// Display the header view
					Group {
						navigationToEditView()
						HStack(spacing: 4) {
							Text("Number of root keys:")
							Text("\(viewModel.dataset.count)").bold().foregroundColor(.primary)
						}
						Divider()
					}
					// Display the list of items
					List {
						ForEach(viewModel.dataset) { item in
							rowView(item)
								.listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
						}
					}
					.listStyle(.plain)
				} else {
					Text("No content available")
						.multilineTextAlignment(.center)
						.foregroundStyle(.secondary)
						.frame(maxHeight: .infinity)
				}
			}
			.padding([.leading, .trailing], nil)
			.searchable(text: $viewModel.filterText, placement:.navigationBarDrawer(displayMode: .always))
			.autocorrectionDisabled(true)
			.onLoad({ Task { await viewModel.updateDataset() } })
			.onChange(of: viewModel.filterText) { _ in
				Task { await viewModel.updateDataset() }
			}
			.onChange(of: viewModel.selectedUserDefaultsDomain) { _ in
				Task { await viewModel.updateDataset() }
			}
			.onChange(of: viewModel.selectedPlistURL) { _ in
				Task { await viewModel.updateDataset() }
			}
			.transform { view in toolbar(view) }
			.navigationTitle(mainViewTitle)
			.navigationBarTitleDisplayMode(.inline)
		}
	}
	
	// MARK: Private
	
	@ViewBuilder private func rowView(_ item:DataItem) -> some View {
		NodeView(item: item, action: { selItem in
			ButtonAlertView(item: selItem) { itm in
				Text(itm.title).badge(itm.children.count)
			} alertMessage: { itm in
				if let key = itm.key {
					Text(key)
				} else {
					EmptyView()
				}
			} alertActions: { itm in
				Button("Copy to clipboard") {
					UIPasteboard.general.string = String(itm.title.characters)
				}
				if !viewModel.isReadOnly {
					if itm.editable {
						let btnEditTitle = itm.type == .dictionary ?
						"Add new key-value" : itm.type == .array ? "Add new child value" : "Edit"
						Button(btnEditTitle) {
							editingItem = itm
						}
					}
					Button("Delete", role: .destructive) {
						Task { await viewModel.deleteItem(itm) }
					}
				}
				Button("Cancel", role: .cancel, action: {})
			}
		})
	}
	
	/// Builds and returns the view and his logic to push to the EditView for the `editingItem`
	/// - Returns: the navigation link to the view
	@ViewBuilder private func navigationToEditView() -> some View {
		let dest = { () -> AnyView in
			if let editingItem {
				return AnyView(EditView(mainViewModel: viewModel, item: editingItem))
			} else { return AnyView(EmptyView()) }
		}()
		let isEditing = Binding<Bool> {
			editingItem != nil
		} set: { newState in if newState == false { editingItem = nil } }
		NavigationLink(isActive: isEditing) { dest } label: { EmptyView() }.isDetailLink(false).hidden()
	}
	
	/// Builds and return the toolbar with the contenxt menu with futher filter options
	@ViewBuilder private func toolbar<T: View>(_ view: T) -> some View {
		view.toolbar {
			Menu {
				if !viewModel.isReadOnly {
					Button {
						// This will initiate the addition of a new key-value in the edit view, to be added
						// directly to the currently selected user defaults
						editingItem = viewModel.symbolicRootItem
					} label: {
						HStack {
							if viewModel.symbolicRootItem.type == .dictionary {
								Text("Add new key-value")
							} else {
								Text("Add new value")
							}
							Image(systemName: "plus.circle")
						}
					}
				}
				
				// Source selection
				switch viewModel.config {
				case .userDefaults:
					SwiftUI.Section {
						Text("UserDefaults domains")
						SwiftUI.Picker("", selection: $viewModel.selectedUserDefaultsDomain) {
							ForEach(viewModel.userDefaultsDomains, id: \.self) { domain in
								Text(domain).tag(domain)
							}
						}
					}
				case .plists(let plistURLs):
					if let selectedURL = viewModel.selectedPlistURL {
						let bindSelection = Binding(get: { selectedURL }) { newURL in
							viewModel.selectedPlistURL = newURL
						}
						SwiftUI.Section {
							Text("Plist files")
							SwiftUI.Picker("", selection: bindSelection) {
								ForEach(plistURLs, id: \.self) { url in
									Text(url.lastPathComponent).tag(url)
								}
							}
						}
					}
				}
			} label: {
				Image(systemName: "ellipsis.circle")
			}
		}
	}
	
}

// MARK: - MainView.NodeView
extension MainView {
	
	struct NodeView<V:View>: View {
		
		// MARK: Properties
		
		@State var item: DataItem
		@State private var expanded:Bool = false
		let action:(DataItem) -> V
		
		// MARK: Init
		
		init(item: DataItem, @ViewBuilder action: @escaping (DataItem) -> V) {
			self._item = State(wrappedValue: item)
			self.action = action
		}
		
		// MARK: Body view
		
		var body: some View {
			if item.children.isEmpty {
				action(item)
			} else {
				DisclosureGroup(
					isExpanded: $expanded,
					content: {
						ForEach(item.children) { child in
							if child.children.isEmpty {
								action(child)
							} else {
								NodeView(item: child, action: action)
							}
						}
					},
					label: {
						action(item)
					}
				)
			}
		}
	}
	
}
