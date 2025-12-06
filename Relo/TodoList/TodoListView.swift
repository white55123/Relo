//
//  TodoListView.swift
//  Relo
//
//  Created by reol on 2025/12/5.
//

//import SwiftUI
//
//struct TodoListView : View {
//    var body: some View {
//        @ObservedObject var vm: NotesViewModel
//        
//        private var allTodos: [(note: Note, todo: TodoItem)] {
//            var todos: [(note: Note, todo: TodoItem)] = []
//            for note in vm.notes {
//                for todo in note.todos {
//                    todos.append((note: note, todo: todo))
//                }
//            }
//            
//            //按日期排序
//            return todos.sorted {todo1, todo2 in
//                let date1 = todo1.todo.dueDate ?? Date.distantFuture
//                let date2 = todo2.todo.dueDate ?? Date.distantFuture
//                if date1 == Date.distantFuture && date2 == Date.distantFuture {
//                    
//                }
//            }
//        }
//    }
//}
