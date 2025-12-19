//
//  NoteDetailView.swift
//  Relo
//
//  笔记详情页 - 查看和编辑笔记
//

import SwiftUI

struct NoteDetailView: View {
    let note: Note
    @ObservedObject var vm: NotesViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var editedText: String
    @State private var isEditing: Bool = false
    @FocusState private var isTextEditorFocused: Bool
    
    init(note: Note, vm: NotesViewModel) {
        self.note = note
        self.vm = vm
        _editedText = State(initialValue: note.text)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 编辑区域
                VStack(alignment: .leading, spacing: 12) {
                    if isEditing {
                        Text("编辑笔记")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        TextEditor(text: $editedText)
                            .frame(minHeight: 200)
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .focused($isTextEditorFocused)
                        
                        HStack {
                            Button("取消") {
                                editedText = note.text
                                isEditing = false
                                isTextEditorFocused = false
                            }
                            .buttonStyle(.bordered)
                            
                            Spacer()
                            
                            Button("保存") {
                                vm.updateNote(noteId: note.id, newText: editedText)
                                isEditing = false
                                isTextEditorFocused = false
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    } else {
                        // 显示模式
                        Text(note.text)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                )
                
                // 分析结果
                VStack(alignment: .leading, spacing: 16) {
                    Text("智能分析结果")
                        .font(.headline)
                    
                    // 摘要
                    if !note.summary.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("摘要", systemImage: "text.alignleft")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(note.summary)
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                        )
                    }
                    
                    // 关键词
                    if !note.keywords.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("关键词", systemImage: "tag")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            
                            FlowLayout(spacing: 8) {
                                ForEach(note.keywords, id: \.self) { kw in
                                    Text(kw)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            LinearGradient(
                                                colors: [.blue.opacity(0.15), .purple.opacity(0.15)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.blue, .purple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                        )
                    }
                    
                    // 情绪分析
                    VStack(alignment: .leading, spacing: 4) {
                        Label("情绪分析", systemImage: "face.smiling")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            Image(systemName: sentimentIcon(for: note.sentiment))
                                .font(.title2)
                            Text(note.sentiment.rawValue)
                                .font(.title3.weight(.semibold))
                        }
                        .foregroundStyle(sentimentColor(for: note.sentiment))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                    )
                    
                    // 待办列表
                    if !note.todos.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("待办事项 (\(note.todos.count))", systemImage: "checkmark.circle")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            
                            ForEach(note.todos) { todo in
                                TodoDetailRowView(todo: todo, note: note, vm: vm)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                        )
                    }
                    
                    // 创建时间
                    VStack(alignment: .leading, spacing: 4) {
                        Label("创建时间", systemImage: "calendar")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(note.createdAt, style: .date)
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text(note.createdAt, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                    )
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("笔记详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !isEditing {
                    Button {
                        isEditing = true
                        isTextEditorFocused = true
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                }
            }
        }
    }
    
    private func sentimentIcon(for sentiment: Sentiment) -> String {
        switch sentiment {
        case .positive: return "face.smiling.fill"
        case .neutral: return "face.dashed"
        case .negative: return "face.dashed.fill"
        }
    }
    
    private func sentimentColor(for sentiment: Sentiment) -> Color {
        switch sentiment {
        case .positive: return .green
        case .neutral: return .gray
        case .negative: return .red
        }
    }
}

// MARK: - 待办详情行视图

struct TodoDetailRowView: View {
    let todo: TodoItem
    let note: Note
    @ObservedObject var vm: NotesViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    vm.toggleTodo(noteId: note.id, todoId: todo.id)
                } label: {
                    Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(
                            todo.isDone ?
                            LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing) :
                            LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }
                .buttonStyle(.plain)
                
                Text(todo.text)
                    .font(.body)
                    .strikethrough(todo.isDone)
                    .foregroundStyle(todo.isDone ? .secondary : .primary)
                
                Spacer()
            }
            
            if let dueDate = todo.dueDate {
                HStack(spacing: 8) {
                    Label {
                        Text(dueDate, style: .date)
                            .font(.caption)
                    } icon: {
                        Image(systemName: "calendar")
                            .font(.caption2)
                    }
                    
                    Text("•")
                        .font(.caption)
                    
                    Label {
                        Text(dueDate, style: .time)
                            .font(.caption)
                    } icon: {
                        Image(systemName: "clock")
                            .font(.caption2)
                    }
                }
                .foregroundStyle(.secondary)
            }
            
            if !todo.isDone, let dueDate = todo.dueDate {
                HStack {
                    if todo.reminderScheduled {
                        Button {
                            vm.cancelReminder(for: todo.id)
                        } label: {
                            Label("已设置提醒", systemImage: "bell.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    } else {
                        Button {
                            vm.quickScheduleReminder(for: todo, note: note)
                        } label: {
                            Label("设置提醒", systemImage: "bell")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .padding(.leading, 32)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 简单的流式布局（用于关键词显示）

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                      y: bounds.minY + result.frames[index].minY),
                          proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}
