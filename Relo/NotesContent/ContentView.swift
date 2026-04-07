import SwiftUI
import Combine
import CoreData
import UserNotifications

// MARK: - 基础数据模型（后续可迁移到独立文件）

enum Sentiment: String {
    case positive = "积极"
    case neutral = "中性"
    case negative = "消极"
}

struct TodoItem: Identifiable {
    let id: UUID
    var text: String
    var dueDate: Date?                      //待办时间
    var isDone: Bool = false                //是否完成待办
    var reminderScheduled: Bool = false     // 是否设置提醒
    
    // 初始化方法：支持传入 id（用于从 Core Data 加载）
    init(id: UUID = UUID(), text: String, dueDate: Date? = nil, isDone: Bool = false, reminderScheduled: Bool = false) {
        self.id = id
        self.text = text
        self.dueDate = dueDate
        self.isDone = isDone
        self.reminderScheduled = reminderScheduled
    }
}

struct Note: Identifiable {
    var id = UUID()
    var text: String
    var createdAt: Date = Date()
    var keywords: [String] = []
    var summary: String = ""
    var sentiment: Sentiment = .neutral
    var todos: [TodoItem] = []
}

struct ReviewTodoItem: Identifiable {
    let id: UUID
    var isSelected: Bool
    var text: String
    var hasDueDate: Bool
    var dueDate: Date
    
    init(todo: TodoItem) {
        id = todo.id
        isSelected = true
        text = todo.text
        hasDueDate = todo.dueDate != nil
        dueDate = todo.dueDate ?? Date()
    }
    
    func toTodoItem() -> TodoItem? {
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isSelected, !cleanedText.isEmpty else { return nil }
        
        return TodoItem(
            id: id,
            text: cleanedText,
            dueDate: hasDueDate ? dueDate : nil
        )
    }
}

// MARK: - ViewModel（内存 + Core Data 持久化）

@MainActor
class NotesViewModel: ObservableObject {
    private let nlpAnalyzer = NLPAnalyzer()
    private let context: NSManagedObjectContext
    private var noteObjectIDs: [UUID: NSManagedObjectID] = [:]
    
    @Published var currentText: String = ""
    @Published var notes: [Note] = []
    @Published var isLoading: Bool = true
    @Published var pendingTodoReviewNoteID: UUID?
    
    init(context: NSManagedObjectContext) {
        self.context = context
        Task {
            await loadNotes()
        }
    }
    
    func addAndAnalyzeNote() {
        guard !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var note = Note(text: currentText)
        analyze(&note)
        notes.insert(note, at: 0)
        if let objectID = saveToCoreData(note: note) {
            noteObjectIDs[note.id] = objectID
            if !note.todos.isEmpty {
                replaceTodosInCoreData(noteId: note.id, todos: note.todos)
                pendingTodoReviewNoteID = note.id
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
        replaceTodosInCoreData(noteId: noteId, todos: reviewedTodos)
        pendingTodoReviewNoteID = nil
    }
    
    func updateNote(noteId: UUID, newText: String) {
        guard let noteIndex = notes.firstIndex(where: {$0.id == noteId}) else {
            return
        }
        
        guard !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        var updatedNote = Note(text: newText, createdAt: notes[noteIndex].createdAt)
        updatedNote.id = notes[noteIndex].id
        analyze(&updatedNote)
        
        let oldText = notes[noteIndex].text
        let oldCreatedAt = notes[noteIndex].createdAt
        
        notes[noteIndex] = updatedNote
        saveUpdatedNoteToCoreData(noteId: noteId, newText: newText, oldText: oldText, createdAt: oldCreatedAt)
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
        
        // 2. 先保存笔记信息，再删除（用于 Core Data 匹配）
        let noteText = note.text
        let noteCreatedAt = note.createdAt
        
        // 3. 从内存中删除笔记
        notes.remove(at: noteIndex)
        
        // 4. 从 Core Data 中删除笔记（使用保存的信息匹配）
        deleteNoteFromCoreData(noteId: noteId, text: noteText, createdAt: noteCreatedAt)
    }
    
    private func deleteNoteFromCoreData(noteId: UUID, text: String, createdAt: Date) {
        do {
            if let objectID = noteObjectIDs[noteId],
               let obj = try? context.existingObject(with: objectID) as? NSManagedObject {
                deleteTodosFromCoreData(noteId: objectID)
                context.delete(obj)
            } else {
                let request = NSFetchRequest<NSManagedObject>(entityName: "NoteEntity")
                let results = try context.fetch(request)
                for obj in results {
                    if let objText = obj.value(forKey: "text") as? String,
                       let objCreatedAt = obj.value(forKey: "createdAt") as? Date,
                       objText == text,
                       abs(objCreatedAt.timeIntervalSince(createdAt)) < 1.0 {  // 时间差小于 1 秒认为是同一条
                        
                        // 先删除对应的待办
                        deleteTodosFromCoreData(noteId: obj.objectID)
                        
                        // 再删除笔记
                        context.delete(obj)
                        break
                    }
                }
            }
            
            try context.save()
            noteObjectIDs.removeValue(forKey: noteId)
            NSLog("笔记删除成功")
        } catch {
            NSLog("删除笔记失败: \(error)")
        }
    }
    
    private func deleteTodosFromCoreData(noteId: NSManagedObjectID) {
        let noteIdString = noteId.uriRepresentation().absoluteString
        let request = NSFetchRequest<NSManagedObject>(entityName: "TodoEntity")
        request.predicate = NSPredicate(format: "noteId == %@", noteIdString)
        
        do {
            let results = try context.fetch(request)
            for obj in results {
                context.delete(obj)
            }
            try context.save()
        } catch {
            print("删除待办失败: \(error)")
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
        saveTodoToCoreData(todo: notes[noteIndex].todos[todoIndex], noteId: noteId)
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
        saveTodoToCoreData(todo: notes[noteIndex].todos[todoIndex], noteId: noteId)
    }
    
    func createIndependentTodo(text: String, dueDate: Date?) {
        var tempNote = Note(text: "__INDEPENDENT_TODO__")
        tempNote.id = UUID()
        tempNote.createdAt = Date()
        
        let todo = TodoItem(text: text, dueDate: dueDate)
        
        tempNote.todos = [todo]
        
        notes.insert(tempNote, at: 0)
        
        if let objectID = saveToCoreData(note: tempNote) {
            noteObjectIDs[tempNote.id] = objectID
            replaceTodosInCoreData(noteId: tempNote.id, todos: tempNote.todos)
        }
    }
    
    private func replaceTodosInCoreData(noteId: UUID, todos: [TodoItem]) {
        guard let noteObjectID = noteObjectIDs[noteId] else {
            NSLog("未找到 noteId 对应的 Core Data 对象，无法批量更新待办")
            return
        }
        
        deleteTodosFromCoreData(noteId: noteObjectID)
        
        for todo in todos {
            saveTodoToCoreData(todo: todo, noteId: noteId)
        }
    }
    
    private func saveTodoToCoreData(todo: TodoItem, noteId: UUID) {
        guard let noteObjectID = noteObjectIDs[noteId] else {
            NSLog("未找到 noteId 对应的 Core Data 对象，无法保存待办")
            return
        }
        
        let noteIdString = noteObjectID.uriRepresentation().absoluteString
        
        do {
            // 查找或创建待办记录
            let todoRequest = NSFetchRequest<NSManagedObject>(entityName: "TodoEntity")
            todoRequest.predicate = NSPredicate(format: "todoId == %@ AND noteId == %@", todo.id.uuidString, noteIdString)
            
            let todoResults = try context.fetch(todoRequest)
            let todoObj: NSManagedObject
            
            if let existing = todoResults.first {
                todoObj = existing
            } else {
                guard let entity = NSEntityDescription.entity(forEntityName: "TodoEntity", in: context) else {
                    NSLog("找不到 TodoEntity 定义")
                    return
                }
                todoObj = NSManagedObject(entity: entity, insertInto: context)
                todoObj.setValue(todo.id.uuidString, forKey: "todoId")
                todoObj.setValue(noteIdString, forKey: "noteId")
            }
            
            // 更新待办属性
            todoObj.setValue(todo.text, forKey: "text")
            todoObj.setValue(todo.dueDate, forKey: "dueDate")
            todoObj.setValue(todo.isDone, forKey: "isDone")
            todoObj.setValue(todo.reminderScheduled, forKey: "reminderScheduled")
            
            // 保存
            try context.save()
            NSLog("待办更新成功")
        } catch {
            NSLog("保存待办到 Core Data 失败: \(error)")
        }
    }
    
    //MARK: - 提醒功能
    /// 请求通知权限
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            NSLog("请求通知权限失败: \(error)")
            return false
        }
    }
    
    /// 检查通知权限状态
    func checkNotificationPermission() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }
    
    /// 设置提醒
    func scheduleReminder(for todo: TodoItem, note: Note, timeBefore: TimeInterval = 3600) async {
        //1.检查是否有到期时间
        guard let dueDate = todo.dueDate else {
            NSLog("待办没有到期时间，无法设置提醒")
            return
        }
        
        //2.检查权限
        let hasPermission = await checkNotificationPermission()
        if !hasPermission {
            let granted = await requestNotificationPermission()
            if !granted {
                NSLog("用户拒绝了通知权限")
                return
            }
        }
        
        // 3. 计算提醒时间（到期时间 - 提前时间）
        let reminderDate = dueDate.addingTimeInterval(-timeBefore)
        
        // 4. 检查提醒时间是否已过
        if reminderDate <= Date() {
            NSLog("提醒时间已过，无法设置提醒")
            return
        }
        
        // 5. 创建通知内容
        let content = UNMutableNotificationContent()
        content.title = "待办提醒"
        content.body = todo.text
        content.sound = .default
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        content.subtitle = "到期时间: \(formatter.string(from: dueDate))"
        
        // 6. 创建触发时间
        let timeInterval = reminderDate.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        
        // 7. 创建通知请求
        let identifier = todo.id.uuidString
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // 8. 添加到通知中心
        do {
            try await UNUserNotificationCenter.current().add(request)
            
            // 9. 更新待办的提醒状态
            if let noteIndex = notes.firstIndex(where: {$0.id == note.id}),
               let todoIndex = notes[noteIndex].todos.firstIndex(where: {$0.id == todo.id}) {
                notes[noteIndex].todos[todoIndex].reminderScheduled = true
                saveTodoToCoreData(todo: notes[noteIndex].todos[todoIndex], noteId: notes[noteIndex].id)
            }
            NSLog("提醒设置成功，将在 \(formatter.string(from: reminderDate)) 提醒")
        } catch {
            NSLog("设置提醒失败: \(error)")
        }
    }
    
    /// 取消提醒
    func cancelReminder(for todoId: UUID) {
        let identifier = todoId.uuidString
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        
        // 更新待办的提醒状态
        for noteIndex in notes.indices {
            if let todoIndex = notes[noteIndex].todos.firstIndex(where: { $0.id == todoId }) {
                notes[noteIndex].todos[todoIndex].reminderScheduled = false
                saveTodoToCoreData(todo: notes[noteIndex].todos[todoIndex], noteId: notes[noteIndex].id)
                break
            }
        }
        
        NSLog("提醒已取消")
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
        
        if result.keywords.isEmpty {
            note.keywords = extractKeywords(from: note.text)
            note.summary = result.summary.isEmpty ? makeSummary(from: note.text) : result.summary
            note.sentiment = result.sentiment
            note.todos = result.todos.isEmpty ? extractTodos(from: note.text) : result.todos
        } else {
            note.keywords = result.keywords
            note.summary = result.summary
            note.sentiment = result.sentiment
            note.todos = result.todos
        }
    }
    
    private func extractKeywords(from text: String) -> [String] {
        let separators = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        let parts = text.components(separatedBy: separators)
        let words = parts.filter { $0.count >= 2 }
        let unique = Array(Set(words))
        return Array(unique.prefix(5))
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
    
    private func loadNotes() async{
        isLoading = true
        try? await Task.sleep(nanoseconds: 1000_000_000)  // 1 秒
        noteObjectIDs.removeAll()
        
        let request = NSFetchRequest<NSManagedObject>(entityName: "NoteEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            let results = try context.fetch(request)
            var loaded: [Note] = []
            for obj in results {
                guard
                    let text = obj.value(forKey: "text") as? String,
                    let createdAt = obj.value(forKey: "createdAt") as? Date
                else { continue }
                
                var note = Note(text: text, createdAt: createdAt)
                analyze(&note)
                
                // 从 Core Data 加载已保存的待办数据
                loadTodosFromCoreData(for: &note, noteObjectID: obj.objectID)
                
                loaded.append(note)
                noteObjectIDs[note.id] = obj.objectID
            }
            self.notes = loaded
        } catch {
            print("读取历史笔记失败: \(error)")
        }
        isLoading = false
    }
    
    // 从 Core Data 加载待办数据
    private func loadTodosFromCoreData(for note: inout Note, noteObjectID: NSManagedObjectID) {
        let noteIdString = noteObjectID.uriRepresentation().absoluteString
        let request = NSFetchRequest<NSManagedObject>(entityName: "TodoEntity")
        request.predicate = NSPredicate(format: "noteId == %@", noteIdString)
        
        do {
            let results = try context.fetch(request)
            var savedTodos: [TodoItem] = []
            
            for obj in results {
                guard
                    let text = obj.value(forKey: "text") as? String,
                    let todoIdString = obj.value(forKey: "todoId") as? String,
                    let todoId = UUID(uuidString: todoIdString)
                else { continue }
                
                let dueDate = obj.value(forKey: "dueDate") as? Date
                let isDone = obj.value(forKey: "isDone") as? Bool ?? false
                let reminderScheduled = obj.value(forKey: "reminderScheduled") as? Bool ?? false
                
                let todo = TodoItem(id: todoId, text: text, dueDate: dueDate, isDone: isDone, reminderScheduled: reminderScheduled)
                savedTodos.append(todo)
            }
            
            // 合并已保存的待办和 NLP 分析出的待办
            let savedTodoKeys = Set(savedTodos.map(todoMergeKey))
            let newTodos = note.todos.filter { !savedTodoKeys.contains(todoMergeKey($0)) }
            
            // 合并：已保存的待办 + 新分析出的待办
            note.todos = savedTodos + newTodos
        } catch {
            NSLog("加载待办数据失败: \(error)")
        }
    }
    
    private func todoMergeKey(_ todo: TodoItem) -> String {
        let normalizedText = todo.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let dueDateTimestamp = todo.dueDate.map { String(Int($0.timeIntervalSince1970)) } ?? "nil"
        return "\(normalizedText)|\(dueDateTimestamp)"
    }
    
    private func saveUpdatedNoteToCoreData(noteId: UUID, newText: String, oldText: String, createdAt: Date) {
        do {
            if let objectID = noteObjectIDs[noteId],
               let obj = try? context.existingObject(with: objectID) as? NSManagedObject {
                obj.setValue(newText, forKey: "text")
                try context.save()
                return
            }
            
            // 回退策略：如果映射缺失，则按旧文本 + 创建时间匹配
            let request = NSFetchRequest<NSManagedObject>(entityName: "NoteEntity")
            let results = try context.fetch(request)
            for obj in results {
                if let objText = obj.value(forKey: "text") as? String,
                   let objCreatedAt = obj.value(forKey: "createdAt") as? Date,
                   objText == oldText,
                   abs(objCreatedAt.timeIntervalSince(createdAt)) < 1.0 {
                    obj.setValue(newText, forKey: "text")
                    try context.save()
                    return
                }
            }
            
            NSLog("更新笔记失败：未找到对应 Core Data 记录")
        } catch {
            NSLog("更新笔记到 Core Data 失败: \(error)")
        }
    }
    
    @discardableResult
    private func saveToCoreData(note: Note) -> NSManagedObjectID? {
        guard let entity = NSEntityDescription.entity(forEntityName: "NoteEntity", in: context) else {
            print("找不到 NoteEntity 定义，请检查 Core Data 模型名称")
            return nil
        }
        let obj = NSManagedObject(entity: entity, insertInto: context)
        obj.setValue(note.text, forKey: "text")
        obj.setValue(note.createdAt, forKey: "createdAt")
        
        do {
            try context.save()
            return obj.objectID
        } catch {
            print("保存笔记到 Core Data 失败: \(error)")
            return nil
        }
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
    
    var body: some View {
        ZStack {
            // ✅ 新增：渐变背景
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.97, blue: 1.0),
                    Color(red: 0.98, green: 0.99, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // ✅ 优化：标题区域
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.title2)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            Text("快速记一条笔记")
                                .font(.title.weight(.bold))
                                .foregroundStyle(.primary)
                        }
                    
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                            
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
                        .frame(minHeight: 200)
            
                        Button {
                            isTextEditorFocused = false
                            vm.addAndAnalyzeNote()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("保存并智能分析")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
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
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                        )
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
//        .navigationTitle("Relo")
//        .navigationBarTitleDisplayMode(.large)
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
