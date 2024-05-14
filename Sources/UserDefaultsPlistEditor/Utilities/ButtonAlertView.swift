//
//  ButtonAlertView.swift
//  UserDefaultsPlistEditor
//
//  Created by Luca Iaconis on 13.04.2024.
//

import SwiftUI

/// Convenience button containing a simple SwiftUI button, which shows an alert popup associated to the
/// given `item`. It handles internally the alert presentation state
struct ButtonAlertView<T, V1:View, V2:View, V3:View>: View {
	
	// MARK: Properties
	
	@State private var isShowingAlert:Bool = false
	private let item: T
	private let alertTitle: LocalizedStringKey
	private let buttonLabel: (T) -> V1
	private let alertMessage: (T) -> V2
	private let alertActions: (T) -> V3
	
	// MARK: Init
	
	init(item:T, alertTitle:LocalizedStringKey = "Choose an action for this entry", @ViewBuilder buttonLabel: @escaping (T) -> V1, @ViewBuilder alertMessage: @escaping (T) -> V2, @ViewBuilder alertActions: @escaping (T) -> V3 ) {
		self.item = item
		self.alertTitle = alertTitle
		self.buttonLabel = buttonLabel
		self.alertMessage = alertMessage
		self.alertActions = alertActions
	}
	
	// MARK: Body view
	
	var body: some View {
		Button(action: {
			isShowingAlert = true
		}, label: {
			buttonLabel(item)
		})
		.alert(alertTitle, isPresented: $isShowingAlert, actions: {
			alertActions(item)
		}, message: {
			alertMessage(item)
		})
	}
}
