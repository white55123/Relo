//
//  Models.swift
//  Relo
//

import Foundation

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
    var tags: [String] = []
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
            dueDate: hasDueDate ? dueDate : Date()
        )
    }
}
