//
//  UIComponents.swift
//  Relo
//

import SwiftUI

struct CardStyle: ViewModifier {
    var cornerRadius: CGFloat = 16
    var shadowRadius: CGFloat = 10
    var shadowY: CGFloat = 4
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: shadowRadius, x: 0, y: shadowY)
            )
    }
}

extension View {
    func cardStyle(cornerRadius: CGFloat = 16, shadowRadius: CGFloat = 10, shadowY: CGFloat = 4) -> some View {
        self.modifier(CardStyle(cornerRadius: cornerRadius, shadowRadius: shadowRadius, shadowY: shadowY))
    }
}

struct ThemeGradient {
    static let primary = LinearGradient(
        colors: [.blue, .purple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let horizontalPrimary = LinearGradient(
        colors: [.blue, .purple],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let background = LinearGradient(
        colors: [
            Color(red: 0.95, green: 0.97, blue: 1.0),
            Color(red: 0.98, green: 0.99, blue: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let success = LinearGradient(
        colors: [.green, .mint],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
