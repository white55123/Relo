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
    
    @State private var editedText: String
    @State private var savedText: String
    @State private var savedTags: [String]
    @State private var autoTagsPreview: [String]
    @State private var selectedTags: Set<String>
    @State private var customTagInput: String = ""
    @State private var isEditing: Bool = false
    @FocusState private var isTextEditorFocused: Bool
    
    init(note: Note, vm: NotesViewModel) {
        self.note = note
        self.vm = vm
        _editedText = State(initialValue: note.text)
        _savedText = State(initialValue: note.text)
        _savedTags = State(initialValue: note.tags)
        _autoTagsPreview = State(initialValue: note.tags)
        _selectedTags = State(initialValue: Set(note.tags))
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
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("标签（推荐 + 自定义）")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            
                            if !selectedTags.isEmpty {
                                FlowLayout(spacing: 8) {
                                    ForEach(finalSelectedTags(), id: \.self) { tag in
                                        Button {
                                            removeSelectedTag(tag)
                                        } label: {
                                            HStack(spacing: 4) {
                                                Text("#\(tag)")
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.caption2)
                                            }
                                            .font(.caption.weight(.medium))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.green.opacity(0.12))
                                            .foregroundStyle(Color.green)
                                            .cornerRadius(10)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            
                            HStack(spacing: 8) {
                                TextField("添加自定义标签，回车确认", text: $customTagInput)
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)
                                    .onSubmit {
                                        addCustomTag()
                                    }
                                
                                Button("添加") {
                                    addCustomTag()
                                }
                                .font(.caption.weight(.semibold))
                                .buttonStyle(.bordered)
                                .disabled(normalizeTag(customTagInput).isEmpty)
                            }
                            
                            if !autoTagsPreview.isEmpty {
                                Text("智能推荐（点击选择/取消）")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                FlowLayout(spacing: 8) {
                                    ForEach(autoTagsPreview, id: \.self) { tag in
                                        let normalized = normalizeTag(tag)
                                        let isSelected = selectedTags.contains(normalized)
                                        
                                        Button {
                                            toggleSuggestedTag(tag)
                                        } label: {
                                            Text("#\(tag)")
                                                .font(.caption.weight(.medium))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(isSelected ? Color.blue.opacity(0.18) : Color.gray.opacity(0.12))
                                                .foregroundStyle(isSelected ? Color.blue : Color.secondary)
                                                .cornerRadius(10)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            } else if selectedTags.isEmpty {
                                Text("修改内容后会实时生成推荐标签")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        HStack {
                            Button("取消") {
                                editedText = savedText
                                selectedTags = Set(savedTags)
                                customTagInput = ""
                                refreshAutoTags(for: savedText)
                                isEditing = false
                                isTextEditorFocused = false
                            }
                            .buttonStyle(.bordered)
                            
                            Spacer()
                            
                            Button("保存") {
                                let finalTags = finalSelectedTags()
                                savedText = editedText
                                savedTags = finalTags
                                vm.updateNote(noteId: note.id, newText: editedText, selectedTags: finalTags)
                                isEditing = false
                                isTextEditorFocused = false
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    } else {
                        // 显示模式
                        Text(savedText)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                        
                        if !savedTags.isEmpty {
                            FlowLayout(spacing: 8) {
                                ForEach(savedTags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.green.opacity(0.12))
                                        .foregroundStyle(Color.green)
                                        .cornerRadius(10)
                                }
                            }
                        }
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
                        selectedTags = Set(savedTags)
                        customTagInput = ""
                        refreshAutoTags(for: editedText)
                        isTextEditorFocused = true
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                }
            }
        }
        .onAppear {
            selectedTags = Set(savedTags)
            refreshAutoTags(for: editedText)
        }
        .onChange(of: editedText) { _, newValue in
            guard isEditing else { return }
            refreshAutoTags(for: newValue)
        }
    }
    
    private func normalizeTag(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let withoutPrefix = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        return withoutPrefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    private func refreshAutoTags(for text: String) {
        autoTagsPreview = vm.suggestedTags(for: text)
        selectedTags = Set(selectedTags.map { normalizeTag($0) }.filter { !$0.isEmpty })
    }
    
    private func toggleSuggestedTag(_ tag: String) {
        let normalized = normalizeTag(tag)
        guard !normalized.isEmpty else { return }
        if selectedTags.contains(normalized) {
            selectedTags.remove(normalized)
        } else {
            selectedTags.insert(normalized)
        }
    }
    
    private func removeSelectedTag(_ tag: String) {
        let normalized = normalizeTag(tag)
        guard !normalized.isEmpty else { return }
        selectedTags.remove(normalized)
    }
    
    private func addCustomTag() {
        let normalized = normalizeTag(customTagInput)
        guard !normalized.isEmpty else { return }
        selectedTags.insert(normalized)
        customTagInput = ""
    }
    
    private func finalSelectedTags() -> [String] {
        var ordered: [String] = []
        
        for tag in autoTagsPreview {
            let normalized = normalizeTag(tag)
            guard !normalized.isEmpty else { continue }
            if selectedTags.contains(normalized), !ordered.contains(normalized) {
                ordered.append(normalized)
            }
        }
        
        for tag in savedTags {
            let normalized = normalizeTag(tag)
            guard !normalized.isEmpty else { continue }
            if selectedTags.contains(normalized), !ordered.contains(normalized) {
                ordered.append(normalized)
            }
        }
        
        for tag in selectedTags.sorted() where !ordered.contains(tag) {
            ordered.append(tag)
        }
        
        return ordered
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

// MARK: - 简单的流式布局（用于标签显示）

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
