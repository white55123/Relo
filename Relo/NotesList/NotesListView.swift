//
//  NotesListView.swift
//  Relo
//
//  Created by reol on 2025/12/4.
//

import SwiftUI

struct NotesListView: View {
    @ObservedObject var vm: NotesViewModel
    
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
                        Section {
                            VStack(alignment: .leading, spacing: 4) {
                                if !note.summary.isEmpty {
                                    Text(note.summary)
                                        .font(.headline)
                                }
                                Text(note.text)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
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
                            
                            HStack {
                                Label(note.sentiment.rawValue, systemImage: "face.smiling")
                                    .font(.caption)
                                    .foregroundStyle(colorFor(sentiment: note.sentiment))
                                Spacer()
                                Text(note.createdAt, style: .date)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } header: {
                            if !note.todos.isEmpty {
                                Text("自动识别的待办 (\(note.todos.count))")
                            } else {
                                Text("笔记")
                            }
                        } footer: {
                            if !note.todos.isEmpty {
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
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("所有笔记")
    }
    
    private func colorFor(sentiment: Sentiment) -> Color {
        switch sentiment {
        case .positive: return .green
        case .neutral: return .gray
        case .negative: return .red
        }
    }
}
