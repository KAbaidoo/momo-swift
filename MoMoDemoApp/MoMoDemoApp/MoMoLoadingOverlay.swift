//
//  MoMoLoadingOverlay.swift
//  MoMoDemoApp
//
//  Created by kobby on 03/10/2026.
//

import SwiftUI

struct MoMoLoadingOverlay: View {
    var message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: MoMoTheme.yellow))
                
                Text(message)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(Color(UIColor.systemBackground).opacity(0.1))
            .background(BlurView(style: .systemThinMaterialDark))
            .cornerRadius(20)
            .shadow(radius: 20)
        }
    }
}

struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}
