//
//  TodoEntity+CoreDataProperties.swift
//  
//
//  Created by ByteDance on 2026/4/8.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias TodoEntityCoreDataPropertiesSet = NSSet

extension TodoEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TodoEntity> {
        return NSFetchRequest<TodoEntity>(entityName: "TodoEntity")
    }

    @NSManaged public var dueDate: Date?
    @NSManaged public var isDone: Bool
    @NSManaged public var noteId: String?
    @NSManaged public var reminderScheduled: Bool
    @NSManaged public var text: String?
    @NSManaged public var todoId: String?
    @NSManaged public var note: NoteEntity?

}

extension TodoEntity : Identifiable {

}
