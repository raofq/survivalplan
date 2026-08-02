import SwiftUI
import Charts
import SwiftData

struct DashboardView: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseRecord.date, order: .reverse) private var expenses: [ExpenseRecord]
    
    private var report: SurvivalReport {
        SurvivalCalculator.calculate(from: profile)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 风险等级卡片
                    RiskCard(report: report)
                    
                    // 概览卡片
                    OverviewCard(report: report)
                    
                    // 本月可用预算走势
                    FundTimelineCard(report: report, expenses: expenses)

                    // 今日预算 + 快速记账 + 今日支出（合并模块）
                    DailyBudgetCard(report: report, spentToday: todaySpent)
                    QuickExpenseCard(profile: profile, expenses: expenses, todayExpenses: todayExpenses)
                }
                .padding()
            }
            .navigationTitle("生存计划")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("设置") {
                        SettingsView(profile: profile)
                    }
                }
            }
        }
    }
    
    private var todayExpenses: [ExpenseRecord] {
        expenses.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var todaySpent: Double {
        todayExpenses.reduce(0) { $0 + $1.amount }
    }

}

// MARK: - 风险等级卡
struct RiskCard: View {
    let report: SurvivalReport
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: report.isWarning ? "exclamationmark.triangle.fill" :
                        report.monthsCanSurvive < 6 ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(report.isWarning ? .red : report.monthsCanSurvive < 6 ? .orange : .green)
                
                Text(report.isWarning ? "资金紧张" : report.monthsCanSurvive < 6 ? "需要关注" : "状况良好")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            Text(report.warningMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }
}

// MARK: - 概览卡
struct OverviewCard: View {
    let report: SurvivalReport
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.pie.fill")
                Text("财务概览")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 0) {
                StatItem(value: "\(Int(report.monthsCanSurvive))", label: "可撑(月)", color: .blue)
                StatItem(value: formatCurrency(report.dailyBudget), label: "每日预算", color: .green)
                StatItem(value: formatCurrency(report.monthlyShortfall), label: "月缺口", color: .red)
            }
            
            Divider()
            
            HStack {
                Text("资金耗尽日")
                Spacer()
                Text(report.exhaustionDate, style: .date)
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)
            }
            .font(.subheadline)
            
            HStack {
                Text("可用资金")
                Spacer()
                Text(formatCurrency(report.totalSavings))
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
        }
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "¥0"
    }
}

struct StatItem: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 本月可用预算走势卡
struct FundTimelineCard: View {
    let report: SurvivalReport
    let expenses: [ExpenseRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                Text("本月剩余预算")
                    .font(.headline)
                Spacer()
                Text("月初至今")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                row(label: "本月预算", value: formatCurrency(monthBudget), color: .primary)
                row(label: "本月已花", value: formatCurrency(monthSpent), color: .red)
                Divider()
                row(label: "本月剩余", value: formatCurrency(max(monthBudget - monthSpent, 0)), color: monthSpent > monthBudget ? .red : .green, bold: true)
                row(label: "剩余天数", value: "\(daysLeft) 天", color: .secondary)
                row(label: "日均可用", value: formatCurrency(dailyRemaining), color: dailyRemaining < 0 ? .red : .blue)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func row(label: String, value: String, color: Color, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(bold ? .headline : .subheadline)
                .fontWeight(bold ? .bold : .regular)
                .foregroundStyle(color)
        }
    }

    private var monthBudget: Double {
        report.totalMonthlyExpenses
    }

    private var monthSpent: Double {
        monthExpenses.reduce(0) { $0 + $1.amount }
    }

    private var daysLeft: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dayOfMonth = calendar.component(.day, from: today)
        return max(daysInMonth - dayOfMonth + 1, 0)
    }

    private var dailyRemaining: Double {
        daysLeft > 0 ? (monthBudget - monthSpent) / Double(daysLeft) : 0
    }

    private var monthExpenses: [ExpenseRecord] {
        let calendar = Calendar.current
        return expenses.filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }
    }

    private var daysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: Date())?.count ?? 30
    }

    private func formatCurrency(_ value: Double) -> String {
        "¥\(Int(value))"
    }
}

// MARK: - 每日预算卡
struct DailyBudgetCard: View {
    let report: SurvivalReport
    let spentToday: Double

    // 今日可用 = 弹性预算分摊（刚性不可控，不参与可用额度）
    private var flexibleDaily: Double { report.flexibleExpenses / 30.0 }
    private var essentialDaily: Double { report.essentialExpenses / 30.0 }
    private var remaining: Double { flexibleDaily - spentToday }
    private var isOver: Bool { remaining < 0 }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "calendar.day.timeline.left")
                Text("今日可用预算")
                    .font(.headline)
                Spacer()
                Text(formatCurrency(max(remaining, 0)))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(isOver ? .red : .blue)
            }

            HStack {
                Text("已用 \(formatCurrency(spentToday)) / 可花 \(formatCurrency(flexibleDaily))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if isOver {
                    Text("已超支 \(formatCurrency(-remaining))")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                }
            }

            HStack {
                Image(systemName: "lock.fill")
                Text("固定支出 \(formatCurrency(essentialDaily)) / 天（房贷、物业等，不含在可花额度内）")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }
    
    private func formatCurrency(_ value: Double) -> String {
        "¥\(Int(value))"
    }
}

// MARK: - 快速记账卡
struct QuickExpenseCard: View {
    let profile: UserProfile
    let expenses: [ExpenseRecord]
    let todayExpenses: [ExpenseRecord]
    @Environment(\.modelContext) private var modelContext
    @State private var showSheet = false
    @State private var amount = ""
    @State private var category = "食品"
    @State private var note = ""
    
    let categories = ["食品", "交通", "医疗", "人情", "购物", "教育", "其他"]
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "list.clipboard")
                Text("今日支出")
                    .font(.headline)
                Spacer()
                Text("共 \(todayExpenses.count) 笔")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { cat in
                        Button {
                            category = cat
                            showSheet = true
                        } label: {
                            Text(cat.map { String($0) }.joined(separator: "\n"))
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .frame(width: 34, height: 46)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .sheet(isPresented: $showSheet) {
                NavigationStack {
                    Form {
                        TextField("金额", text: $amount)
                            .keyboardType(.decimalPad)
                        TextField("备注（可选）", text: $note)
                    }
                    .navigationTitle(category)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("取消") { showSheet = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("保存") {
                                saveExpense()
                                showSheet = false
                            }
                        }
                    }
                }
                .presentationDetents([.height(250)])
            }

            // 今日支出列表
            Divider()

            if todayExpenses.isEmpty {
                Text("今天还没有支出记录")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(todayExpenses.prefix(6)) { expense in
                    HStack {
                        Text(expense.category)
                            .font(.caption)
                        if !expense.note.isEmpty {
                            Text(expense.note)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(formatCurrency(expense.amount))
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                }
                if todayExpenses.count > 6 {
                    Text("还有 \(todayExpenses.count - 6) 笔…")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func saveExpense() {
        guard let amt = Double(amount), amt > 0 else { return }
        let record = ExpenseRecord(category: category, amount: amt, note: note)
        modelContext.insert(record)
        try? modelContext.save()
        amount = ""; note = ""
    }

    private func formatCurrency(_ value: Double) -> String {
        "¥\(Int(value))"
    }
}
