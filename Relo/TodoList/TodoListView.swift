//
//  TodoListView.swift
//  Relo
//
//  待办列表页面 - 集中显示所有笔记中的待办事项
//

import SwiftUI
import UIKit

enum TimePeriod : String, CaseIterable {
    case today = "今日"
    case thisWeek = "本周"
    case thisMonth = "本月"
}

struct TodoListView: View {
    @ObservedObject var vm: NotesViewModel
    @State private var selectedPeriod : TimePeriod = .today     //选中的时间段
    
    // 从所有笔记中提取所有待办(根据时间段过滤)
    private var allTodos: [(note: Note, todo: TodoItem)] {
        var todos: [(note: Note, todo: TodoItem)] = []
        for note in vm.notes {
            for todo in note.todos {
//                todos.append((note: note, todo: todo))
                if let dueDate = todo.dueDate {
                    if isDateInPeriod(dueDate, period: selectedPeriod) {
                        todos.append((note: note, todo: todo))
                    }
                } else {
                    //TODO reol
                    // 目前没有日期的待办会在本周/本月显示，后续思考一下如何改进
                    if selectedPeriod != .today {
                        todos.append((note: note, todo: todo))
                    }
                }
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
    
    //判断日期是否在指定时间段内
    private func isDateInPeriod(_ date: Date, period: TimePeriod) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        switch period {
        case .today:
            //判断是否是今天
            return calendar.isDateInToday(date)
            
        case .thisWeek:
            //判断是否在本周内
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
            let dateStart = calendar.startOfDay(for: date)
            let weekStart = calendar.startOfDay(for: startOfWeek)
            let weekEnd = calendar.startOfDay(for: endOfWeek)
            return dateStart >= weekStart && dateStart <= weekEnd
            
        case .thisMonth:
            let components = calendar.dateComponents([.year, .month], from: now)
            let startOfMonth = calendar.date(from: components)!
            let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
            let dateStart = calendar.startOfDay(for: date)
            let monthStart = calendar.startOfDay(for: startOfMonth)
            let monthEnd = calendar.startOfDay(for: endOfMonth)
            return dateStart >= monthStart && dateStart <= monthEnd
        }
    }
    
    private var completedTodos: [(note: Note, todo: TodoItem)] {
        allTodos.filter { $0.todo.isDone }
    }
    
    private var pendingTodos: [(note: Note, todo: TodoItem)] {
        allTodos.filter { !$0.todo.isDone }
    }
        
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    Text("我的待办列表")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(DateHelper.formatTodayDate())
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(DateHelper.formatTodayWeekday())
                            .font(.title)
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(.systemBackground))
                
                Divider()
                
                Picker("时间段", selection: $selectedPeriod) {
                    ForEach(TimePeriod.allCases, id: \.self) { period in
                        Text(period.rawValue)
                            .font(.headline)
                            .tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .frame(height: 44)
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.97, blue: 1.0),
                            Color(red: 0.98, green: 0.99, blue: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                
            }
            .background(Color(.systemBackground))
            
            // 内容区域
            Group {
                if allTodos.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.badge.questionmark")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("还没有待办事项")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("在笔记中添加包含时间的任务，\n会自动识别为待办事项")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.97, blue: 1.0),
                                Color(red: 0.98, green: 0.99, blue: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
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
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(DateHelper.formatTodayDate())
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(.secondary)
                                    Text(DateHelper.formatTodayWeekday())
                                        .font(.title)
                                        .foregroundStyle(.primary)
                                }
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
                    )
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                EmptyView()  // 隐藏默认导航栏标题
            }
        }
    }
}

// MARK: - 待办行视图

struct TodoRowView: View {
    let note: Note
    let todo: TodoItem
    @ObservedObject var vm: NotesViewModel
    
    @State private var showDatePicker = false  // 显示时间选择器
    @State private var selectedDate = Date()  // 选中的日期
    
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
                        Button {
                            selectedDate = Date()
                            showDatePicker = true
                        } label: {
                            Label("设置时间", systemImage: "calendar.badge.plus")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
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
                } else if !todo.isDone && todo.dueDate == nil {
                    Text("设置时间后可以设置提醒")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
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
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(
                selectedDate: $selectedDate,
                onConfirm: {
                    vm.updateTodoDueDate(noteId: note.id, todoId: todo.id, dueDate: selectedDate)
                    showDatePicker = false
                },
                onCancel: {
                    showDatePicker = false
                }
            )
        }
    }
}

// MARK: - 时间选择器 Sheet

struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("选择待办时间")
                    .font(.headline)
                    .padding(.top)
                
                DatePicker(
                    "时间",
                    selection: $selectedDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                
                Spacer()
            }
            .padding()
            .navigationTitle("设置时间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确定") {
                        onConfirm()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

