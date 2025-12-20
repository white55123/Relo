//
//  LoadingView.swift
//  Relo
//
//  Created by reol on 2025/12/19.
//

import SwiftUI

struct LoadingView : View {
    @State private var rotationAngle: Double = 0
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red:0.95, green: 0.97, blue:1.0),
                    Color(red:0.98, green: 0.99, blue:1.0)
            ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                ZStack {
                    //外圈动画
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 4
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(rotationAngle))
                    
                    //内圈图标
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(scale)
                }
                
                Text("Relo")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("AI 智能日程管理助手")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                ProgressView()
                    .scaleEffect(1.2)
                    .padding(.top, 8)
            }
        }
        .onAppear {
            // 启动旋转动画
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
            
            // 启动缩放动画
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                scale = 1.1
            }
        }
    }
}
