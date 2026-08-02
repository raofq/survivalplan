import SwiftUI
import Charts

struct SimulatorView: View {
    let profile: UserProfile
    
    @State private var newJobIncome: Double = 0
    @State private var reduceExpense: Double = 0
    @State private var oneTimeIncome: Double = 0
    @State private var findJobInMonths: Int = 3
    @State private var showResult = false
    @State private var simulatedReport: SurvivalReport?
    
    private var currentReport: SurvivalReport {
        SurvivalCalculator.calculate(from: profile)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 当前状况
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                            Text("当前状况")
                                .font(.headline)
                            Spacer()
                        }
                        HStack {
                            Text("可支撑")
                            Text("\(Int(currentReport.monthsCanSurvive)) 个月")
                                .fontWeight(.bold)
                                .foregroundStyle(.blue)
                            Spacer()
                            Text("每日 ¥\(Int(currentReport.dailyBudget))")
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                    
                    // 模拟条件
                    VStack(spacing: 16) {
                        Text("如果…会怎样？")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("找到月薪多少的工作？")
                                .font(.subheadline)
                            HStack {
                                TextField("月薪", value: $newJobIncome, format: .number)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                Text("元/月")
                                    .font(.subheadline)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("每月削减多少开支？")
                                .font(.subheadline)
                            HStack {
                                TextField("削减金额", value: $reduceExpense, format: .number)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                Text("元/月")
                                    .font(.subheadline)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("一次性收入（卖车/借款等）")
                                .font(.subheadline)
                            HStack {
                                TextField("金额", value: $oneTimeIncome, format: .number)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                Text("元")
                                    .font(.subheadline)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("预计几个月后找到工作？")
                                .font(.subheadline)
                            Picker("", selection: $findJobInMonths) {
                                Text("1个月").tag(1)
                                Text("3个月").tag(3)
                                Text("6个月").tag(6)
                                Text("12个月").tag(12)
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                    
                    // 计算按钮
                    Button(action: calculate) {
                        Text("看看变化")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.blue, in: .capsule)
                    }
                    
                    // 模拟结果
                    if let report = simulatedReport {
                        VStack(spacing: 12) {
                            Text("模拟结果")
                                .font(.headline)
                            
                            HStack(spacing: 0) {
                                StatItem(value: "\(Int(report.monthsCanSurvive))", label: "可撑(月)", color: .blue)
                                StatItem(value: "¥\(Int(report.dailyBudget))", label: "每日预算", color: .green)
                                StatItem(
                                    value: "¥\(Int(abs(report.monthlyShortfall)))",
                                    label: report.monthlyShortfall > 0 ? "月缺口" : "月盈余",
                                    color: report.monthlyShortfall > 0 ? .red : .green
                                )
                            }
                            
                            Divider()
                            
                            // 对比
                            HStack {
                                Text("改善前后")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(currentReport.monthsCanSurvive)) 个月 → \(Int(report.monthsCanSurvive)) 个月")
                                    .fontWeight(.bold)
                                    .foregroundStyle(.green)
                            }
                            .font(.subheadline)
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))

                        // 资金曲线对比
                        TimelineComparisonChart(current: currentReport, simulated: report)
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.immediately)
            .scrollDisabled(false)
            .navigationTitle("模拟器")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        hideKeyboard()
                    }
                }
            }
        }
    }
    
    private func calculate() {
        hideKeyboard()
        let changes = SimulatedChanges(
            newMonthlyIncome: newJobIncome > 0 ? newJobIncome : nil,
            reduceMonthlyExpense: reduceExpense > 0 ? reduceExpense : nil,
            oneTimeIncome: oneTimeIncome > 0 ? oneTimeIncome : nil,
            findJobInMonths: newJobIncome > 0 ? findJobInMonths : nil
        )
        simulatedReport = SurvivalCalculator.simulate(profile: profile, changes: changes)
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - 资金曲线对比图
struct TimelineComparisonChart: View {
    let current: SurvivalReport
    let simulated: SurvivalReport

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                Text("资金曲线对比")
                    .font(.headline)
                Spacer()
            }

            Chart {
                ForEach(Array(current.timeline.prefix(12))) { month in
                    LineMark(
                        x: .value("月份", month.id),
                        y: .value("积蓄", month.savingsAfter)
                    )
                    .foregroundStyle(.gray)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                }

                ForEach(Array(simulated.timeline.prefix(12))) { month in
                    LineMark(
                        x: .value("月份", month.id),
                        y: .value("积蓄", month.savingsAfter)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
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
            .frame(height: 180)

            // 图例
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(.gray)
                        .frame(width: 16, height: 2)
                    Text("改善前")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(.blue)
                        .frame(width: 16, height: 2.5)
                    Text("改善后")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }
}
