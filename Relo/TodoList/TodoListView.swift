//
//  TodoListView.swift
//  Relo
//
//  待办列表页面 - 集中显示所有笔记中的待办事项
//

import SwiftUI

struct TodoListView: View {
    @ObservedObject var vm: NotesViewModel
    
    // 从所有笔记中提取所有待办
    private var allTodos: [(note: Note, todo: TodoItem)] {
        var todos: [(note: Note, todo: TodoItem)] = []
        for note in vm.notes {
            for todo in note.todos {
                todos.append((note: note, todo: todo))
            }
        }
        return todos.sorted { todo1, todo2 in
            let date1 = todo1.todo.dueDate ?? Date.distantFuture
            let date2 = todo2.todo.dueDate ?? Date.distantFuture
            if date1 == Date.distantFuture && date2 == Date.distantFuture {
                return false
            }
            if date1 == Date.distantFuture {
                return false
            }
            if date2 == Date.distantFuture {
                return true
            }
            return date1 < date2
        }
    }
    
    private var completedTodos: [(note: Note, todo: TodoItem)] {
        allTodos.filter { $0.todo.isDone }
    }
    
    private var pendingTodos: [(note: Note, todo: TodoItem)] {
        allTodos.filter { !$0.todo.isDone }
    }
    
    var body: some View {
        Group {
            if allTodos.isEmpty {
                // ✅ 优化：空状态
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "checkmark.circle.badge.questionmark")
                            .font(.system(size: 40))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    
                    Text("还没有待办事项")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Text("在笔记中添加包含时间的任务，\n会自动识别为待办事项")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if !pendingTodos.isEmpty {
                        Section {
                            ForEach(pendingTodos, id: \.todo.id) { item in
                                TodoRowView(note: item.note, todo: item.todo, vm: vm)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                    .listRowBackground(Color.clear)
                            }
                        } header: {
                            Text("待完成 (\(pendingTodos.count))")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                    
                    if !completedTodos.isEmpty {
                        Section {
                            ForEach(completedTodos, id: \.todo.id) { item in
                                TodoRowView(note: item.note, todo: item.todo, vm: vm)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                    .listRowBackground(Color.clear)
                            }
                        } header: {
                            Text("已完成 (\(completedTodos.count))")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.97, blue: 1.0),
                            Color(red: 0.98, green: 0.99, blue: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                )
            }
        }
        .navigationTitle("待办列表")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - 待办行视图

struct TodoRowView: View {
    let note: Note
    let todo: TodoItem
    @ObservedObject var vm: NotesViewModel
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                vm.toggleTodo(noteId: note.id, todoId: todo.id)
            } label: {
                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(
                        todo.isDone ?
                        LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing) :
                        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(todo.text)
                    .font(.body.weight(.medium))
                    .strikethrough(todo.isDone)
                    .foregroundStyle(todo.isDone ? .secondary : .primary)
                
                HStack(spacing: 8) {
                    if let dueDate = todo.dueDate {
                        Label {
                            Text(dueDate, style: .date)
                                .font(.caption)
                        } icon: {
                            Image(systemName: "calendar")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                        
                        Text("•")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        
                        Label {
                            Text(dueDate, style: .time)
                                .font(.caption)
                        } icon: {
                            Image(systemName: "clock")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    } else {
                        Label("无具体时间", systemImage: "clock.badge.questionmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "note.text")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(note.summary.isEmpty ? "笔记" : note.summary)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                
                if !todo.isDone, let dueDate = todo.dueDate {
                    HStack {
                        if todo.reminderScheduled {
                            Button {
                                vm.cancelReminder(for: todo.id)
                            } label: {
                                Label("已设置提醒", systemImage: "bell.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        } else {
                            Button {
                                vm.quickScheduleReminder(for: todo, note: note)
                            } label: {
                                Label("设置提醒（提前1小时）", systemImage: "bell")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
    }
}
