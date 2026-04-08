//
//  SettingView.swift
//  Relo
//
//  Created by reol on 2025/12/5.
//

import SwiftUI

struct SettingView : View {
    @Environment(\.dismiss) private var dismiss
    @State private var showClearDataAlert = false
    @State private var showAbout = false
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: 隐私问题
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(.blue)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("本地隐私数据保护(开发中)")
                                .font(.headline)
                            Text("待补充")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("隐私与安全")
                }
                
                // MARK: 数据管理
                Section {
                    Button(role: .destructive) {
                        showClearDataAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("清空所有笔记")
                        }
                    }
                } header: {
                    Text("数据管理")
                } footer: {
                    Text("此操作将删除所有本地存储的笔记数据，且无法恢复")
                }
                
                // MARK: 智能分析设置
                Section {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.orange)
                        //TODO 目前按钮固定开启
                        Toggle("自动分析情绪", isOn: .constant(true))
                    }
                    
                    HStack {
                        Image(systemName: "list.bullet.rectangle")
                            .foregroundStyle(.green)
                        Toggle("自动提取待办", isOn: .constant(true))
                            .disabled(true)
                    }
                } header: {
                    Text("智能分析")
                } footer: {
                    Text("基于 Natural Language 框架进行本地分析")
                }
                
                // MARK: - 关于
                Section {
                    Button {
                        showAbout = true
                    } label: {
                        HStack {
                            Image(systemName: "info.circle")
                            Text("关于 Relo")
                        }
                    }
                    
                    HStack {
                        Image(systemName: "doc.text")
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("关于")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .alert("确认清空数据", isPresented: $showClearDataAlert) {
                Button("取消", role: .cancel) { }
                Button("清空", role: .destructive) {
                    // TODO: 实现清空 Core Data 的逻辑
                    // 这里你可以自己实现清空功能
                }
            } message: {
                Text("此操作将永久删除所有笔记，且无法恢复。确定要继续吗？")
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
        }
    }
}

// MARK: - 关于页面

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("Relo")
                            .font(.largeTitle.weight(.bold))
                        
                        Text("AI 智能日程管理助手")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)

                    Divider()
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("核心功能")
                            .font(.headline)
                        
                        FeatureRow(
                            icon: "text.magnifyingglass",
                            title: "智能文本分析",
                            description: "基于 Core ML + Natural Language 框架，自动生成摘要并识别标签"
                        )
                        
                        FeatureRow(
                            icon: "checkmark.circle.badge.questionmark",
                            title: "自动待办识别",
                            description: "通过 NLP 识别笔记中的任务描述，自动创建待办事项"
                        )
                        
                        FeatureRow(
                            icon: "face.smiling",
                            title: "情感倾向识别",
                            description: "分析笔记文本的情绪倾向，提供个性化反馈"
                        )
                        
                        FeatureRow(
                            icon: "lock.shield",
                            title: "本地化隐私保护",
                            description: "所有 AI 处理均在设备端完成，数据安全可靠"
                        )
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("技术栈")
                            .font(.headline)
                        
                        Text("• SwiftUI")
                        Text("• Core Data")
                        Text("• Natural Language")
                        Text("• Core ML")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("关于")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 功能特点行组件（独立结构体）

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
