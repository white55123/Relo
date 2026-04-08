//
//  NotesListView.swift
//  Relo
//
//  Created by reol on 2025/12/4.
//

import SwiftUI

private enum NoteListScope: String, CaseIterable {
    case all = "全部"
    case onlyTodos = "仅有待办"
}

private enum SentimentFilter: String, CaseIterable {
    case all = "全部情绪"
    case positive = "积极"
    case neutral = "中性"
    case negative = "消极"
    
    var sentiment: Sentiment? {
        switch self {
        case .all: return nil
        case .positive: return .positive
        case .neutral: return .neutral
        case .negative: return .negative
        }
    }
}

struct NotesListView: View {
    @ObservedObject var vm: NotesViewModel
    @State private var noteToDelete: Note?
    @State private var showDeleteAlert = false
    @State private var searchText = ""
    @State private var selectedScope: NoteListScope = .all
    @State private var selectedTag: String?
    @State private var selectedSentiment: SentimentFilter = .all
    
    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // 过滤掉独立待办的笔记
    private var baseNotes: [Note] {
        vm.notes.filter { note in
            note.text != "__INDEPENDENT_TODO__"
        }
    }
    
    private var availableTags: [String] {
        let unique = Set(baseNotes.flatMap { $0.tags })
        return Array(unique).sorted()
    }
    
    private var displayedNotes: [Note] {
        baseNotes.filter { note in
            matchesScope(note) &&
            matchesTag(note) &&
            matchesSentiment(note) &&
            matchesSearch(note)
        }
    }
    
    private var hasActiveFilters: Bool {
        !normalizedSearchText.isEmpty || selectedScope != .all || selectedTag != nil || selectedSentiment != .all
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if baseNotes.isEmpty {
                emptyNotesView
            } else {
                filterSection
                
                if displayedNotes.isEmpty {
                    noMatchView
                } else {
                    notesList
                }
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
    
    private var emptyNotesView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("还没有任何笔记")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    private var noMatchView: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("无匹配结果")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("试试更短搜索词或清空筛选")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var filterSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索正文、摘要、标签、待办", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            Picker("范围", selection: $selectedScope) {
                ForEach(NoteListScope.allCases, id: \.self) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            
            HStack(spacing: 10) {
                Menu {
                    Button("全部标签") { selectedTag = nil }
                    if !availableTags.isEmpty {
                        Divider()
                        ForEach(availableTags, id: \.self) { tag in
                            Button("#\(tag)") { selectedTag = tag }
                        }
                    }
                } label: {
                    Label(
                        selectedTag.map { "标签: \($0)" } ?? "标签: 全部",
                        systemImage: "tag"
                    )
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.12))
                    .foregroundStyle(Color.green)
                    .cornerRadius(10)
                }
                
                Menu {
                    ForEach(SentimentFilter.allCases, id: \.self) { filter in
                        Button(filter.rawValue) { selectedSentiment = filter }
                    }
                } label: {
                    Label(
                        selectedSentiment.rawValue,
                        systemImage: "face.smiling"
                    )
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.12))
                    .foregroundStyle(Color.orange)
                    .cornerRadius(10)
                }
                
                Spacer()
                
                if hasActiveFilters {
                    Button("清空") {
                        searchText = ""
                        selectedScope = .all
                        selectedTag = nil
                        selectedSentiment = .all
                    }
                    .font(.caption.weight(.semibold))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
    }
    
    private var notesList: some View {
        List {
            ForEach(displayedNotes) { note in
                NavigationLink {
                    NoteDetailView(note: note, vm: vm)
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(note.todos.isEmpty ? "笔记" : "自动识别的待办")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            if !note.summary.isEmpty {
                                highlightedText(note.summary, query: normalizedSearchText)
                                    .font(.headline)
                            }
                            highlightedText(note.text, query: normalizedSearchText, baseColor: .secondary)
                                .font(.subheadline)
                                .lineLimit(3)
                        }
                        
                        if !note.tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(note.tags, id: \.self) { tag in
                                        highlightedText("#\(tag)", query: normalizedSearchText)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.green.opacity(0.12))
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
                        
                        if !note.todos.isEmpty {
                            Divider()
                                .padding(.vertical, 4)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(note.todos.prefix(2)) { todo in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(todo.isDone ? .green : .blue)
                                            .font(.caption)
                                        highlightedText(todo.text, query: normalizedSearchText, baseColor: todo.isDone ? .secondary : .primary)
                                            .font(.caption)
                                            .strikethrough(todo.isDone)
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
    
    private func matchesScope(_ note: Note) -> Bool {
        switch selectedScope {
        case .all:
            return true
        case .onlyTodos:
            return !note.todos.isEmpty
        }
    }
    
    private func matchesTag(_ note: Note) -> Bool {
        guard let selectedTag else { return true }
        return note.tags.contains(selectedTag)
    }
    
    private func matchesSentiment(_ note: Note) -> Bool {
        guard let sentiment = selectedSentiment.sentiment else { return true }
        return note.sentiment == sentiment
    }
    
    private func matchesSearch(_ note: Note) -> Bool {
        guard !normalizedSearchText.isEmpty else { return true }
        
        let searchSpace = [note.text, note.summary]
            + note.tags
            + note.todos.map { $0.text }
        
        return searchSpace.contains { $0.localizedCaseInsensitiveContains(normalizedSearchText) }
    }
    
    private func highlightedText(_ text: String, query: String, baseColor: Color = .primary) -> Text {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return Text(text).foregroundStyle(baseColor) }
        
        let nsText = text as NSString
        let pattern = NSRegularExpression.escapedPattern(for: trimmedQuery)
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return Text(text).foregroundStyle(baseColor)
        }
        
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else { return Text(text) }
        
        var result = Text("")
        var currentLocation = 0
        
        for match in matches {
            if match.range.location > currentLocation {
                let prefix = nsText.substring(with: NSRange(location: currentLocation, length: match.range.location - currentLocation))
                result = result + Text(prefix).foregroundStyle(baseColor)
            }
            
            let matchedText = nsText.substring(with: match.range)
            result = result + Text(matchedText).bold().foregroundStyle(.blue)
            currentLocation = match.range.location + match.range.length
        }
        
        if currentLocation < nsText.length {
            let suffix = nsText.substring(from: currentLocation)
            result = result + Text(suffix).foregroundStyle(baseColor)
        }
        
        return result
    }
    
    private func colorFor(sentiment: Sentiment) -> Color {
        switch sentiment {
        case .positive: return .green
        case .neutral: return .gray
        case .negative: return .red
        }
    }
}
