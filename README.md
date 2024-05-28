# UserDefaultsPlistEditor
This SwiftUI project provides an SPM utility which allows CRUD operations on the app UserDefaults or addressed Plist files. The content is displayed preserving the tree data structure

It requires minimum **iOS 15**, and has been coded on **Xcode 15.1**

The package exposes one SwiftUI view, which is to be presented modally (or within a window if you prefer).

It provides a `SampleApp` Xcode project within the package, linking the local SPM, which also allows you to play around with it and see how it works.

### Demo:

https://github.com/LucaIaco/UserDefaultsPlistEditor/assets/7451313/038f8f23-9787-41a9-8e05-bc95c63b8191

### Sample usage for the '**UserDefaults**' configuration:

```swift
import UserDefaultsPlistEditor

// Compact way:
UserDefaultsPlistEditor.MainView()
// Equivalent way:
UserDefaultsPlistEditor.MainView(config: .userDefaults(hideReservedKeys:true), readOnly: false, excludedKeys: [])
```

### Sample usage for the '**Plist**' configuration:

```swift
import UserDefaultsPlistEditor

let filesURLs = [plistURL1, plistURL2, ..., plistURLN]
UserDefaultsPlistEditor.MainView(config: .plists(filesURLs), excludedKeys: ["myExcludedKey1", "myExcludedKey2"])
```

### Sample usage in **UIKit** (eg from within a `UIViewController`)
```swift
import UserDefaultsPlistEditor

let vc = UIHostingController(rootView: UserDefaultsPlistEditor.MainView())
self.present(vc, animated: true)
```

As shown above, you can optionally enforce the read only mode with `readOnly`, so just allowing the visualization and the search over the list. As well, you can provide an explicit list of keys which shall be excluded from being displayed and added/edited, at **any level** of the tree, by passing them to the parameter `excludedKeys`.

### Description for the '**UserDefaults**' configuration: 
The `.userDefaults(hideReservedKeys:)` configuration enables you to perform CRUD actions over the `UserDefault.standard` as well as any other UserDefaults file automatically identified in your hosting app under the */Library/Preferences*. From the top-right navigation bar button item, you can add a new item directly to the root of the currently displayed `UserDefaults`, and, if more than one `UserDefaults` domain is found, you can choose among the resulting list, in order to visualize the corresponding `UserDefaults` bound to that domain. If the associated value `hideReservedKeys` is `true`, then it will **ATTEMPT** to hide the keys which are added in runtime by the OS in the dictionary representation of the `UserDefaults` 

(_**Note** regarding `hideReservedKeys`_: as we don't have a clear and full reliable list of Apple reserved keys adopted in the `UserDefaults`, we do achieve this by reading a different non existent `UserDefaults` and capturing his dictionary representation keys. Those keys are then filtered out from the actually displayed `UserDefaults` during the session. If the underlying behavior should change in future, you can always exclude the undesired keys by passing them explicitly in the initializer parameter `excludedKeys`)

### Description for the '**Plist**' configuration: 
The `.plist([URL])` configuration enables you perform CRUD actions over the addressed *Plist* files, as long as those are accessible for reading/writing (so, usually files within the sandbox of your hosting app). From the top-right navigation bar button item, you can add a new item directly to the root of the currently displayed *Plist* file, and, if more than one *Plist* file `URL` was provided in the configuration enum case, you can choose among the resulting list, in order to visualize the corresponding *Plist* file. This option allows you to operate on both *Plist* files with a root *Dictionary* as well as those with a root *Array*

### Supported types
The utility allows the addition / edit of the following types:
- `String`
- Number (`Int` or `Double`)
- `Date`
- `Bool`
- `Array`
- `Dictionary`

Regarding the `Array` and `Dictionary`, when adding them (directly in the root of the `UserDefaults` / *Plist file* or under a sub-node in the tree) will be added always empty. After saving the changes ( from the top-right navigation bar button item ), you can go back, and tap on them in order to add child nodes

### Limitations
At the moment, the parent node which owns an item that has been just altered in any way (edited, added a child, deleted, etc.) causes the list refresh to collapse that node again, and you need to manually expand the levels till the node you were looking at
