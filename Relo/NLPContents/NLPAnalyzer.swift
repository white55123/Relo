//
//  NLPAnalyzer.swift
//  Relo
//
//  AI 智能分析器 - 基于 Natural Language 框架
//

import Foundation
import NaturalLanguage

// MARK: - 分析结果结构体

struct AnalysisResult {
    var keywords: [String]
    var summary: String
    var sentiment: Sentiment
    var todos: [TodoItem]
}

// MARK: - NLP 分析器主类

class NLPAnalyzer {
    
    private static let stopWords: Set<String> = [
        "的", "了", "在", "是", "我", "有", "和", "就", "不", "人", "都", "一", "一个",
        "上", "也", "很", "到", "说", "要", "去", "你", "会", "着", "没有", "看", "好",
        "自己", "这", "那", "给", "还", "能", "可以"
    ]
    
    private static let positiveWords: Set<String> = [
        "开心", "高兴", "快乐", "兴奋", "满意", "顺利", "期待", "不错", "很好", "优秀",
        "成功", "完成", "达成", "进步", "改善", "提升", "美好", "愉快", "轻松", "舒适",
        "喜欢", "爱", "赞", "棒", "好", "棒极了", "太好了", "完美", "精彩", "出色"
    ]
    
    private static let negativeWords: Set<String> = [
        "累", "疲惫", "疲劳", "压力", "紧张", "焦虑", "担心", "难受", "痛苦", "糟糕",
        "崩溃", "讨厌", "烦", "失望", "沮丧", "难过", "伤心", "困难", "麻烦",
        "失败", "错误", "问题", "不好", "差", "糟糕透顶", "绝望", "无助", "迷茫"
    ]
    
    private static let negationWords: Set<String> = ["不", "没", "没有", "非", "无", "别", "不要", "不会", "不能"]
    
    private static let intensityWords: [String: Double] = [
        "非常": 2.0, "很": 1.5, "特别": 2.0, "极其": 2.5, "超级": 2.0,
        "有点": 0.5, "稍微": 0.5, "略微": 0.5, "比较": 0.8
    ]
    
    private static let timePatterns: [String] = [
        "今天", "明天", "后天", "大后天",
        "周一", "周二", "周三", "周四", "周五", "周六", "周日",
        "下周一", "下周二", "下周三", "下周四", "下周五", "下周六", "下周日",
        "下周", "下个月", "下个星期",
        "早上", "早晨", "清晨", "上午", "下午", "傍晚", "晚上", "中午", "凌晨",
        "今晚", "明早", "明晚",
        "点", "时", "分", "刻"
    ]
    
    private static let actionWords: Set<String> = [
        "提交", "完成", "开会", "讨论", "准备", "检查", "审核", "修改", "发送",
        "回复", "处理", "安排", "计划", "制定", "执行", "实施", "落实",
        "汇报", "报告", "总结", "分析", "研究", "学习", "复习", "练习",
        "买", "购买", "采购", "联系", "沟通", "提醒", "取", "拿", "寄", "送",
        "缴费", "付款", "支付", "预约", "看病", "就诊", "取药",
        "去", "做", "写", "看", "听", "打", "交", "约", "见", "找"
    ]
    
    private static let colonRegex = try! NSRegularExpression(pattern: #"([01]?\d|2[0-3])[:：]([0-5]\d)"#)
    private static let hmRegex = try! NSRegularExpression(pattern: #"(\d{1,2})\s*[点时](\d{1,2})?\s*分?"#)
    private static let dateRegex = try! NSRegularExpression(pattern: #"(\d{1,2})月(\d{1,2})日?"#)
    private static let dayRegex = try! NSRegularExpression(pattern: #"下(周|个?星期)([一二三四五六日天1-7])"#)
    
    // MARK: - 主入口：分析文本
    
    func analyze(text: String) -> AnalysisResult {
        // 1. 识别语言
        let language = detectLanguage(from: text)
        
        // 2. 提取关键词
        let keywords = extractKeywords(from: text, language: language)
        
        // 3. 生成摘要
        let summary = generateSummary(from: text, language: language)
        
        // 4. 分析情绪
        let sentiment = detectSentiment(from: text, language: language)
        
        // 5. 识别任务
        let todos = extractTodos(from: text, language: language)
        
        return AnalysisResult(
            keywords: keywords,
            summary: summary,
            sentiment: sentiment,
            todos: todos
        )
    }
    
    // 对外提供简单的时间推断，供 fallback 逻辑复用
    func inferDueDate(from text: String) -> Date? {
        parseDate(from: text)
    }
    
    // MARK: - 语言识别
    
    private func detectLanguage(from text: String) -> NLLanguage {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        
        if let dominantLanguage = recognizer.dominantLanguage {
            return dominantLanguage
        }
        
        // 默认返回中文
        return .simplifiedChinese
    }
    
    // MARK: - 关键词提取
    
    private func extractKeywords(from text: String, language: NLLanguage) -> [String] {
        guard !text.isEmpty else { return [] }
        
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = text
        tagger.setLanguage(language, range: text.startIndex..<text.endIndex)
        
        var keywords: [String] = []
        var keywordScores: [String: Int] = [:]
        
        // 停用词列表（无意义的词）
        let stopWords = Self.stopWords
        
        // 遍历所有 token，提取名词、动词、形容词
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass
        ) { tag, tokenRange in
            guard let tag = tag else { return true }
            
            let word = String(text[tokenRange]).trimmingCharacters(in: .whitespaces)
            
            // 过滤条件：
            // 1. 长度 >= 2
            // 2. 不是停用词
            // 3. 是名词、动词、形容词
            if word.count >= 2,
               !stopWords.contains(word),
               tag == .noun || tag == .verb || tag == .adjective {
                
                // 计算关键词得分（出现频率）
                keywordScores[word, default: 0] += 1
            }
            
            return true
        }
        
        // 按得分排序，取前 5-8 个
        keywords = keywordScores
            .sorted { $0.value > $1.value }
            .prefix(8)
            .map { $0.key }
        
        // 如果关键词太少，尝试提取词组（2-3 个字的组合）
        if keywords.count < 5 {
            keywords.append(contentsOf: extractPhrases(from: text, stopWords: stopWords))
        }
        
        return Array(keywords.prefix(8))
    }
    
    // MARK: - 提取词组（辅助关键词提取）
    
    private func extractPhrases(from text: String, stopWords: Set<String>) -> [String] {
        var phrases: [String] = []
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        
        var currentPhrase: [String] = []
        
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass
        ) { tag, tokenRange in
            guard let tag = tag else {
                // 遇到标点或空格，结束当前词组
                if currentPhrase.count >= 2 && currentPhrase.count <= 3 {
                    let phrase = currentPhrase.joined()
                    if phrase.count >= 4 && phrase.count <= 8 {
                        phrases.append(phrase)
                    }
                }
                currentPhrase = []
                return true
            }
            
            let word = String(text[tokenRange]).trimmingCharacters(in: .whitespaces)
            
            if word.count >= 2,
               !stopWords.contains(word),
               tag == .noun || tag == .verb {
                currentPhrase.append(word)
            } else {
                if currentPhrase.count >= 2 && currentPhrase.count <= 3 {
                    let phrase = currentPhrase.joined()
                    if phrase.count >= 4 && phrase.count <= 8 {
                        phrases.append(phrase)
                    }
                }
                currentPhrase = []
            }
            
            return true
        }
        
        return Array(phrases.prefix(3))
    }
    
    // MARK: - 摘要生成
    
    private func generateSummary(from text: String, language: NLLanguage) -> String {
        guard !text.isEmpty else { return "" }
        
        // 1. 分割句子
        let sentences = splitIntoSentences(text: text)
        guard !sentences.isEmpty else {
            // 如果没有句子分隔符，返回前 50 个字符
            return text.count > 50 ? String(text.prefix(50)) + "..." : text
        }
        
        // 2. 提取所有关键词（用于计算句子重要性）
        let allKeywords = extractKeywords(from: text, language: language)
        let keywordSet = Set(allKeywords)
        
        // 3. 计算每个句子的得分
        var sentenceScores: [(String, Double)] = []
        
        for (index, sentence) in sentences.enumerated() {
            var score: Double = 0.0
            
            // 关键词密度：句子中包含的关键词数量 / 句子长度
            let sentenceWords = sentence.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
                .filter { !$0.isEmpty }
            
            let keywordCount = sentenceWords.filter { keywordSet.contains($0) }.count
            let keywordDensity = sentenceWords.isEmpty ? 0.0 : Double(keywordCount) / Double(sentenceWords.count)
            
            // 位置权重：第一句和最后一句通常更重要
            let positionWeight: Double
            if index == 0 {
                positionWeight = 1.5
            } else if index == sentences.count - 1 {
                positionWeight = 1.2
            } else {
                positionWeight = 1.0
            }
            
            // 长度权重：太短或太长的句子得分降低
            let lengthWeight: Double
            if sentence.count < 10 {
                lengthWeight = 0.5
            } else if sentence.count > 100 {
                lengthWeight = 0.8
            } else {
                lengthWeight = 1.0
            }
            
            score = keywordDensity * 100 * positionWeight * lengthWeight
            sentenceScores.append((sentence, score))
        }
        
        // 4. 选择得分最高的 1-2 个句子
        sentenceScores.sort { $0.1 > $1.1 }
        
        let topSentences = sentenceScores.prefix(2).map { $0.0 }
        let summary = topSentences.joined(separator: "。")
        
        // 5. 限制长度
        if summary.count > 80 {
            return String(summary.prefix(80)) + "..."
        }
        
        return summary.isEmpty ? (text.count > 50 ? String(text.prefix(50)) + "..." : text) : summary
    }
    
    // MARK: - 分割句子
    
    private func splitIntoSentences(text: String) -> [String] {
        let separators = CharacterSet(charactersIn: "。！？.!?")
        let sentences = text.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return sentences
    }
    
    // MARK: - 情绪分析
    
    private func detectSentiment(from text: String, language: NLLanguage) -> Sentiment {
        guard !text.isEmpty else { return .neutral }
        
        // 扩展的情绪词典
        let positiveWords = Self.positiveWords
        let negativeWords = Self.negativeWords
        
        // 否定词（会反转情绪）
        let negationWords = Self.negationWords
        
        // 程度词（会增强情绪）
        let intensityWords = Self.intensityWords
        
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        tagger.setLanguage(language, range: text.startIndex..<text.endIndex)
        
        var positiveScore: Double = 0.0
        var negativeScore: Double = 0.0
        
        var previousWord: String = ""
        var previousIntensity: Double = 1.0
        
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass
        ) { tag, tokenRange in
            let word = String(text[tokenRange]).lowercased()
            
            // 检查是否是程度词
            if let intensity = intensityWords[word] {
                previousIntensity = intensity
                previousWord = word
                return true
            }
            
            // 检查是否是情绪词
            var isPositive = positiveWords.contains(word)
            var isNegative = negativeWords.contains(word)
            
            // 检查前一个词是否是否定词
            let isNegated = negationWords.contains(previousWord)
            
            // 计算得分
            if isPositive {
                let score = previousIntensity * (isNegated ? -1.0 : 1.0)
                positiveScore += abs(score)
                if isNegated {
                    negativeScore += abs(score) * 0.5  // 否定积极词 = 轻微消极
                }
            } else if isNegative {
                let score = previousIntensity * (isNegated ? -1.0 : 1.0)
                negativeScore += abs(score)
                if isNegated {
                    positiveScore += abs(score) * 0.5  // 否定消极词 = 轻微积极
                }
            }
            
            previousWord = word
            previousIntensity = 1.0
            
            return true
        }
        
        // 判断情绪
        if positiveScore > negativeScore * 1.2 {
            return .positive
        } else if negativeScore > positiveScore * 1.2 {
            return .negative
        } else {
            return .neutral
        }
    }
    
    // MARK: - 任务识别
    
    private func extractTodos(from text: String, language _: NLLanguage) -> [TodoItem] {
        guard !text.isEmpty else { return [] }
        
        var todos: [TodoItem] = []
        
        // 1. 分割句子
        let sentences = splitIntoSentences(text: text)
        
        // 2. 时间词模式（扩展版）
        let timePatterns = Self.timePatterns
        
        // 3. 动作词（常见的任务动词）
        let actionWords = Self.actionWords
        
        for sentence in sentences {
            // 改进待办提取逻辑：利用 NLTagger 进行词性分析
            let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
            tagger.string = sentence
            
            var hasActionVerb = false
            
            // 检查句子中是否有动词
            tagger.enumerateTags(in: sentence.startIndex..<sentence.endIndex, unit: .word, scheme: .lexicalClass) { tag, _ in
                if tag == .verb {
                    hasActionVerb = true
                }
                return true
            }
            
            // 检查是否包含时间词，或动作词，或含有实际动词
            let hasTimeWord = timePatterns.contains { sentence.contains($0) } || (parseDate(from: sentence) != nil)
            let hasActionWord = actionWords.contains { sentence.contains($0) }
            
            // 条件放宽：只要有时间+任意动词，或者明确的动作词，就认为是任务
            if (hasTimeWord && hasActionVerb) || (hasTimeWord && hasActionWord) {
                // 提取任务文本（清理一下）
                let todoText = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // 尝试解析日期
                let dueDate = parseDate(from: sentence)
                
                todos.append(TodoItem(text: todoText, dueDate: dueDate))
            }
        }
        
        return todos
    }
    
    // MARK: - 日期解析
    
    private func parseDate(from text: String) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        var targetDate: Date?
        
        // 0. 尝试提取确切的 X月X日
        if let match = Self.dateRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let monthRange = Range(match.range(at: 1), in: text),
           let dayRange = Range(match.range(at: 2), in: text),
           let month = Int(text[monthRange]),
           let day = Int(text[dayRange]) {
            var comps = calendar.dateComponents([.year], from: now)
            comps.month = month
            comps.day = day
            
            if let parsedDate = calendar.date(from: comps) {
                // 如果解析出的日期比今天还早很多（比如跨年了），默认算明年的
                if parsedDate < calendar.date(byAdding: .month, value: -1, to: now)! {
                    comps.year = (comps.year ?? calendar.component(.year, from: now)) + 1
                    targetDate = calendar.date(from: comps)
                } else {
                    targetDate = parsedDate
                }
            }
        }
        
        // 1. 先解析星期
        let weekdayMap: [String: Int] = [
            "周一": 2, "周二": 3, "周三": 4, "周四": 5, "周五": 6, "周六": 7, "周日": 1
        ]
        
        if targetDate == nil {
            for (key, targetWeekday) in weekdayMap {
                if text.contains(key) {
                    let currentWeekday = calendar.component(.weekday, from: now)
                    var daysToAdd = targetWeekday - currentWeekday
                    
                    // 处理"下周一"等
                    if let match = Self.dayRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                        daysToAdd += 7
                    }
                    
                    // 如果目标星期已经过了，加 7 天
                    if daysToAdd <= 0 {
                        daysToAdd += 7
                    }
                    
                    targetDate = calendar.date(byAdding: .day, value: daysToAdd, to: calendar.startOfDay(for: now))
                    break
                }
            }
        }
        
        // 2. 如果没有找到星期，解析相对日期
        if targetDate == nil {
            if text.contains("明早") || text.contains("明晨") || text.contains("明晚") {
                targetDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            } else if text.contains("今晚") || text.contains("今早") || text.contains("今晨") || text.contains("今天") {
                targetDate = calendar.startOfDay(for: now)
            } else if text.contains("明天") {
                targetDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            } else if text.contains("后天") {
                targetDate = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: now))
            } else if text.contains("大后天") {
                targetDate = calendar.date(byAdding: .day, value: 3, to: calendar.startOfDay(for: now))
            }
        }
        
        // 3. 解析时间（无论是否有日期，都尝试解析时间）
        return parseTime(from: text, baseDate: targetDate)
    }
    
    // MARK: - 时间解析
    
    private func parseTime(from text: String, baseDate: Date?) -> Date? {
        // 如果没有日期，返回 nil（或者可以返回今天+时间）
        guard let baseDate = baseDate else {
            // 如果只有时间没有日期，可以返回今天+时间
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            return parseTimeOnly(from: text, baseDate: today)
        }
        
        return parseTimeOnly(from: text, baseDate: baseDate)
    }
    
    private func parseTimeOnly(from text: String, baseDate: Date) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
        
        var hour: Int? = nil
        var minute = 0
        
        if let digitalTime = extractDigitalTime(from: text) {
            hour = digitalTime.hour
            minute = digitalTime.minute
        }
        
        if hour == nil {
            // 1. 先解析具体时间点（优先匹配长的词："十一"、"十二"）
            let hourMap: [(String, Int)] = [
                ("十一", 11), ("十二", 12),  // 先匹配长的
                ("两", 2), ("一", 1), ("二", 2), ("三", 3), ("四", 4), ("五", 5),
                ("六", 6), ("七", 7), ("八", 8), ("九", 9), ("十", 10)
            ]
            
            for (key, value) in hourMap {
                if text.contains("\(key)点") || text.contains("\(key)时") {
                    hour = value
                    break
                }
            }
        }
        
        // 2. 如果没有找到具体时间点，根据时间段设置默认时间
        if hour == nil {
            if text.contains("早上") || text.contains("早晨") || text.contains("清晨") || text.contains("明早") || text.contains("今早") {
                hour = 8
            } else if text.contains("上午") {
                hour = 9
            } else if text.contains("下午") {
                hour = 14
            } else if text.contains("傍晚") {
                hour = 18
            } else if text.contains("晚上") || text.contains("今晚") || text.contains("明晚") {
                hour = 19
            } else if text.contains("中午") {
                hour = 12
            } else if text.contains("凌晨") {
                hour = 6
            } else {
                // 如果既没有具体时间点，也没有时间段，返回 nil 或默认时间
                hour = 9  // 默认上午 9 点
            }
        } else if var h = hour {
            // 3. 如果找到了具体时间点，检查是否需要转换（下午的时间需要 +12）
            if text.contains("下午") && h < 12 {
                h += 12
            } else if (text.contains("晚上") || text.contains("今晚") || text.contains("明晚")) && h < 12 {
                h += 12
            } else if text.contains("中午") && h < 11 {
                h += 12
            }
            hour = h
        }
        
        // 4. 解析分钟
        if minute == 0 {
            if text.contains("半") {
                minute = 30
            } else if text.contains("一刻") {
                minute = 15
            } else if text.contains("三刻") {
                minute = 45
            }
        }
        
        components.hour = hour
        components.minute = minute
        
        return calendar.date(from: components)
    }
    
    private func extractDigitalTime(from text: String) -> (hour: Int, minute: Int)? {
        // 1) HH:mm / HH：mm
        let regex = Self.colonRegex
        if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let hourRange = Range(match.range(at: 1), in: text),
           let minuteRange = Range(match.range(at: 2), in: text),
           let hour = Int(text[hourRange]),
           let minute = Int(text[minuteRange]) {
            return (hour, minute)
        }
        
        // 2) H点 / H时 / H点M分
        let hmRegex = Self.hmRegex
        if let match = hmRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let hourRange = Range(match.range(at: 1), in: text),
           let hour = Int(text[hourRange]),
           hour >= 0, hour <= 23 {
            
            var minute = 0
            if let minuteRange = Range(match.range(at: 2), in: text),
               let parsedMinute = Int(text[minuteRange]),
               parsedMinute >= 0, parsedMinute <= 59 {
                minute = parsedMinute
            } else if text.contains("半") {
                minute = 30
            } else if text.contains("一刻") {
                minute = 15
            } else if text.contains("三刻") {
                minute = 45
            }
            return (hour, minute)
        }
        
        return nil
    }
}
