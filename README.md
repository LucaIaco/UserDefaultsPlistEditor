# UserDefaultsPlistEditor
This SwiftUI project provides an SPM utility which allows CRUD operations on the app UserDefaults or addressed Plist files. 

It requires minimum **iOS 15**, and has been coded on **Xcode 15.1**

The package exposes one SwiftUI view, which is to be presented modally (or within a window if you prefer).

It provides a `SampleApp` Xcode project within the package, linking the local SPM, which also allows you to play around with it and see how it works.

### Sample usage for the '**UserDefaults**' configuration:

```swift
// Compact way:
UserDefaultsPlistEditor.MainView()
// Equivalent way:
UserDefaultsPlistEditor.MainView(config: .userDefaults, readOnly: false)
```

### Sample usage for the '**Plist**' configuration:

```swift
let filesURLs = [plistURL1, plistURL2, ..., plistURLN]
UserDefaultsPlistEditor.MainView(config: .plists(filesURLs), readOnly: false)
```

As shown above, you can optionally enforce the read only mode, so just allowing the visualization and the search over the list

### Description for the '**UserDefaults**' configuration: 
The `.userDefaults` configuration enables you perform CRUD actions over the `UserDefault.standard` as well as any other UserDefaults file automatically identified in your hosting app under the */Library/Preferences*. From the top-right navigation bar button item, you can add a new item directly to the root of the currently displayed `UserDefaults`, and, if more than one `UserDefaults` domain is found, you can choose among the resulting list, in order to visualize the corresponding `UserDefault` bound to that domain

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

Regarding the `Array` and Dictionary, when adding them (directly in the root of the `UserDefaults` / *Plist file* or under a sub-node in the tree) will be added always empty. After saving the changes ( from the top-right navigation bar button item ), you can go back, and tap on them in order to add child nodes

### Limitations
At the moment, the parent node which owns an item that has been just altered in any way (edited, added a child, deleted, etc.) causes the list refresh to collapse that node again, and you need to manually expand the levels till the node you were looking at