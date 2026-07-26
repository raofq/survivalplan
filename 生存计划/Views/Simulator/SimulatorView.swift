import SwiftUI

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
                                StatItem(value: "¥\(Int(report.monthlyShortfall))", label: "月缺口", color: .red)
                            }
                            
                            Divider()
                            
                            // 对比
                            HStack {
                                Text("改善前")
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
                    }
                }
                .padding()
            }
            .navigationTitle("模拟器")
        }
    }
    
    private func calculate() {
        let changes = SimulatedChanges(
            newMonthlyIncome: newJobIncome > 0 ? newJobIncome : nil,
            reduceMonthlyExpense: reduceExpense > 0 ? reduceExpense : nil,
            oneTimeIncome: oneTimeIncome > 0 ? oneTimeIncome : nil,
            findJobInMonths: newJobIncome > 0 ? findJobInMonths : nil
        )
        simulatedReport = SurvivalCalculator.simulate(profile: profile, changes: changes)
    }
}
