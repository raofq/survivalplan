import SwiftUI
import SwiftData

struct StudyView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StudyRecord.date, order: .reverse) private var records: [StudyRecord]
    
    @State private var skill = ""
    @State private var content = ""
    @State private var duration = ""
    @State private var showFeedback = false
    
    private var weekMinutes: Int {
        let calendar = Calendar.current
        let weekStart = calendar.date(byAdding: .day, value: -6, to: Date()) ?? Date()
        return records.filter { $0.date >= weekStart }.reduce(0) { $0 + $1.duration }
    }
    
    private var totalMinutes: Int {
        records.reduce(0) { $0 + $1.duration }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                    // 周概览
                    HStack(spacing: 12) {
                        StatItem(value: "\(records.count)", label: "累计学习", color: .blue)
                        StatItem(value: "\(weekMinutes)" + L("分"), label: "本周时长", color: .green)
                        StatItem(value: "\(totalMinutes / 60)h", label: "总时长", color: .orange)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                    
                    // 记录表单
                    VStack(spacing: 14) {
                        Text(L("记录一次学习"))
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        TextField("学的是什么技能？", text: $skill)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("学了什么内容？（可选）", text: $content, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)
                        
                        HStack {
                            TextField("学习时长（分钟）", text: $duration)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                            Text(L("分钟"))
                                .font(.subheadline)
                        }
                        
                        Button(action: saveStudy) {
                            Text(L("记录"))
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.blue, in: .capsule)
                        }
                        
                        if showFeedback {
                            Label(L("已记录，每天进步一点点"), systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                    
                    // 最近记录
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L("最近记录"))
                            .font(.headline)
                        
                        if records.isEmpty {
                            VStack(spacing: 6) {
                                Image(systemName: "book.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                                Text(L("还没有学习记录，开始学点新技能吧"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        } else {
                            ForEach(records.prefix(10)) { record in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(record.skill)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        Spacer()
                                        Text("\(record.duration) 分钟")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if !record.content.isEmpty {
                                        Text(record.content)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    Text(record.date, format: .dateTime.month().day().hour().minute())
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
            }
            .padding()
        }
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle("学习")
    }
    
    private func saveStudy() {
        AnalyticsService.shared.track("action_checkin_study")
        guard !skill.isEmpty, let mins = Int(duration), mins > 0 else { return }
        let record = StudyRecord()
        record.skill = skill
        record.content = content
        record.duration = mins
        record.date = Date()
        modelContext.insert(record)
        try? modelContext.save()
        let studySkill = skill
        let durationMins = mins
        let totalCount = records.count + 1
        skill = ""
        content = ""
        duration = ""
        showFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showFeedback = false }
        }
        // 打卡联动：自动分享到圈子
        let author = UserDefaults.standard.string(forKey: "circle_author") ?? "匿名"
        Task {
            let title = "学习打卡第 \(totalCount) 次"
            let content = "今天学了 \(studySkill) \(durationMins) 分钟，累计学习 \(totalCount) 次。失业期也要充电！"
            try? await CircleAPI.createPost(category: "学习", title: title, content: content, author: author)
        }
    }
}
