import SwiftUI
import Combine
import CoreData
import UserNotifications

// MARK: - ViewModel（内存 + Core Data 持久化）

@MainActor
class NotesViewModel: ObservableObject {
    private let nlpAnalyzer = NLPAnalyzer()
    private let context: NSManagedObjectContext
    private var noteObjectIDs: [UUID: NSManagedObjectID] = [:]
    private let coreDataManager: CoreDataManager
    private let notificationService = NotificationService.shared
    
    @Published var currentText: String = ""
    @Published var notes: [Note] = []
    @Published var isLoading: Bool = true
    @Published var pendingTodoReviewNoteID: UUID?
    
    init(context: NSManagedObjectContext) {
        self.context = context
        self.coreDataManager = CoreDataManager(context: context)
        Task {
            await loadNotes()
        }
    }
    
    func addAndAnalyzeNote(selectedTags: [String]? = nil) {
        guard !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var note = Note(text: currentText)
        
        let autoTags = generateAutoTags(from: note.text)
        note.tags = normalizeTags(selectedTags ?? autoTags)
        
        // Background thread for NLP
        Task.detached {
            var analyzingNote = note
            // run analysis in background
            let result = self.nlpAnalyzer.analyze(text: analyzingNote.text)
            
            await MainActor.run {
                analyzingNote.summary = result.summary.isEmpty ? self.makeSummary(from: analyzingNote.text) : result.summary
                analyzingNote.sentiment = result.sentiment
                analyzingNote.todos = result.todos.isEmpty ? self.extractTodos(from: analyzingNote.text) : result.todos
                
                self.notes.insert(analyzingNote, at: 0)
                
                if let objectID = self.coreDataManager.saveNote(analyzingNote) {
                    self.noteObjectIDs[analyzingNote.id] = objectID
                    if !analyzingNote.todos.isEmpty {
                        self.coreDataManager.replaceTodos(noteObjectID: objectID, todos: analyzingNote.todos)
                        self.pendingTodoReviewNoteID = analyzingNote.id
                    }
                }
            }
        }
        currentText = ""
    }
    
    var pendingTodoReviewNote: Note? {
        guard let noteId = pendingTodoReviewNoteID else { return nil }
        return notes.first(where: { $0.id == noteId })
    }
    
    func dismissTodoReview() {
        pendingTodoReviewNoteID = nil
    }
    
    func applyTodoReview(_ reviewedTodos: [TodoItem]) {
        guard let noteId = pendingTodoReviewNoteID,
              let noteIndex = notes.firstIndex(where: { $0.id == noteId }) else {
            pendingTodoReviewNoteID = nil
            return
        }
        
        notes[noteIndex].todos = reviewedTodos
        if let objectID = noteObjectIDs[noteId] {
            coreDataManager.replaceTodos(noteObjectID: objectID, todos: reviewedTodos)
        }
        pendingTodoReviewNoteID = nil
    }
    
    func updateNote(noteId: UUID, newText: String, selectedTags: [String]? = nil) {
        guard let noteIndex = notes.firstIndex(where: {$0.id == noteId}) else {
            return
        }
        
        guard !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        var updatedNote = Note(text: newText, createdAt: notes[noteIndex].createdAt)
        updatedNote.id = notes[noteIndex].id
        
        let autoTags = generateAutoTags(from: updatedNote.text)
        updatedNote.tags = normalizeTags(selectedTags ?? autoTags)
        
        Task.detached {
            let result = self.nlpAnalyzer.analyze(text: updatedNote.text)
            await MainActor.run {
                updatedNote.summary = result.summary.isEmpty ? self.makeSummary(from: updatedNote.text) : result.summary
                updatedNote.sentiment = result.sentiment
                updatedNote.todos = result.todos.isEmpty ? self.extractTodos(from: updatedNote.text) : result.todos
                
                self.notes[noteIndex] = updatedNote
                if let objectID = self.noteObjectIDs[noteId] {
                    self.coreDataManager.updateNote(objectID: objectID, newText: newText, newTags: updatedNote.tags)
                }
            }
        }
    }
    
    func deleteNote(noteId: UUID) {
        guard let noteIndex = notes.firstIndex(where: {$0.id == noteId}) else {
            return
        }
        
        let note = notes[noteIndex]
        
        // 1. 取消所有待办的提醒
        for todo in note.todos {
            if todo.reminderScheduled {
                cancelReminder(for: todo.id)
            }
        }
        
        // 2. 从内存中删除笔记
        notes.remove(at: noteIndex)
        
        // 3. 从 Core Data 中删除笔记
        if let objectID = noteObjectIDs[noteId] {
            coreDataManager.deleteNote(objectID: objectID)
            noteObjectIDs.removeValue(forKey: noteId)
        }
    }
    

    
    //MARK: - 代办操作
    ///切换待办的完成状态
    func toggleTodo(noteId: UUID, todoId: UUID) {
        guard let noteIndex = notes.firstIndex(where: { $0.id == noteId}),
              let todoIndex = notes[noteIndex].todos.firstIndex(where: { $0.id == todoId}) else {
            return
        }
        
        notes[noteIndex].todos[todoIndex].isDone.toggle()
        if let objectID = noteObjectIDs[noteId] {
            coreDataManager.saveTodo(notes[noteIndex].todos[todoIndex], noteObjectID: objectID)
        }
    }
    
    ///更新待办的到期时间
    func updateTodoDueDate(noteId: UUID, todoId: UUID, dueDate: Date) {
        guard let noteIndex = notes.firstIndex(where: { $0.id == noteId}),
              let todoIndex = notes[noteIndex].todos.firstIndex(where: { $0.id == todoId}) else {
            NSLog("未找到匹配的笔记来更新待办的到期时间")
            return
        }
        
        // 更新内存中的数据
        notes[noteIndex].todos[todoIndex].dueDate = dueDate
        if let objectID = noteObjectIDs[noteId] {
            coreDataManager.saveTodo(notes[noteIndex].todos[todoIndex], noteObjectID: objectID)
        }
    }
    
    func createIndependentTodo(text: String, dueDate: Date?) {
        var tempNote = Note(text: "__INDEPENDENT_TODO__")
        tempNote.id = UUID()
        tempNote.createdAt = Date()
        
        let todo = TodoItem(text: text, dueDate: dueDate)
        tempNote.todos = [todo]
        notes.insert(tempNote, at: 0)
        
        if let objectID = coreDataManager.saveNote(tempNote) {
            noteObjectIDs[tempNote.id] = objectID
            coreDataManager.replaceTodos(noteObjectID: objectID, todos: tempNote.todos)
        }
    }
    

    
    //MARK: - 提醒功能
    /// 请求通知权限
    func requestNotificationPermission() async -> Bool {
        return await notificationService.requestPermission()
    }
    
    /// 检查通知权限状态
    func checkNotificationPermission() async -> Bool {
        return await notificationService.checkPermission()
    }
    
    /// 设置提醒
    func scheduleReminder(for todo: TodoItem, note: Note, timeBefore: TimeInterval = 3600) async {
        guard let dueDate = todo.dueDate else {
            NSLog("待办没有到期时间，无法设置提醒")
            return
        }
        
        let reminderDate = dueDate.addingTimeInterval(-timeBefore)
        let success = await notificationService.scheduleReminder(id: todo.id, title: "待办提醒", body: todo.text, date: reminderDate)
        
        if success {
            if let noteIndex = notes.firstIndex(where: {$0.id == note.id}),
               let todoIndex = notes[noteIndex].todos.firstIndex(where: {$0.id == todo.id}) {
                notes[noteIndex].todos[todoIndex].reminderScheduled = true
                if let objectID = noteObjectIDs[notes[noteIndex].id] {
                    coreDataManager.saveTodo(notes[noteIndex].todos[todoIndex], noteObjectID: objectID)
                }
            }
        }
    }
    
    /// 取消提醒
    func cancelReminder(for todoId: UUID) {
        notificationService.cancelReminder(for: todoId)
        
        // 更新待办的提醒状态
        for noteIndex in notes.indices {
            if let todoIndex = notes[noteIndex].todos.firstIndex(where: { $0.id == todoId }) {
                notes[noteIndex].todos[todoIndex].reminderScheduled = false
                if let objectID = noteObjectIDs[notes[noteIndex].id] {
                    coreDataManager.saveTodo(notes[noteIndex].todos[todoIndex], noteObjectID: objectID)
                }
                break
            }
        }
    }
    
    /// 快速设置提醒（提前 1 小时）
    func quickScheduleReminder(for todo: TodoItem, note: Note) {
        Task { @MainActor in
            await scheduleReminder(for: todo, note: note, timeBefore: 3600)  // 提前 1 小时
        }
    }
    
    //分析笔记内容
    private func analyze(_ note: inout Note) {
        //使用nlp分析
        let result = nlpAnalyzer.analyze(text: note.text)
        note.summary = result.summary.isEmpty ? makeSummary(from: note.text) : result.summary
        note.sentiment = result.sentiment
        note.todos = result.todos.isEmpty ? extractTodos(from: note.text) : result.todos
    }
    
    private func makeSummary(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let sentences = trimmed.split(whereSeparator: { ".。!！?？".contains($0) })
        if let first = sentences.first {
            let s = String(first)
            return s.count > 40 ? String(s.prefix(40)) + "..." : s
        } else {
            return trimmed.count > 40 ? String(trimmed.prefix(40)) + "..." : trimmed
        }
    }
    
    private func detectSentiment(from text: String) -> Sentiment {
        let lower = text.lowercased()
        let negativeWords = ["累", "压力", "难受", "糟糕", "崩溃", "讨厌"]
        let positiveWords = ["开心", "兴奋", "不错", "满意", "顺利", "期待"]
        
        let negScore = negativeWords.reduce(0) { $0 + (lower.contains($1) ? 1 : 0) }
        let posScore = positiveWords.reduce(0) { $0 + (lower.contains($1) ? 1 : 0) }
        
        if posScore > negScore {
            return .positive
        } else if negScore > posScore {
            return .negative
        } else {
            return .neutral
        }
    }
    
    /// 极简 “NLP”：识别类似 “明天提交报告”、“周五开会” 这样的任务短语
    private func extractTodos(from text: String) -> [TodoItem] {
        var todos: [TodoItem] = []
        let timePatterns = [
            "今天", "明天", "后天", "大后天", "周一", "周二", "周三", "周四", "周五", "周六", "周日",
            "下周", "早上", "早晨", "清晨", "上午", "下午", "傍晚", "晚上", "中午", "凌晨", "今晚", "明早", "明晚",
            "点", "时", "分", "刻"
        ]
        let actionPatterns = [
            "买", "购买", "采购", "提交", "完成", "开会", "讨论", "准备", "检查", "审核", "修改", "发送",
            "回复", "处理", "安排", "计划", "制定", "执行", "实施", "落实", "汇报", "报告", "总结", "分析",
            "研究", "学习", "复习", "练习", "联系", "沟通", "提醒", "取", "拿", "寄", "送", "缴费", "付款",
            "支付", "预约", "看病", "就诊", "取药"
        ]
        let sentences = text.split(whereSeparator: { "\n。.!！?？".contains($0) })
        
        for sentenceSub in sentences {
            let sentence = String(sentenceSub).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sentence.isEmpty else { continue }
            
            let hasTimeWord = timePatterns.contains(where: { sentence.contains($0) })
            let hasActionWord = actionPatterns.contains(where: { sentence.contains($0) })
            
            if hasTimeWord && hasActionWord {
                let dueDate = nlpAnalyzer.inferDueDate(from: sentence)
                todos.append(TodoItem(text: sentence, dueDate: dueDate))
            }
        }
        return todos
    }
    
    // MARK: - Core Data 持久化
    
    private func loadNotes() async {
        isLoading = true
        // 模拟加载动画
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        let data = coreDataManager.loadNotes()
        
        // 批量做 NLP 分析？其实这里最好懒加载或直接存到 CoreData。
        // 但既然我们改不了 CoreData 的 Schema，我们可以在后台并发分析所有的 note。
        let loadedNotes = data.notes
        
        // 我们需要对加载出来的 notes 进行分析以获得 summary, sentiment 等。
        let analyzedNotes = await withTaskGroup(of: Note.self) { group in
            for note in loadedNotes {
                group.addTask {
                    var analyzingNote = note
                    let result = self.nlpAnalyzer.analyze(text: analyzingNote.text)
                    
                    let finalNote = await MainActor.run { () -> Note in
                        analyzingNote.summary = result.summary.isEmpty ? self.makeSummary(from: analyzingNote.text) : result.summary
                        analyzingNote.sentiment = result.sentiment
                        
                        let nlpTodos = result.todos.isEmpty ? self.extractTodos(from: analyzingNote.text) : result.todos
                        let savedTodoKeys = Set(analyzingNote.todos.map(self.todoMergeKey))
                        let newTodos = nlpTodos.filter { !savedTodoKeys.contains(self.todoMergeKey($0)) }
                        analyzingNote.todos.append(contentsOf: newTodos)
                        
                        return analyzingNote
                    }
                    return finalNote
                }
            }
            
            var results: [Note] = []
            for await note in group {
                results.append(note)
            }
            return results
        }
        
        // Sort back to original order (by createdAt descending)
        let sortedNotes = analyzedNotes.sorted { $0.createdAt > $1.createdAt }
        
        self.notes = sortedNotes
        self.noteObjectIDs = data.mapping
        self.isLoading = false
    }
    
    private func todoMergeKey(_ todo: TodoItem) -> String {
        let normalizedText = todo.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let dueDateTimestamp = todo.dueDate.map { String(Int($0.timeIntervalSince1970)) } ?? "nil"
        return "\(normalizedText)|\(dueDateTimestamp)"
    }
    
    private func normalizeTags(_ tags: [String]) -> [String] {
        var seen: Set<String> = []
        var normalized: [String] = []
        
        for tag in tags {
            let cleaned = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !cleaned.isEmpty, !seen.contains(cleaned) else { continue }
            seen.insert(cleaned)
            normalized.append(cleaned)
        }
        
        return normalized
    }
    
    func suggestedTags(for text: String) -> [String] {
        generateAutoTags(from: text)
    }
    
    private func generateAutoTags(from text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        var candidates: [String] = []
        candidates.append(contentsOf: extractTagCandidates(from: trimmed))
        
        // 补充时间/场景标签，让实时输入的标签更符合直觉
        candidates.append(contentsOf: extractContextualTags(from: trimmed))
        return Array(normalizeTags(candidates).prefix(6))
    }
    
    private func extractTagCandidates(from text: String) -> [String] {
        let separators = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        let parts = text.components(separatedBy: separators)
        let words = parts.filter { $0.count >= 2 }
        let unique = Array(Set(words))
        return Array(unique.prefix(8))
    }
    
    private func extractContextualTags(from text: String) -> [String] {
        var tags: [String] = []
        
        let timeWords = [
            "今天", "明天", "后天", "大后天", "今晚", "明早", "明晚",
            "周一", "周二", "周三", "周四", "周五", "周六", "周日", "下周"
        ]
        let periodWords = ["早上", "上午", "中午", "下午", "傍晚", "晚上", "凌晨"]
        let actionWords = [
            "买", "购买", "采购", "开会", "会议", "提交", "汇报", "学习",
            "复习", "锻炼", "运动", "就诊", "看病", "出差", "旅行", "沟通"
        ]
        
        for word in timeWords where text.contains(word) {
            tags.append(word)
        }
        
        for word in periodWords where text.contains(word) {
            tags.append(word)
        }
        
        for word in actionWords where text.contains(word) {
            tags.append(word)
        }
        
        if text.contains("早餐") {
            tags.append("早餐")
        }
        if text.contains("午餐") {
            tags.append("午餐")
        }
        if text.contains("晚餐") {
            tags.append("晚餐")
        }
        
        return tags
    }
}

// MARK: - 根视图：TabView（编辑页 + 列表页）

struct ContentView: View {
    @StateObject private var vm: NotesViewModel
    
    init(context: NSManagedObjectContext) {
        _vm = StateObject(wrappedValue: NotesViewModel(context: context))
    }
    
    var body: some View {
        Group {
            if vm.isLoading {
                LoadingView()
            } else {
                TabView {
                    NavigationStack {
                        NoteEditorPage(vm: vm)
                    }
                    .tabItem {
                        Label("记笔记", systemImage: "square.and.pencil")
                    }
                    
                    NavigationStack {
                        // 笔记列表页
                        NotesListView(vm: vm)
                    }
                    .tabItem {
                        Label("笔记列表", systemImage: "list.bullet")
                    }
                    
                    NavigationStack {
                        // 笔记列表页
                        TodoListView(vm: vm)
                    }
                    .tabItem {
                        Label("待办", systemImage: "checkmark.circle")
                    }
                    
                    NavigationStack {
                        // 设置页
                        SettingView()
                    }
                    .tabItem {
                        Label("设置", systemImage: "gearshape")
                    }
                }
                .tint(.blue)
            }
        }
    }
}

// MARK: - 笔记编辑页

struct NoteEditorPage: View {
    @ObservedObject var vm: NotesViewModel
    @FocusState private var isTextEditorFocused: Bool
    @State private var autoTagsPreview: [String] = []
    @State private var selectedTags: Set<String> = []
    @State private var customTagInput: String = ""
    
    var body: some View {
        ZStack {
            // ✅ 新增：渐变背景
            ThemeGradient.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // ✅ 优化：标题区域
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.title2)
                                .foregroundStyle(ThemeGradient.horizontalPrimary)
                            Text("快速记一条笔记")
                                .font(.title.weight(.bold))
                                .foregroundStyle(.primary)
                        }
                    
                        ZStack(alignment: .topLeading) {
                            if vm.currentText.isEmpty {
                                Text("输入你的任务或想法...")
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                            }
                            
                            TextEditor(text: $vm.currentText)
                                .frame(minHeight: 400)
                                .padding(12)
                                .scrollContentBackground(.hidden)
                                .focused($isTextEditorFocused)
                        }
                        .cardStyle()
                        .frame(minHeight: 200)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("标签（推荐 + 自定义）")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            
                            if !selectedTags.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
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
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
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
                                }
                            } else if selectedTags.isEmpty {
                                Text("输入内容后会实时生成推荐标签")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
            
                        Button {
                            isTextEditorFocused = false
                            vm.addAndAnalyzeNote(selectedTags: finalSelectedTags())
                            autoTagsPreview = []
                            selectedTags.removeAll()
                            customTagInput = ""
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("保存并智能分析")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(ThemeGradient.horizontalPrimary)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(vm.currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    if let last = vm.notes.first {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(.blue)
                                Text("最近的一条笔记")
                                    .font(.headline.weight(.semibold))
                            }
                            
                            Text(last.summary.isEmpty ? last.text : last.summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            
                            if !last.tags.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(last.tags, id: \.self) { tag in
                                            Text("#\(tag)")
                                                .font(.caption2.weight(.medium))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.green.opacity(0.12))
                                                .foregroundStyle(Color.green)
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                            
                            HStack {
                                HStack(spacing: 4) {
                                    Image(systemName: sentimentIcon(for: last.sentiment))
                                        .font(.caption)
                                    Text(last.sentiment.rawValue)
                                        .font(.caption.weight(.medium))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(sentimentColor(for: last.sentiment).opacity(0.15))
                                .foregroundStyle(sentimentColor(for: last.sentiment))
                                .cornerRadius(8)
                                
                                Spacer()
                                
                                Text(last.createdAt, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(16)
                        .cardStyle()
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .sheet(
            isPresented: Binding(
                get: { vm.pendingTodoReviewNote != nil },
                set: { isPresented in
                    if !isPresented {
                        vm.dismissTodoReview()
                    }
                }
            )
        ) {
            if let note = vm.pendingTodoReviewNote {
                TodoReviewSheet(
                    note: note,
                    onConfirm: { reviewedTodos in
                        vm.applyTodoReview(reviewedTodos)
                    },
                    onSkip: {
                        vm.dismissTodoReview()
                    }
                )
            }
        }
        .onAppear {
            refreshAutoTags(for: vm.currentText)
        }
        .onChange(of: vm.currentText) { _, newValue in
            refreshAutoTags(for: newValue)
        }
//        .navigationTitle("Relo")
//        .navigationBarTitleDisplayMode(.large)
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

struct TodoReviewSheet: View {
    let note: Note
    let onConfirm: ([TodoItem]) -> Void
    let onSkip: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var reviewItems: [ReviewTodoItem]
    
    init(note: Note, onConfirm: @escaping ([TodoItem]) -> Void, onSkip: @escaping () -> Void) {
        self.note = note
        self.onConfirm = onConfirm
        self.onSkip = onSkip
        _reviewItems = State(initialValue: note.todos.map(ReviewTodoItem.init))
    }
    
    private var selectedCount: Int {
        reviewItems.compactMap { $0.toTodoItem() }.count
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("识别结果") {
                    Text("识别到 \(note.todos.count) 个待办，请确认保留的内容。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text(note.summary.isEmpty ? note.text : note.summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Section("待确认待办") {
                    ForEach($reviewItems) { $item in
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("保留这条待办", isOn: $item.isSelected)
                                .toggleStyle(.switch)
                            
                            TextField("待办内容", text: $item.text, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .disabled(!item.isSelected)
                            
                            Toggle("设置时间", isOn: $item.hasDueDate)
                                .disabled(!item.isSelected)
                            
                            if item.isSelected && item.hasDueDate {
                                DatePicker(
                                    "待办时间",
                                    selection: $item.dueDate,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .datePickerStyle(.compact)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .navigationTitle("确认待办")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("稍后处理") {
                        onSkip()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成(\(selectedCount))") {
                        let reviewedTodos = reviewItems.compactMap { $0.toTodoItem() }
                        onConfirm(reviewedTodos)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
