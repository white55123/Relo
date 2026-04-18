//
//  CoreDataManager.swift
//  Relo
//

import CoreData

class CoreDataManager {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Notes
    
    func loadNotes() -> (notes: [Note], mapping: [UUID: NSManagedObjectID]) {
        let request = NSFetchRequest<NSManagedObject>(entityName: "NoteEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        var loaded: [Note] = []
        var mapping: [UUID: NSManagedObjectID] = [:]
        var shouldSaveTagMigration = false
        
        do {
            let results = try context.fetch(request)
            for obj in results {
                guard
                    let text = obj.value(forKey: "text") as? String,
                    let createdAt = obj.value(forKey: "createdAt") as? Date
                else { continue }
                
                let tagsRaw = obj.value(forKey: "tags") as? String
                var note = Note(text: text, createdAt: createdAt, tags: decodeTags(tagsRaw))
                
                // 从 Core Data 加载已保存的待办数据
                let savedTodos = loadTodos(for: obj.objectID)
                note.todos = savedTodos
                
                loaded.append(note)
                mapping[note.id] = obj.objectID
            }
            if shouldSaveTagMigration {
                try? context.save()
            }
        } catch {
            print("读取历史笔记失败: \(error)")
        }
        
        return (loaded, mapping)
    }
    
    func saveNote(_ note: Note) -> NSManagedObjectID? {
        guard let entity = NSEntityDescription.entity(forEntityName: "NoteEntity", in: context) else {
            return nil
        }
        let obj = NSManagedObject(entity: entity, insertInto: context)
        obj.setValue(note.text, forKey: "text")
        obj.setValue(note.createdAt, forKey: "createdAt")
        obj.setValue(encodeTags(note.tags), forKey: "tags")
        
        do {
            try context.save()
            return obj.objectID
        } catch {
            print("保存笔记到 Core Data 失败: \(error)")
            return nil
        }
    }
    
    func updateNote(objectID: NSManagedObjectID, newText: String, newTags: [String]) {
        do {
            if let obj = try? context.existingObject(with: objectID) {
                obj.setValue(newText, forKey: "text")
                obj.setValue(encodeTags(newTags), forKey: "tags")
                try context.save()
            }
        } catch {
            print("更新笔记到 Core Data 失败: \(error)")
        }
    }
    
    func deleteNote(objectID: NSManagedObjectID) {
        do {
            if let obj = try? context.existingObject(with: objectID) {
                deleteTodos(noteId: objectID)
                context.delete(obj)
                try context.save()
            }
        } catch {
            print("删除笔记失败: \(error)")
        }
    }
    
    // MARK: - Todos
    
    func loadTodos(for noteObjectID: NSManagedObjectID) -> [TodoItem] {
        let noteIdString = noteObjectID.uriRepresentation().absoluteString
        let request = NSFetchRequest<NSManagedObject>(entityName: "TodoEntity")
        request.predicate = NSPredicate(format: "noteId == %@", noteIdString)
        
        var savedTodos: [TodoItem] = []
        do {
            let results = try context.fetch(request)
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
        } catch {
            print("加载待办数据失败: \(error)")
        }
        return savedTodos
    }
    
    func replaceTodos(noteObjectID: NSManagedObjectID, todos: [TodoItem]) {
        deleteTodos(noteId: noteObjectID)
        for todo in todos {
            saveTodo(todo, noteObjectID: noteObjectID)
        }
    }
    
    func saveTodo(_ todo: TodoItem, noteObjectID: NSManagedObjectID) {
        let noteIdString = noteObjectID.uriRepresentation().absoluteString
        
        do {
            let request = NSFetchRequest<NSManagedObject>(entityName: "TodoEntity")
            request.predicate = NSPredicate(format: "todoId == %@ AND noteId == %@", todo.id.uuidString, noteIdString)
            
            let results = try context.fetch(request)
            let obj: NSManagedObject
            
            if let existing = results.first {
                obj = existing
            } else {
                guard let entity = NSEntityDescription.entity(forEntityName: "TodoEntity", in: context) else { return }
                obj = NSManagedObject(entity: entity, insertInto: context)
                obj.setValue(todo.id.uuidString, forKey: "todoId")
                obj.setValue(noteIdString, forKey: "noteId")
            }
            
            obj.setValue(todo.text, forKey: "text")
            obj.setValue(todo.dueDate, forKey: "dueDate")
            obj.setValue(todo.isDone, forKey: "isDone")
            obj.setValue(todo.reminderScheduled, forKey: "reminderScheduled")
            
            try context.save()
        } catch {
            print("保存待办到 Core Data 失败: \(error)")
        }
    }
    
    func deleteTodos(noteId: NSManagedObjectID) {
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
    
    // MARK: - Helpers
    
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
    
    private func encodeTags(_ tags: [String]) -> String? {
        let normalized = normalizeTags(tags)
        guard !normalized.isEmpty else { return nil }
        guard let data = try? JSONEncoder().encode(normalized) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    private func decodeTags(_ raw: String?) -> [String] {
        guard let raw, !raw.isEmpty else { return [] }
        if let data = raw.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            return normalizeTags(decoded)
        }
        let fallback = raw.split(separator: ",").map { String($0) }
        return normalizeTags(fallback)
    }
}
