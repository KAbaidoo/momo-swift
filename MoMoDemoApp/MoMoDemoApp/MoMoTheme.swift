//
//  MoMoTheme.swift
//  MoMoDemoApp
//
//  Created by kobby on 03/10/2026.
//

import SwiftUI

public enum MoMoTheme {
    // Official MTN MoMo Yellow is typically #FFCC00
    public static let yellow = Color(red: 1.0, green: 0.8, blue: 0.0)
    public static let darkBlue = Color(red: 0.0, green: 0.2, blue: 0.4)
    public static let background = Color(UIColor.systemGroupedBackground)
}

struct PrimaryButtonStyle: ButtonStyle {
    var isLoading: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Spacer()
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
            } else {
                configuration.label
                    .font(.headline)
            }
            Spacer()
        }
        .padding()
        .background(configuration.isPressed ? MoMoTheme.yellow.opacity(0.8) : MoMoTheme.yellow)
        .foregroundColor(.black)
        .cornerRadius(12)
        .opacity(isLoading ? 0.7 : 1.0)
    }
}

struct MoMoTextFieldStyle: ViewModifier {
    var iconName: String
    
    func body(content: Content) -> some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(.secondary)
                .frame(width: 24)
            content
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

extension View {
    func momoTextField(icon: String) -> some View {
        self.modifier(MoMoTextFieldStyle(iconName: icon))
    }
}
