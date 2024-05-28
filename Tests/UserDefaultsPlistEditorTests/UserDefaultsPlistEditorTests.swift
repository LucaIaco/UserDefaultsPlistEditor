import XCTest
@testable import UserDefaultsPlistEditor

final class UserDefaultsPlistEditorTests: XCTestCase {
	
	// MARK: Properties
	
	private let baseSamplePlistURL = FileManager.default.urls(for: .documentDirectory, in:.userDomainMask).first!
	
	private var samplePlistFile1: URL { baseSamplePlistURL.appendingPathComponent("samplePlist1.plist") }
	
	// MARK: Setup & TearDown
	
	override func setUp() async throws {
		try await super.setUp()
		
		// Initialize the testing UserDefaults
		
		UserDefaults.standard.removeObject(forKey: "testUDKey1")
		UserDefaults.standard.removeObject(forKey: "testUDKey2")
		UserDefaults.standard.removeObject(forKey: "testUDKey3")
		
		UserDefaults.standard.set(true, forKey: "testUDKey1")
		UserDefaults.standard.set(["k1": 123,
								   "k2": "hello",
								   "k3": false,
								   "k4": "SomeData".utf8Data!,
								   "k5": Date(),
								   "k6": [1, false, 3, "abcd", Date()],
								   "k7": [
									"k7a": true,
									"k7b": 42,
									"k7c": "efgh"
								   ]
								  ], forKey: "testUDKey2")
		
		// Initialize the testing plist file
		
		// Sample Plist 1 with root item: Dictionary
		await writePlist(["testUDKey1": true,
						  "testUDKey2": ["k1": 123,
										 "k2": "hello",
										 "k3": false,
										 "k4": "SomeData".utf8Data!,
										 "k5": Date(),
										 "k6": [1, false, 3, "abcd", Date()],
										 "k7": [
											"k7a": true,
											"k7b": 42,
											"k7c": "efgh",
											"k7d": [
												true, 
												[
													"subVal",
													Date(),
													[1, "nestedTarget", 3]
												],
												121
											]
										 ]
								   ]
						 ], fileName: "samplePlist1")
	}
	
	override func tearDown() async throws {
		try await super.tearDown()
		
		// Remove the testing values before ending the test case
		UserDefaults.standard.removeObject(forKey: "testUDKey1")
		UserDefaults.standard.removeObject(forKey: "testUDKey2")
		UserDefaults.standard.removeObject(forKey: "testUDKey3")
		
		// Remove the testing plist file
		try? FileManager.default.removeItem(at: samplePlistFile1)
	}

	// MARK: Monster test cases o.o
    
	@MainActor func test1_UserDefaults() async throws {
        try await runtTest(mainViewModel: MainViewModel(config: .userDefaults(hideReservedKeys: true), readOnly: false, excludedKeys: ["sampleExcluded1"]), testingUserDefaults: true)
	}
	
	@MainActor func test2_Plists() async throws {
		
		// Test Plist with root node as dictionary
		
        try await runtTest(mainViewModel: MainViewModel(config: .plists([samplePlistFile1]), readOnly: false, excludedKeys: ["sampleExcluded1"]), testingUserDefaults: false)
	}
	
	// MARK: Private
	
    @MainActor private func runtTest(mainViewModel:MainViewModel, testingUserDefaults:Bool) async throws {
		
		// Test Main View Model
		
		await mainViewModel.updateDataset()
		XCTAssertFalse(mainViewModel.dataset.isEmpty)
		XCTAssertTrue(mainViewModel.dataset.contains(where: {
			guard let key = $0.key else { return false }
			return ["testUDKey1", "testUDKey2"].contains(key)
		}))
		
		// Test DELETE direct UserDefaults item
		XCTAssertNotNil(UserDefaults.standard.object(forKey: "testUDKey1"))
		let itemToDelete = try XCTUnwrap(mainViewModel.dataset.first(where: { $0.key == "testUDKey1" }))
		await mainViewModel.deleteItem(itemToDelete)
		XCTAssertFalse(mainViewModel.dataset.contains(where: { $0.key == "testUDKey1" }))
        if testingUserDefaults {
            XCTAssertNil(UserDefaults.standard.object(forKey: "testUDKey1"))
        }
		
		// Test ADD direct UserDefaults item
		let rootItem = mainViewModel.symbolicRootItem
		await mainViewModel.addOrEditItem(rootItem, newValue: true, addingKey: "testUDKey1", addingType: .boolean)
		XCTAssertTrue(mainViewModel.dataset.contains(where: { $0.key == "testUDKey1" }))
		XCTAssertNotNil(UserDefaults.standard.object(forKey: "testUDKey1"))
		
		// Test EDIT direct UserDefaults item
		let itemToEdit = try XCTUnwrap(mainViewModel.dataset.first(where: { $0.key == "testUDKey1" }))
		XCTAssertTrue((itemToEdit.value as? Bool) == true)
		await mainViewModel.addOrEditItem(itemToEdit, newValue: false)
		let itemEdited = try XCTUnwrap(mainViewModel.dataset.first(where: { $0.key == "testUDKey1" }))
		XCTAssertTrue((itemEdited.value as? Bool) == false)
        if testingUserDefaults {
			XCTAssertEqual(UserDefaults.standard.bool(forKey: "testUDKey1"), false)
		}
		
		// --------------------------------------------------
		
		// Test DELETE child node (non array)
		XCTAssertNotNil(UserDefaults.standard.object(forKey: "testUDKey2"))
		var childDictItem = try XCTUnwrap(mainViewModel.dataset.first(where: { $0.key == "testUDKey2" }))
		let childItemToDelete = try XCTUnwrap(childDictItem.children.first(where: { $0.key == "k2" }))
		await mainViewModel.deleteItem(childItemToDelete)
		childDictItem = try XCTUnwrap(mainViewModel.dataset.first(where: { $0.key == "testUDKey2" }))
		XCTAssertNil(childDictItem.children.first(where: { $0.key == "k2" }))
		
		// Test DELETE child node (array item)
		childDictItem = try XCTUnwrap(mainViewModel.dataset.first(where: { $0.key == "testUDKey2" }))
		var childArray = try XCTUnwrap(childDictItem.children.first(where: { $0.key == "k6" }))
		XCTAssertEqual(childArray.children.count, 5)
		let childItemToDelete1 = try XCTUnwrap(childArray.children[3]) // should be "abcd" item in the array
		XCTAssertEqual(childItemToDelete1.value as? String, "abcd")
		await mainViewModel.deleteItem(childItemToDelete1)
		childDictItem = try XCTUnwrap(mainViewModel.dataset.first(where: { $0.key == "testUDKey2" }))
		childArray = try XCTUnwrap(childDictItem.children.first(where: { $0.key == "k6" }))
		XCTAssertEqual(childArray.children.count, 4)
		XCTAssertNil(childArray.children.first(where: {
			guard let v = $0.value as? String else { return false }
			return v == "abcd"
		}))
		
		// Test EDIT child node (non array)
		XCTAssertNotNil(UserDefaults.standard.object(forKey: "testUDKey2"))
		childDictItem = try XCTUnwrap(mainViewModel.dataset.first(where: { $0.key == "testUDKey2" }))
		var childItemToEdit = try XCTUnwrap(childDictItem.children.first(where: { $0.key == "k1" }))
		XCTAssertEqual(childItemToEdit.value as? Int, 123)
		await mainViewModel.addOrEditItem(childItemToEdit, newValue: 456)
		childDictItem = try XCTUnwrap(mainViewModel.dataset.first(where: { $0.key == "testUDKey2" }))
		childItemToEdit = try XCTUnwrap(childDictItem.children.first(where: { $0.key == "k1" }))
		XCTAssertEqual(childItemToEdit.value as? Int, 456)
		
		// Test EDIT child node (array item)
		childDictItem = try XCTUnwrap(mainViewModel.dataset.first(where: { $0.key == "testUDKey2" }))
		childArray = try XCTUnwrap(childDictItem.children.first(where: { $0.key == "k6" }))
		XCTAssertEqual(childArray.children.count, 4)
		let childItemToEdit1 = try XCTUnwrap(childArray.children[2]) // should be `3` item in the array
		XCTAssertEqual(childItemToEdit1.value as? Int, 3)
		await mainViewModel.addOrEditItem(childItemToEdit1, newValue: 555)
		childDictItem = try XCTUnwrap(mainViewModel.dataset.first(where: { $0.key == "testUDKey2" }))
		childArray = try XCTUnwrap(childDictItem.children.first(where: { $0.key == "k6" }))
		XCTAssertEqual(childArray.children.count, 4)
		XCTAssertNotNil(childArray.children.first(where: {
			guard let v = $0.value as? Int else { return false }
			return v == 555
		}))
		
		// Test ADD child node (dict > new non-collection)
		XCTAssertNotNil(UserDefaults.standard.object(forKey: "testUDKey2"))
		childDictItem = try XCTUnwrap(mainViewModel.dataset.first(where: { $0.key == "testUDKey2" }))
		XCTAssertEqual(childDictItem.children.count, 6)
		await mainViewModel.addOrEditItem(childDictItem, newValue: 333, addingKey: "newKey1", addingType: .number)
		childDictItem = try XCTUnwrap(mainViewModel.dataset.first(where: { $0.key == "testUDKey2" }))
		XCTAssertEqual(childDictItem.children.count, 7)
		XCTAssertNotNil(childDictItem.children.first(where: {
			guard $0.key == "newKey1", let v = $0.value as? Int else { return false }
			return v == 333
		}))
		
		// Test ADD child node (dict > new dict)
		XCTAssertNotNil(UserDefaults.standard.object(forKey: "testUDKey2"))
		childDictItem = try XCTUnwrap(mainViewModel.dataset.first(where: { $0.key == "testUDKey2" }))
		XCTAssertEqual(childDictItem.children.count, 7)
		await mainViewModel.addOrEditItem(childDictItem, newValue: [String: Any](), addingKey: "newKey2", addingType: .dictionary)
		childDictItem = try XCTUnwrap(mainViewModel.dataset.first(where: { $0.key == "testUDKey2" }))
		XCTAssertEqual(childDictItem.children.count, 8)
		XCTAssertNotNil(childDictItem.children.first(where: {
			guard $0.key == "newKey2", let _ = $0.value as? [String: Any] else { return false }
			return true
		}))
		
		// Test ADD child node (dict > new array)
		XCTAssertNotNil(UserDefaults.standard.object(forKey: "testUDKey2"))
		childDictItem = try XCTUnwrap(mainViewModel.dataset.first(where: { $0.key == "testUDKey2" }))
		XCTAssertEqual(childDictItem.children.count, 8)
		await mainViewModel.addOrEditItem(childDictItem, newValue: [String: Any](), addingKey: "newKey3", addingType: .array)
		childDictItem = try XCTUnwrap(mainViewModel.dataset.first(where: { $0.key == "testUDKey2" }))
		XCTAssertEqual(childDictItem.children.count, 9)
		XCTAssertNotNil(childDictItem.children.first(where: {
			guard $0.key == "newKey3", let _ = $0.value as? [Any] else { return false }
			return true
		}))
		
		// Test ADD child node (array > new non-collection)
		XCTAssertNotNil(UserDefaults.standard.object(forKey: "testUDKey2"))
		childDictItem = try XCTUnwrap(mainViewModel.dataset.first(where: { $0.key == "testUDKey2" }))
		childArray = try XCTUnwrap(childDictItem.children.first(where: { $0.key == "k6" }))
		XCTAssertEqual(childArray.children.count, 4)
		await mainViewModel.addOrEditItem(childArray, newValue: "xyz", addingType: .string)
		childDictItem = try XCTUnwrap(mainViewModel.dataset.first(where: { $0.key == "testUDKey2" }))
		childArray = try XCTUnwrap(childDictItem.children.first(where: { $0.key == "k6" }))
		XCTAssertEqual(childArray.children.count, 5)
		XCTAssertEqual(childArray.children.last?.value as? String, "xyz")
		
		// Test ADD child node (array > new dictionary)
		XCTAssertNotNil(UserDefaults.standard.object(forKey: "testUDKey2"))
		childDictItem = try XCTUnwrap(mainViewModel.dataset.first(where: { $0.key == "testUDKey2" }))
		childArray = try XCTUnwrap(childDictItem.children.first(where: { $0.key == "k6" }))
		XCTAssertEqual(childArray.children.count, 5)
		await mainViewModel.addOrEditItem(childArray, newValue: [String: Any](), addingType: .dictionary)
		childDictItem = try XCTUnwrap(mainViewModel.dataset.first(where: { $0.key == "testUDKey2" }))
		childArray = try XCTUnwrap(childDictItem.children.first(where: { $0.key == "k6" }))
		XCTAssertEqual(childArray.children.count, 6)
		XCTAssertNotNil(childArray.children.last?.value as? [String: Any])
		
		// Test ADD child node (array > new array)
		XCTAssertNotNil(UserDefaults.standard.object(forKey: "testUDKey2"))
		childDictItem = try XCTUnwrap(mainViewModel.dataset.first(where: { $0.key == "testUDKey2" }))
		childArray = try XCTUnwrap(childDictItem.children.first(where: { $0.key == "k6" }))
		XCTAssertEqual(childArray.children.count, 6)
		await mainViewModel.addOrEditItem(childArray, newValue: [1,2,3,4], addingType: .array)
		childDictItem = try XCTUnwrap(mainViewModel.dataset.first(where: { $0.key == "testUDKey2" }))
		childArray = try XCTUnwrap(childDictItem.children.first(where: { $0.key == "k6" }))
		XCTAssertEqual(childArray.children.count, 7)
		XCTAssertNotNil(childArray.children.last?.value as? [Any])
		
		
		// Test EditView.Model - Edit
		var itemToEdit1 = try XCTUnwrap(mainViewModel.dataset.first(where: { $0.key == "testUDKey1" }))
		var editModel = EditView.ViewModel(mainViewModel: mainViewModel, item: itemToEdit1)
		XCTAssertTrue((editModel.fieldValue as? Bool) == false)
		editModel.fieldValue = true
		await editModel.applyChanges()
		itemToEdit1 = try XCTUnwrap(mainViewModel.dataset.first(where: { $0.key == "testUDKey1" }))
		XCTAssertTrue((itemToEdit1.value as? Bool) == true)
		
		// Test EditView.Model - Add
		editModel = EditView.ViewModel(mainViewModel: mainViewModel, item: mainViewModel.symbolicRootItem)
		editModel.fieldKey = "testUDKey3"
		editModel.fieldType = .string
		editModel.fieldValue = "test123"
		XCTAssertFalse(editModel.keyAlreadyExists)
		await editModel.applyChanges()
		XCTAssertTrue(mainViewModel.dataset.contains(where: {
			guard let key = $0.key else { return false }
			return key == "testUDKey3"
		}))
		
		// TEST Search filter (eg last nested item in the tree)
		mainViewModel.filterText = "test123"
		await mainViewModel.updateDataset()
		XCTAssertTrue(mainViewModel.dataset.count == 1)
		
		// TEST for Plist only
        if !testingUserDefaults {
			mainViewModel.filterText = "nestedTarget"
			await mainViewModel.updateDataset()
			var item = try XCTUnwrap(mainViewModel.dataset.first)
			while !item.children.isEmpty {
				item = try XCTUnwrap(item.children.first)
			}
			
			// TEST Editing item in double nested array
			editModel = EditView.ViewModel(mainViewModel: mainViewModel, item: item)
			editModel.fieldValue = "nestedTarget123"
			await editModel.applyChanges()
			var itemModified = try XCTUnwrap(mainViewModel.dataset.first)
			while !itemModified.children.isEmpty {
				itemModified = try XCTUnwrap(itemModified.children.first)
			}
			let modifiedValue = try XCTUnwrap(itemModified.value as? String)
			XCTAssertEqual(modifiedValue, "nestedTarget123")
		}
		
	}
	
	@discardableResult private func writePlist(_ rootNode: Any, fileName:String) async -> Bool {
		let url = baseSamplePlistURL.appendingPathComponent("\(fileName).plist")
		do {
			let writeData = try PropertyListSerialization.data(fromPropertyList: rootNode, format: .xml, options:0)
			try writeData.write(to: url)
			return true
		} catch {
			return false
		}
	}
	
}
