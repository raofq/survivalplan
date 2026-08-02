import SwiftUI
import Charts
import SwiftData

struct BudgetView: View {
    let profile: UserProfile
    @Query(sort: \ExpenseRecord.date, order: .reverse) private var expenses: [ExpenseRecord]
    
    private var report: SurvivalReport {
        SurvivalCalculator.calculate(from: profile)
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
            ScrollView {
                VStack(spacing: 16) {
                    // 本周预算
                    VStack(spacing: 8) {
                        Text("本周预算")
                            .font(.headline)
                        Text("¥\(Int(report.weeklyBudget))")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(.blue)
                        Text("每日 ¥\(Int(report.dailyBudget))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                    
                    // 分类预算进度
                    VStack(alignment: .leading, spacing: 12) {
                        Text("分类预算")
                            .font(.headline)
                        
                        BudgetProgressRow(label: "食品", budget: report.foodBudget * 30, spent: categoryTotal("食品"))
                        BudgetProgressRow(label: "交通", budget: report.transportBudget * 30, spent: categoryTotal("交通"))
                        BudgetProgressRow(label: "医疗", budget: report.medicalBudget * 30, spent: categoryTotal("医疗"))
                        BudgetProgressRow(label: "人情", budget: report.socialBudget * 30, spent: categoryTotal("人情"))
                        BudgetProgressRow(label: "购物", budget: report.shoppingBudget * 30, spent: categoryTotal("购物"))
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                    
                    // 支出趋势（最近7天）
                    VStack(alignment: .leading, spacing: 12) {
                        Text("最近7天支出")
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
}

struct BudgetProgressRow: View {
    let label: String
    let budget: Double
    let spent: Double
    
    var pct: Double { budget > 0 ? spent / budget : 0 }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text("¥\(Int(spent)) / ¥\(Int(budget))")
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
