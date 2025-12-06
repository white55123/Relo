import SwiftUI
import Combine
import CoreData

// MARK: - 基础数据模型（后续可迁移到独立文件）

enum Sentiment: String {
    case positive = "积极"
    case neutral = "中性"
    case negative = "消极"
}

struct TodoItem: Identifiable {
    let id = UUID()
    var text: String
    var dueDate: Date?
    var isDone: Bool = false
}

struct Note: Identifiable {
    let id = UUID()
    var text: String
    var createdAt: Date = Date()
    var keywords: [String] = []
    var summary: String = ""
    var sentiment: Sentiment = .neutral
    var todos: [TodoItem] = []
}

// MARK: - ViewModel（内存 + Core Data 持久化）

@MainActor
class NotesViewModel: ObservableObject {
    private let nlpAnalyzer = NLPAnalyzer()
    private let context: NSManagedObjectContext
    
    @Published var currentText: String = ""
    @Published var notes: [Note] = []
    
    init(context: NSManagedObjectContext) {
        self.context = context
        loadNotes()
    }
    
    func addAndAnalyzeNote() {
        guard !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var note = Note(text: currentText)
        analyze(&note)
        notes.insert(note, at: 0)
        saveToCoreData(note: note)
        currentText = ""
    }
    
    //MARK: - 代办操作
    ///切换待办的完成状态
    func toggleTodo(noteId: UUID, todoId: UUID) {
        guard let noteIndex = notes.firstIndex(where: { $0.id == noteId}),
              let todoIndex = notes[noteIndex].todos.firstIndex(where: { $0.id == todoId}) else {
            return
        }
        
        notes[noteIndex].todos[todoIndex].isDone.toggle()
    }
    
    //分析笔记内容
    private func analyze(_ note: inout Note) {
        //使用nlp分析
        let result = nlpAnalyzer.analyze(text: note.text)
        
        if result.keywords.isEmpty {
            note.keywords = extractKeywords(from: note.text)
            note.summary = makeSummary(from: note.text)
            note.sentiment = detectSentiment(from: note.text)
            note.todos = extractTodos(from: note.text)
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
        let patterns = ["明天", "今天", "后天", "周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        let sentences = text.split(whereSeparator: { "\n。.!！?？".contains($0) })
        
        for sentenceSub in sentences {
            let sentence = String(sentenceSub)
            if patterns.contains(where: { sentence.contains($0) }) {
                todos.append(TodoItem(text: sentence, dueDate: nil))
            }
        }
        return todos
    }
    
    // MARK: - Core Data 持久化
    
    private func loadNotes() {
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
                loaded.append(note)
            }
            self.notes = loaded
        } catch {
            print("读取历史笔记失败: \(error)")
        }
    }
    
    private func saveToCoreData(note: Note) {
        guard let entity = NSEntityDescription.entity(forEntityName: "NoteEntity", in: context) else {
            print("找不到 NoteEntity 定义，请检查 Core Data 模型名称")
            return
        }
        let obj = NSManagedObject(entity: entity, insertInto: context)
        obj.setValue(note.text, forKey: "text")
        obj.setValue(note.createdAt, forKey: "createdAt")
        
        do {
            try context.save()
        } catch {
            print("保存笔记到 Core Data 失败: \(error)")
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
                // 设置页
                SettingView()
            }
            .tabItem {
                Label("设置", systemImage: "gearshape")
            }
        }
    }
}

// MARK: - 笔记编辑页

// MARK: - 笔记编辑页

struct NoteEditorPage: View {
    @ObservedObject var vm: NotesViewModel
    @FocusState private var isTextEditorFocused: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("快速记一条笔记")
                        .font(.title2.weight(.semibold))
                    
                    TextEditor(text: $vm.currentText)
                        .frame(minHeight: 180)
                        .padding(10)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(14)
                        .focused($isTextEditorFocused)
                    
                    HStack {
                        Spacer()
                        Button {
                            isTextEditorFocused = false
                            vm.addAndAnalyzeNote()
                        } label: {
                            Label("保存并智能分析", systemImage: "sparkles")
                                .padding(.horizontal, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(vm.currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding()
                
                if let last = vm.notes.first {
                    // 最近一条笔记的摘要预览
                    VStack(alignment: .leading, spacing: 8) {
                        Text("最近的一条笔记")
                            .font(.headline)
                        Text(last.summary.isEmpty ? last.text : last.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        
                        HStack {
                            Label(last.sentiment.rawValue, systemImage: "face.smiling")
                                .font(.caption)
                                .foregroundStyle(colorFor(sentiment: last.sentiment))
                            Spacer()
                            Text(last.createdAt, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(14)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .contentShape(Rectangle())
        .onTapGesture {
            isTextEditorFocused = false
        }
        .navigationTitle("Relo · 智能笔记")
    }
    
    private func colorFor(sentiment: Sentiment) -> Color {
        switch sentiment {
        case .positive: return .green
        case .neutral: return .gray
        case .negative: return .red
        }
    }
}
