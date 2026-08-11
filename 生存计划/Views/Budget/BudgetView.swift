import SwiftUI
import Charts
import SwiftData

struct BudgetView: View {
    let profile: UserProfile
    @Query(sort: \ExpenseRecord.date, order: .reverse) private var expenses: [ExpenseRecord]
    
    @State private var reportCache: SurvivalReport?
    private var report: SurvivalReport {
        reportCache ?? SurvivalCalculator.calculate(from: profile)
    }
    
    // 最近30天支出
    private var recentExpenses: [ExpenseRecord] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return expenses.filter { $0.date >= cutoff }
    }
    
    // 按分类汇总
    private var expensesByCategory: [(String, Double)] {
        Dictionary(grouping: recentExpenses) { $0.category }
            .map { ($0.key, $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.1 > $1.1 }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if let report = reportCache {
                ScrollView {
                VStack(spacing: 16) {
                    // 本周预算
                    VStack(spacing: 8) {
                        Text(L("本周预算"))
                            .font(.headline)
                        Text("\(money(report.weeklyBudget))")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(.blue)
                        Text("每日 ¥\(Int(report.dailyBudget.rounded()))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                    
                    // 分类预算进度
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L("分类预算"))
                            .font(.headline)
                        
                        BudgetProgressRow(label: "食品", budget: report.foodBudget * 30, spent: categoryTotal("食品"))
                        BudgetProgressRow(label: "交通", budget: report.transportBudget * 30, spent: categoryTotal("交通"))
                        BudgetProgressRow(label: "医疗", budget: report.medicalBudget * 30, spent: categoryTotal("医疗"))
                        BudgetProgressRow(label: "教育", budget: report.educationBudget * 30, spent: categoryTotal("教育"))
                        BudgetProgressRow(label: "人情", budget: report.socialBudget * 30, spent: categoryTotal("人情"))
                        BudgetProgressRow(label: "购物", budget: report.shoppingBudget * 30, spent: categoryTotal("购物"))
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))

                    // 月底支出预测
                    if let prediction = monthlyPrediction {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "chart.xyaxis.line")
                                Text(L("月底支出预测"))
                                    .font(.headline)
                                Spacer()
                            }

                            HStack(spacing: 0) {
                                StatItem(value: formatCurrency(prediction.projectedTotal), label: "预计月底", color: prediction.isOver ? .red : .blue)
                                StatItem(value: formatCurrency(prediction.monthlyBudget), label: "月度预算", color: .gray)
                                StatItem(value: formatCurrency(abs(prediction.diff)), label: prediction.isOver ? "超支" : "结余", color: prediction.isOver ? .red : .green)
                            }

                            if prediction.isOver {
                                Label("按当前消费速度，月底将超支 ¥\(Int(prediction.diff))，建议控制支出", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            } else {
                                Label("按当前消费速度，月底预计结余 ¥\(Int(abs(prediction.diff)))", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                    }
                    
                    // 支出趋势（最近7天）
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L("最近7天支出"))
                            .font(.headline)
                        
                        Chart {
                            ForEach(last7DaysExpenses, id: \.date) { day in
                                BarMark(
                                    x: .value("日期", day.date, unit: .day),
                                    y: .value("金额", day.total)
                                )
                                .foregroundStyle(.blue.gradient)
                            }
                        }
                        .frame(height: 180)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                }
                    .padding()
                }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .scrollIndicators(.hidden)
            .onAppear {
                // 每次进入都重算：设置改动后预算页数据实时联动
                let d = UserProfileDraft(profile: profile)   // 主线程取值快照——后台不碰 @Model
                Task.detached(priority: .userInitiated) {
                    let r = SurvivalCalculator.calculate(from: d)
                    await MainActor.run { reportCache = r }
                }
            }
        .navigationTitle("预算")
        }
    }
    
    private func categoryTotal(_ category: String) -> Double {
        recentExpenses.filter { $0.category == category }.reduce(0) { $0 + $1.amount }
    }
    
    private var last7DaysExpenses: [(date: Date, total: Double)] {
        let calendar = Calendar.current
        return (0..<7).reversed().map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            let total = expenses.filter { calendar.isDate($0.date, inSameDayAs: date) }
                .reduce(0) { $0 + $1.amount }
            return (date, total)
        }
    }

    /// 月底支出预测 = 刚性支出（固定必花） + 本月已花（弹性实际） + 日均弹性支出 × 本月剩余天数
    private var monthlyPrediction: (projectedTotal: Double, monthlyBudget: Double, diff: Double, isOver: Bool)? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let firstExpense = expenses.map(\.date).min() else { return nil }

        // 实际覆盖天数：第一笔支出至今的天数（含首尾），封顶30天
        let daysSinceFirst = calendar.dateComponents([.day], from: calendar.startOfDay(for: firstExpense), to: today).day ?? 0
        let daysCovered = min(30, max(1, daysSinceFirst + 1))

        let cutoff = calendar.date(byAdding: .day, value: -(daysCovered - 1), to: today) ?? today
        let recent = expenses.filter { $0.date >= cutoff }

        let dailyAvg = recent.reduce(0.0) { $0 + $1.amount } / Double(daysCovered)
        let daysInMonth = calendar.range(of: .day, in: .month, for: Date())?.count ?? 30
        let daysLeft = max(daysInMonth - calendar.component(.day, from: today), 0)

        let report = SurvivalCalculator.calculate(from: profile)
        let essential = report.essentialExpenses                      // 刚性：固定必花
        let monthSpent = expenses.filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }
            .reduce(0.0) { $0 + $1.amount }                           // 本月已花（弹性实际）
        let projectedTotal = essential + monthSpent + dailyAvg * Double(daysLeft)
        let budget = report.totalMonthlyExpenses
        let diff = projectedTotal - budget

        return (projectedTotal, budget, diff, diff > 0)
    }

    private func formatCurrency(_ value: Double) -> String {
        return money(value)

    }
}

struct BudgetProgressRow: View {
    let label: String
    let budget: Double
    let spent: Double
    
    var pct: Double { budget > 0 ? spent / budget : 0 }
    var healthText: String {
        if pct > 1 { return "超支" }
        if pct > 0.8 { return "接近上限" }
        return "正常"
    }
    var healthColor: Color {
        if pct > 1 { return .red }
        if pct > 0.8 { return .orange }
        return .green
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(L(label))
                    .font(.subheadline)
                Spacer()
                Text(L(healthText))
                    .font(.caption2)
                    .foregroundStyle(healthColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(healthColor.opacity(0.12), in: .capsule)
                Text("¥\(Int(spent.rounded())) / ¥\(Int(budget.rounded()))")
                    .font(.caption)
                    .foregroundStyle(pct > 1 ? .red : .secondary)
            }
            
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
        }
    }
}
