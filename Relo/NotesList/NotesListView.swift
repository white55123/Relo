//
//  NotesListView.swift
//  Relo
//
//  Created by reol on 2025/12/4.
//

import SwiftUI

struct NotesListView: View {
    @ObservedObject var vm: NotesViewModel
    @State private var noteToDelete: Note?
    @State private var showDeleteAlert = false
    
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
                        NavigationLink {
                            NoteDetailView(note: note, vm: vm)
                        } label: {
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
                                        .lineLimit(3)
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
                                
                                // 待办列表（预览）
                                if !note.todos.isEmpty {
                                    Divider()
                                        .padding(.vertical, 4)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        ForEach(note.todos.prefix(2)) { todo in
                                            HStack(alignment: .top, spacing: 8) {
                                                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(todo.isDone ? .green : .blue)
                                                    .font(.caption)
                                                Text(todo.text)
                                                    .font(.caption)
                                                    .strikethrough(todo.isDone)
                                                    .foregroundStyle(todo.isDone ? .secondary : .primary)
                                                    .lineLimit(1)
                                                Spacer()
                                            }
                                        }
                                        
                                        if note.todos.count > 2 {
                                            Text("还有 \(note.todos.count - 2) 个待办...")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
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
                        }
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
