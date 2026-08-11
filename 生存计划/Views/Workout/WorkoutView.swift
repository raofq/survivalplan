import SwiftUI
import SwiftData

struct WorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var records: [WorkoutRecord]
    
    @State private var selectedType = "散步"
    @State private var duration = ""
    @State private var note = ""
    @State private var showFeedback = false
    
    let workoutTypes = ["散步", "跑步", "居家健身", "骑行", "瑜伽", "其他"]
    
    private var weekCount: Int {
        let calendar = Calendar.current
        let weekStart = calendar.date(byAdding: .day, value: -6, to: Date()) ?? Date()
        return records.filter { $0.date >= weekStart }.count
    }
    
    private var weekMinutes: Int {
        let calendar = Calendar.current
        let weekStart = calendar.date(byAdding: .day, value: -6, to: Date()) ?? Date()
        return records.filter { $0.date >= weekStart }.reduce(0) { $0 + $1.duration }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                    // 周概览
                    HStack(spacing: 12) {
                        StatItem(value: "\(weekCount)", label: "本周打卡", color: .blue)
                        StatItem(value: "\(weekMinutes)" + L("分"), label: "本周时长", color: .green)
                        StatItem(value: "\(streakDays)", label: "连续天数", color: .orange)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                    
                    // 打卡表单
                    VStack(spacing: 14) {
                        Text(L("记录一次运动"))
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(workoutTypes, id: \.self) { type in
                                    Button(L(type)) {
                                        selectedType = type
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(selectedType == type ? .blue : .gray)
                                    .font(.caption)
                                }
                            }
                        }
                        
                        HStack {
                            TextField("运动时长（分钟）", text: $duration)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                            Text(L("分钟"))
                                .font(.subheadline)
                        }
                        
                        Button(action: saveWorkout) {
                            Text(L("打卡"))
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.green, in: .capsule)
                        }
                        
                        if showFeedback {
                            Label(L("打卡成功，保持节奏！"), systemImage: "checkmark.circle.fill")
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
                                Image(systemName: "figure.walk")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                                Text(L("还没有运动记录，动起来吧！"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        } else {
                            ForEach(records.prefix(10)) { record in
                                HStack {
                                    Image(systemName: "figure.walk")
                                        .foregroundStyle(.green)
                                    Text(L(record.type))
                                        .font(.subheadline)
                                    Text("\(record.duration) 分钟")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(record.date, format: .dateTime.month().day().hour().minute())
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
            }
            .padding()
        }
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle("运动")
    }
    
    private var streakDays: Int {
        let calendar = Calendar.current
        var streak = 0
        var day = Date()
        while records.contains(where: { calendar.isDate($0.date, inSameDayAs: day) }) {
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return streak
    }
    
    private func saveWorkout() {
        AnalyticsService.shared.track("action_checkin_workout")
        guard let mins = Int(duration), mins > 0 else { return }
        let record = WorkoutRecord()
        record.type = selectedType
        record.duration = mins
        record.note = note
        record.date = Date()
        modelContext.insert(record)
        try? modelContext.save()
        let workoutType = selectedType
        let durationMins = mins
        let streak = streakDays + 1
        duration = ""
        note = ""
        showFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showFeedback = false }
        }
        // 打卡联动：自动分享到圈子
        let author = UserDefaults.standard.string(forKey: "circle_author") ?? "匿名"
        Task {
            let title = "运动打卡第 \(streak) 天"
            let content = "今天\(workoutType) \(durationMins) 分钟，连续打卡 \(streak) 天。一起来互相监督吧！"
            try? await CircleAPI.createPost(category: "运动", title: title, content: content, author: author)
        }
    }
}
