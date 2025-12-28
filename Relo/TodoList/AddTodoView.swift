//
//  AddTodoView.swift
//  Relo
//
//  添加待办视图
//

import SwiftUI

struct AddTodoView: View {
    @ObservedObject var vm: NotesViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var todoText: String = ""
    @State private var selectedDate: Date = Date()
    @State private var hasDate: Bool = false
    @FocusState private var isTextFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 待办文本输入
                VStack(alignment: .leading, spacing: 12) {
                    Text("待办内容")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    TextEditor(text: $todoText)
                        .frame(minHeight: 120)
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .focused($isTextFocused)
                }
                
                // 时间设置
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("设置时间", isOn: $hasDate)
                        .font(.headline)
                    
                    if hasDate {
                        DatePicker(
                            "选择时间",
                            selection: $selectedDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.compact)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                Spacer()
                
                // 保存按钮
                Button {
                    guard !todoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        return
                    }
                    
                    vm.createIndependentTodo(
                        text: todoText.trimmingCharacters(in: .whitespacesAndNewlines),
                        dueDate: hasDate ? selectedDate : nil
                    )
                    
                    dismiss()
                } label: {
                    Text("添加待办")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .disabled(todoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .navigationTitle("添加待办")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isTextFocused = true
            }
        }
    }
}
