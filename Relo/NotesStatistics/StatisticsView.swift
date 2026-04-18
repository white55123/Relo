//
//  StatisticsView.swift
//  Relo
//

import SwiftUI
import Charts

struct SentimentData: Identifiable {
    let id = UUID()
    let sentiment: Sentiment
    let count: Int
}

struct ActivityData: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
}

struct TodoStatsData: Identifiable {
    let id = UUID()
    let status: String
    let count: Int
}

struct StatisticsView: View {
    @ObservedObject var vm: NotesViewModel
    
    var body: some View {
        ZStack {
            ThemeGradient.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    if vm.notes.isEmpty {
                        emptyStateView
                    } else {
                        // 1. 待办完成率
                        todoCompletionCard
                        
                        // 2. 近7天活跃度
                        activityChartCard
                        
                        // 3. 情绪分布
                        sentimentChartCard
                    }
                }
                .padding()
            }
            .navigationTitle("数据统计")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - 空白状态
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)
            Text("暂无数据")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("记录几条笔记后再来看看吧～")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 100)
    }
    
    // MARK: - 待办统计卡片
    private var todoCompletionCard: some View {
        let allTodos = vm.notes.flatMap { $0.todos }
        let doneCount = allTodos.filter { $0.isDone }.count
        let pendingCount = allTodos.count - doneCount
        let progress = allTodos.isEmpty ? 0.0 : Double(doneCount) / Double(allTodos.count)
        
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("待办完成情况")
                    .font(.headline)
            }
            
            if allTodos.isEmpty {
                Text("暂无待办事项")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("总计: \(allTodos.count)")
                            .font(.subheadline)
                        Text("已完成: \(doneCount)")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                        Text("未完成: \(pendingCount)")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                    
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(ThemeGradient.success, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(Int(progress * 100))%")
                            .font(.headline.weight(.bold))
                    }
                    .frame(width: 80, height: 80)
                }
            }
        }
        .padding()
        .cardStyle()
    }
    
    // MARK: - 近7天活跃度卡片
    private var activityChartCard: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // 生成近7天的日期数组
        var last7Days: [Date] = []
        for i in (0..<7).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                last7Days.append(date)
            }
        }
        
        // 统计每天的笔记数量
        let grouped = Dictionary(grouping: vm.notes) { note -> Date in
            calendar.startOfDay(for: note.createdAt)
        }
        
        let data: [ActivityData] = last7Days.map { date in
            ActivityData(date: date, count: grouped[date]?.count ?? 0)
        }
        
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.blue)
                Text("近 7 天笔记记录")
                    .font(.headline)
            }
            
            Chart(data) { item in
                BarMark(
                    x: .value("日期", item.date, unit: .day),
                    y: .value("数量", item.count)
                )
                .foregroundStyle(ThemeGradient.primary)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .frame(height: 180)
        }
        .padding()
        .cardStyle()
    }
    
    // MARK: - 情绪分布卡片
    private var sentimentChartCard: some View {
        let grouped = Dictionary(grouping: vm.notes, by: { $0.sentiment })
        let data: [SentimentData] = [
            SentimentData(sentiment: .positive, count: grouped[.positive]?.count ?? 0),
            SentimentData(sentiment: .neutral, count: grouped[.neutral]?.count ?? 0),
            SentimentData(sentiment: .negative, count: grouped[.negative]?.count ?? 0)
        ].filter { $0.count > 0 }
        
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "face.smiling.fill")
                    .foregroundStyle(.orange)
                Text("近期情绪分布")
                    .font(.headline)
            }
            
            if data.isEmpty {
                Text("暂无情绪数据")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                if #available(iOS 17.0, *) {
                    Chart(data) { item in
                        SectorMark(
                            angle: .value("数量", item.count),
                            innerRadius: .ratio(0.5),
                            angularInset: 1.5
                        )
                        .cornerRadius(4)
                        .foregroundStyle(colorForSentiment(item.sentiment))
                        .annotation(position: .overlay) {
                            Text("\(item.count)")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(height: 200)
                    .chartLegend(position: .bottom, alignment: .center)
                } else {
                    // 兼容 iOS 16：使用横向柱状图代替饼图
                    Chart(data) { item in
                        BarMark(
                            x: .value("数量", item.count),
                            y: .value("情绪", item.sentiment.rawValue)
                        )
                        .foregroundStyle(colorForSentiment(item.sentiment))
                    }
                    .frame(height: 120)
                }
                
                // 图例说明 (iOS 16 compatibility or general legend)
                if #available(iOS 17.0, *) {} else {
                    HStack(spacing: 16) {
                        legendItem(color: .green, text: "积极")
                        legendItem(color: .gray, text: "中性")
                        legendItem(color: .red, text: "消极")
                    }
                    .font(.caption)
                    .padding(.top, 8)
                }
            }
        }
        .padding()
        .cardStyle()
    }
    
    private func colorForSentiment(_ sentiment: Sentiment) -> Color {
        switch sentiment {
        case .positive: return .green
        case .neutral: return .gray
        case .negative: return .red
        }
    }
    
    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
        }
    }
}
