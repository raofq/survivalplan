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
                        StatItem(value: "\(weekMinutes)分", label: "本周时长", color: .green)
                        StatItem(value: "\(totalMinutes / 60)h", label: "总时长", color: .orange)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                    
                    // 记录表单
                    VStack(spacing: 14) {
                        Text("记录一次学习")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        TextField("学的是什么技能？", text: $skill)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("学了什么内容？（可选）", text: $content, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)
                        
                        HStack {
                            TextField("学习时长（分钟）", text: $duration)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                            Text("分钟")
                                .font(.subheadline)
                        }
                        
                        Button(action: saveStudy) {
                            Text("记录")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.blue, in: .capsule)
                        }
                        
                        if showFeedback {
                            Label("已记录，每天进步一点点", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                    
                    // 最近记录
                    VStack(alignment: .leading, spacing: 10) {
                        Text("最近记录")
                            .font(.headline)
                        
                        if records.isEmpty {
                            Text("还没有学习记录，开始学点新技能吧")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
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
        guard !skill.isEmpty, let mins = Int(duration), mins > 0 else { return }
        let record = StudyRecord()
        record.skill = skill
        record.content = content
        record.duration = mins
        record.date = Date()
        modelContext.insert(record)
        try? modelContext.save()
        skill = ""
        content = ""
        duration = ""
        showFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showFeedback = false }
        }
    }
}
