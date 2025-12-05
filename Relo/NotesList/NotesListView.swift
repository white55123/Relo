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
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(note.todos) {todo in
                                        HStack(alignment: .top, spacing: 6) {
                                            Image(systemName: "checkmark.circle")
                                                .foregroundStyle(.blue)
                                            Text(todo.text)
                                                .font(.caption)
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
