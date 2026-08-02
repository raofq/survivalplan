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
                    
                    // 资金走势
                    FundTimelineCard(report: report)

                    // 今日预算 + 快速记账 + 今日支出（合并模块）
                    DailyBudgetCard(report: report, spentToday: todaySpent, categorySpent: todaySpentByCategory)
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

    private var todaySpentByCategory: [String: Double] {
        Dictionary(grouping: todayExpenses) { $0.category }
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
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

// MARK: - 资金走势卡
struct FundTimelineCard: View {
    let report: SurvivalReport

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.downtrend.xyaxis")
                Text("资金走势")
                    .font(.headline)
                Spacer()
                Text("未来12个月")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Chart(Array(report.timeline.prefix(12))) { month in
                AreaMark(
                    x: .value("月份", month.id),
                    y: .value("积蓄", month.savingsAfter)
                )
                .foregroundStyle(.blue.opacity(0.12))
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("月份", month.id),
                    y: .value("积蓄", month.savingsAfter)
                )
                .foregroundStyle(.blue)
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("¥\(Int(v))")
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { value in
                    AxisValueLabel {
                        if let month = value.as(Int.self) {
                            Text("\(month)月")
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 160)

            if report.monthsCanSurvive < 12 {
                Label("资金将在第 \(Int(report.monthsCanSurvive)) 个月耗尽", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Label("12 个月内资金充足", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }
}

// MARK: - 每日预算卡
struct DailyBudgetCard: View {
    let report: SurvivalReport
    let spentToday: Double
    let categorySpent: [String: Double]

    private var remaining: Double { report.dailyBudget - spentToday }
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
                Text("已用 \(formatCurrency(spentToday)) / 预算 \(formatCurrency(report.dailyBudget))")
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
            
            Divider()
            
            BudgetRow(label: "食品", budget: report.foodBudget, spent: categorySpent["食品"] ?? 0)
            BudgetRow(label: "交通", budget: report.transportBudget, spent: categorySpent["交通"] ?? 0)
            BudgetRow(label: "医疗", budget: report.medicalBudget, spent: categorySpent["医疗"] ?? 0)
            BudgetRow(label: "人情", budget: report.socialBudget, spent: categorySpent["人情"] ?? 0)
            BudgetRow(label: "购物", budget: report.shoppingBudget, spent: categorySpent["购物"] ?? 0)
        }
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }
    
    private func formatCurrency(_ value: Double) -> String {
        "¥\(Int(value))"
    }
}

struct BudgetRow: View {
    let label: String
    let budget: Double
    let spent: Double

    private var pct: Double { budget > 0 ? spent / budget : 0 }
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .frame(width: 40, alignment: .leading)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.gray.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(pct > 1 ? Color.red : Color.blue)
                        .frame(width: geo.size.width * min(pct, 1), height: 8)
                }
            }
            .frame(height: 8)
            
            Text("¥\(Int(spent))/\(Int(budget))")
                .font(.caption)
                .foregroundStyle(pct > 1 ? .red : .secondary)
                .frame(width: 50, alignment: .trailing)
        }
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
    @State private var feedback: (message: String, isWarning: Bool)?
    
    let categories = ["食品", "交通", "医疗", "人情", "购物", "教育", "其他"]
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("快速记账")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { cat in
                    Button(cat) {
                        category = cat
                        showSheet = true
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
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

            // 记账反馈条
            if let fb = feedback {
                HStack(spacing: 8) {
                    Image(systemName: fb.isWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    Text(fb.message)
                        .font(.caption)
                        .lineLimit(2)
                    Spacer()
                }
                .foregroundStyle(fb.isWarning ? .red : .green)
                .padding(10)
                .background((fb.isWarning ? Color.red : Color.green).opacity(0.1), in: .rect(cornerRadius: 10))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // 今日支出列表
            Divider()

            HStack {
                Text("今日支出")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("共 \(todayExpenses.count) 笔")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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

        let report = SurvivalCalculator.calculate(from: profile)
        let calendar = Calendar.current

        // 分类本月支出（含刚记的这笔）
        let monthExpenses = expenses.filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }
            .reduce(amt) { $0 + $1.amount }
        let categoryMonthlyBudget = monthlyBudget(for: category, report: report)

        // 今日总支出（含刚记的这笔）
        let todayTotal = expenses.filter { calendar.isDateInToday($0.date) }
            .reduce(amt) { $0 + $1.amount }

        if categoryMonthlyBudget > 0 && monthExpenses > categoryMonthlyBudget {
            feedback = ("「\(category)」本月已超支 ¥\(Int(monthExpenses - categoryMonthlyBudget))", true)
        } else if todayTotal > report.dailyBudget && report.dailyBudget > 0 {
            feedback = ("今日已超预算 ¥\(Int(todayTotal - report.dailyBudget))，注意控制", true)
        } else if report.dailyBudget > 0 {
            feedback = ("已记账，今日还剩 ¥\(Int(report.dailyBudget - todayTotal)) 可用", false)
        }
    }

    private func monthlyBudget(for cat: String, report: SurvivalReport) -> Double {
        switch cat {
        case "食品": return report.foodBudget * 30
        case "交通": return report.transportBudget * 30
        case "医疗": return report.medicalBudget * 30
        case "人情": return report.socialBudget * 30
        case "购物": return report.shoppingBudget * 30
        default: return 0
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        "¥\(Int(value))"
    }
}
