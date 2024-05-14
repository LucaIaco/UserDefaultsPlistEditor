//
//  ContentView.swift
//  SampleApp
//
//  Created by Luca Iaconis on 20.04.2024.
//

import SwiftUI
import UserDefaultsPlistEditor

struct ContentView: View {
    
    // MARK: Properties
    
    @State var shownConfig:UserDefaultsPlistEditor.Config?
    
    private let baseSamplePlistURL: URL = FileManager.default.urls(for: .documentDirectory, in:.userDomainMask).first!
    
    private var samplePlistFiles: [URL] {
        [
            baseSamplePlistURL.appendingPathComponent("samplePlist1.plist"),
            baseSamplePlistURL.appendingPathComponent("samplePlist2.plist"),
            baseSamplePlistURL.appendingPathComponent("samplePlist3.plist")
        ]
    }
    
    // MARK: Body view
    
    var body: some View {
        VStack(spacing:20) {
            
            Text("This sample project shows how to present and operate with the *UserDefaultsPlistEditor* compoment. It an nutshell: \n\n- It allows CRUD actions on the **UserDefaults.standard** as well as any other UserDefaults automatically found under the *Library/Preferences* path of the app sandbox.\n\n- It allows CRUD actions on a generic **Plist** file (or a set of Plist files from the given *URL*) as long as those are accessible, usually in the app sandbox as well")
            
            let showView = Binding(get: { shownConfig != nil }, set: { if !$0 { shownConfig = nil }})
            Button("Show with **.userDefaults**") {
                createSampleExtraUserDefaultsIfNeeded()
                shownConfig = .userDefaults
            }
            Button("Show with **.plists([URL])**", action: {
                Task {
                    await createSamplePlistFilesIfNeeded()
                    shownConfig = .plists(samplePlistFiles)
                }
            })
            .sheet(isPresented: showView, content: {
                UserDefaultsPlistEditor.MainView(config: shownConfig ?? .userDefaults, readOnly: false)
            })
        }
        .padding()
    }
    
    // MARK: Private
    
    private func createSampleExtraUserDefaultsIfNeeded() {
        guard let ud = UserDefaults(suiteName: "com.sampleDomain.sampleApp") else { return }
        guard ud.object(forKey: "sampleAppKey") == nil else { return }
        ud.set("Sample value. This is used by the sample project to create the additional UserDefaults file", forKey: "sampleAppKey")
    }
    
    private func createSamplePlistFilesIfNeeded(forceCreate:Bool = false) async {
        guard let fURL = samplePlistFiles.first else { return }
        guard !FileManager.default.fileExists(atPath: fURL.path) || forceCreate else { return }
        // Sample Plist 1 with root item: Dictionary
        await writePlist(["key1": true,
                          "key2": "samplePlist1_SomeString",
                          "key3": Date(),
                          "key4": 123,
                          "key5": 10.5,
                          "key6": [1, "someValue", true, false, 100.3, Date(),
                                   ["key6_subKey1": "apple", "key6_subKey2": true],
                                   [10,20,30,40,50]],
                          "key7": ["key7_subKey1": false, "key7_subKey2": [1,2,3,4,5]]
                   ], fileName: "samplePlist1")
        
        // Sample Plist 2 with root item: Dictionary
        await writePlist(["key1": "samplePlist2_SomeString",
                          "key2": false,
                          "key3": 0,
                          "key4": 999,
                          "key5": Date(),
                          "key6": ["key6_subKey2": false, "key6_subKey1": [1,2,3,4,5]],
                          "key7": ["someValue", 1, false, 999.1, Date(),
                                   ["key7_subKey1": "apple", "key7_subKey2": 13],
                                   ["a","b","c","d", true]]
                   ], fileName: "samplePlist2")
        
        // Sample Plist 3 with root item: Array
        await writePlist([true,
                          0,
                          Date(),
                          "SampleString",
                          256.5,
                          ["key1": ["key1_subKey2": false, "key1_subKey1": [1,2,3,4,5]]],
                          ["a", "b", "c", "d"]
                         ], fileName: "samplePlist3")
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
