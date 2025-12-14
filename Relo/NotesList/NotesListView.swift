//
//  NotesListView.swift
//  Relo
//
//  Created by reol on 2025/12/4.
//

import SwiftUI

struct NotesListView: View {
    @ObservedObject var vm: NotesViewModel
    @State private var noteToDelete: Note?  //要删除的笔记
    @State private var showDeleteAlert = false  //显示删除确认提示框
    
    var body: some View {
        Group {
            if vm.notes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("还没有任何笔记")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else {
                List {
                    ForEach(vm.notes) { note in
                        VStack(alignment: .leading, spacing: 12) {
                            // Header（标题）
                            Text(note.todos.isEmpty ? "笔记" : "自动识别的待办 (\(note.todos.count))")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(nil)
                            
                            // 笔记内容
                            VStack(alignment: .leading, spacing: 4) {
                                if !note.summary.isEmpty {
                                    Text(note.summary)
                                        .font(.headline)
                                }
                                Text(note.text)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            // 关键词
                            if !note.keywords.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        ForEach(note.keywords, id: \.self) { kw in
                                            Text(kw)
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                            
                            // 底部信息
                            HStack {
                                Label(note.sentiment.rawValue, systemImage: "face.smiling")
                                    .font(.caption)
                                    .foregroundStyle(colorFor(sentiment: note.sentiment))
                                Spacer()
                                Text(note.createdAt, style: .date)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            
                            // 待办列表
                            if !note.todos.isEmpty {
                                Divider()
                                    .padding(.vertical, 4)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(note.todos) { todo in
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(alignment: .top, spacing: 8) {
                                                Button {
                                                    vm.toggleTodo(noteId: note.id, todoId: todo.id)
                                                } label: {
                                                    Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                                                        .foregroundStyle(todo.isDone ? .green : .blue)
                                                        .font(.title3)
                                                }
                                                .buttonStyle(.plain)
                                                
                                                Text(todo.text)
                                                    .font(.caption)
                                                    .strikethrough(todo.isDone)
                                                    .foregroundStyle(todo.isDone ? .secondary : .primary)
                                                
                                                Spacer()
                                            }
                                            
                                            // 显示时间和提醒按钮
                                            HStack(spacing: 8) {
                                                if let dueDate = todo.dueDate {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "clock")
                                                            .font(.caption2)
                                                            .foregroundStyle(.secondary)
                                                        Text(dueDate, style: .date)
                                                            .font(.caption2)
                                                            .foregroundStyle(.secondary)
                                                        Text("•")
                                                            .font(.caption2)
                                                            .foregroundStyle(.secondary)
                                                        Text(dueDate, style: .time)
                                                            .font(.caption2)
                                                            .foregroundStyle(.secondary)
                                                    }
                                                }
                                                
                                                Spacer()
                                                
                                                // 设置提醒按钮
                                                if !todo.isDone, let dueDate = todo.dueDate {
                                                    if todo.reminderScheduled {
                                                        Button {
                                                            vm.cancelReminder(for: todo.id)
                                                        } label: {
                                                            Label("取消提醒", systemImage: "bell.slash.fill")
                                                                .font(.caption2)
                                                                .foregroundStyle(.orange)
                                                        }
                                                    } else {
                                                        Button {
                                                            vm.quickScheduleReminder(for: todo, note: note)
                                                        } label: {
                                                            Label("设置提醒", systemImage: "bell.fill")
                                                                .font(.caption2)
                                                                .foregroundStyle(.blue)
                                                        }
                                                    }
                                                }
                                            }
                                            .padding(.leading, 32)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                noteToDelete = note
                                showDeleteAlert = true
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle("所有笔记")
        .alert("删除笔记", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {
                noteToDelete = nil
            }
            Button("删除", role: .destructive) {
                if let note = noteToDelete {
                    vm.deleteNote(noteId: note.id)
                }
                noteToDelete = nil
            }
        } message: {
            if let note = noteToDelete {
                let todoCount = note.todos.count
                if todoCount > 0 {
                    Text("删除笔记将同时删除对应笔记的 \(todoCount) 个待办，确定删除吗？")
                } else {
                    Text("确定要删除这条笔记吗？")
                }
            }
        }
    }
    
    private func colorFor(sentiment: Sentiment) -> Color {
        switch sentiment {
        case .positive: return .green
        case .neutral: return .gray
        case .negative: return .red
        }
    }
}
