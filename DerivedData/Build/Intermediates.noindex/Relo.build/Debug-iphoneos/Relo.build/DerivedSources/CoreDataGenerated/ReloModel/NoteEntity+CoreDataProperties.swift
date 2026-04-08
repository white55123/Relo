//
//  NoteEntity+CoreDataProperties.swift
//  
//
//  Created by ByteDance on 2026/4/8.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias NoteEntityCoreDataPropertiesSet = NSSet

extension NoteEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<NoteEntity> {
        return NSFetchRequest<NoteEntity>(entityName: "NoteEntity")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var tags: String?
    @NSManaged public var text: String?
    @NSManaged public var todos: TodoEntity?

}

extension NoteEntity : Identifiable {

}
