//
//  Persistence.swift
//  Relo
//
//  简单的 Core Data 持久化控制器
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "ReloModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("加载 Core Data 持久化存储失败: \(error)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}


