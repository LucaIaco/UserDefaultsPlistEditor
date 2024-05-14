//
//  Extensions.swift
//  UserDefaultsPlistEditor
//
//  Created by Luca Iaconis on 13.04.2024.
//

import SwiftUI
import CryptoKit

extension String {
	
	/// Returns the last path component of the string if this is represented as a path
	var lastPathComponent:String { (self as NSString).lastPathComponent }
	
	/// Returns the UTF-8 representation of this string
	var utf8Data: Data? { self.data(using: .utf8) }
	
	/// The trimmed representation of this string
	var trimmed:String { self.trimmingCharacters(in:.whitespacesAndNewlines) }
}

extension Data {
	
	/// Return the SHA-256 data representation of this data instance
	var sha256:Data { Data(SHA256.hash(data: self)) }
}

extension Date {
	
	/// Intenral date formatter using current timezone
	private static let localRepresentationFormatter:DateFormatter = {
		let df = DateFormatter()
		df.dateFormat = "dd-MM-yyyy HH:mm:ss.SS"
		df.timeZone = TimeZone.current
		return df
	}()
	
	// String representation of the date. Eg. "01/02/2020 15:10:05.12 (Europe/Rome)"
	var localReprestationWithLocale:String {
		"\(Self.localRepresentationFormatter.string(from: self)) (\(TimeZone.current.identifier))"
	}
}

extension AttributedString {
	
	/// Highlights the match of a given string in this attributed string
	/// - Parameters:
	///   - search: the string to search and highlight
	///   - highlightColor: the highlight color
	mutating func highlight(_ search:String, highlightColor:Color = .yellow) {
		guard !search.isEmpty, let range = self.range(of: search, options: .caseInsensitive) else { return }
		self[range].backgroundColor = highlightColor
	}
}

// MARK: - SwiftUI - View extensions
extension View {
	
	/// This modifider is called once on view being created, after `onAppear`. Is somehow the peer of the UIKit viewDidLoad
	/// - Parameter action: the closure to execute on load
	/// - Returns: the modified view
	func onLoad(_ action: (() -> Void)? = nil) -> some View {
		modifier(ViewDidLoadModifier(perform: action))
	}
	
	/// Applies the given custom transformation
	/// - Parameters:
	///   - block: The transform to apply to the source `View`.
	/// - Returns: The modified `View`.
	func transform<V: View>(@ViewBuilder _ block: (Self) -> V) -> V { block(self) }
	
}

fileprivate struct ViewDidLoadModifier: ViewModifier {
   
	@State private var didLoad = false
	private let action: (() -> Void)?

	init(perform action: (() -> Void)? = nil) { self.action = action }

	func body(content: Content) -> some View {
		content.onAppear {
			if didLoad == false {
				didLoad = true
				action?()
			}
		}
	}
}
