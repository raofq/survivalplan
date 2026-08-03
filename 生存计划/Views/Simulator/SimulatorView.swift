import SwiftUI
import Charts

struct SimulatorView: View {
    let profile: UserProfile
    
    @State private var newJobIncome: Double = 0
    @State private var probationIncome: Double = 0
    @State private var probationMonths: Int = 0
    @State private var foodCut: Double = 0
    @State private var transportCut: Double = 0
    @State private var shoppingCut: Double = 0
    @State private var socialCut: Double = 0
    @State private var oneTimeIncome: Double = 0
    @State private var findJobInMonths: Int = 3
    @State private var showResult = false
    @State private var simulatedReport: SurvivalReport?
    @State private var targetMonths: Int = 12
    @State private var activeScenario: Scenario?
    @State private var stopShoppingOn = false
    @State private var stopEducationOn = false
    @State private var carSaleOn = false
    @State private var carSaleAmount: Double = 0
    @State private var borrowOn = false
    @State private var borrowAmount: Double = 0
    @State private var borrowRepayment: Double = 0

    enum Scenario: String, Identifiable {
        case sellCar = "卖车"
        case borrow = "借款"
        var id: String { rawValue }
    }
    
    private var currentReport: SurvivalReport {
        SurvivalCalculator.calculate(from: profile)
    }

    private var targetResult: SurvivalTarget? {
        // 联动：模拟过就用模拟后的收支，没模拟过用原始数据
        SurvivalCalculator.projectTarget(report: simulatedReport ?? currentReport, targetMonths: targetMonths)
    }
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
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
                            Text("试用期（选填）")
                                .font(.subheadline)
                            HStack {
                                TextField("试用期月薪", value: $probationIncome, format: .number)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                Text("元/月")
                                    .font(.subheadline)
                            }
                            Picker("", selection: $probationMonths) {
                                Text("无试用期").tag(0)
                                Text("1个月").tag(1)
                                Text("2个月").tag(2)
                                Text("3个月").tag(3)
                                Text("6个月").tag(6)
                            }
                            .pickerStyle(.segmented)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("削减开支（按分类）")
                                .font(.subheadline)
                            HStack(spacing: 8) {
                                cutField("食品", value: $foodCut)
                                cutField("交通", value: $transportCut)
                                cutField("购物", value: $shoppingCut)
                                cutField("人情", value: $socialCut)
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

                    // 场景预设
                    VStack(spacing: 14) {
                        HStack {
                            Image(systemName: "square.grid.2x2.fill")
                            Text("场景模拟")
                                .font(.headline)
                            Spacer()
                        }

                        HStack(spacing: 8) {
                            Button {
                                if carSaleOn && carSaleAmount > 0 {
                                    carSaleOn = false
                                } else {
                                    activeScenario = .sellCar
                                }
                            } label: {
                                VStack(spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text("🚗 卖车")
                                        if carSaleOn { Image(systemName: "checkmark.circle.fill").font(.caption2) }
                                    }
                                    if carSaleOn {
                                        Text("¥\(Int(carSaleAmount))")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(carSaleOn ? .orange : .gray)

                            Button {
                                stopShoppingOn.toggle()
                                calculate()
                                withAnimation { proxy.scrollTo("simResult", anchor: .top) }
                            } label: {
                                VStack(spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text("✂️ 停购物")
                                        if stopShoppingOn { Image(systemName: "checkmark.circle.fill").font(.caption2) }
                                    }
                                    if stopShoppingOn {
                                        Text("已停")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(stopShoppingOn ? .orange : .gray)

                            Button {
                                stopEducationOn.toggle()
                                calculate()
                                withAnimation { proxy.scrollTo("simResult", anchor: .top) }
                            } label: {
                                VStack(spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text("🎒 停兴趣班")
                                        if stopEducationOn { Image(systemName: "checkmark.circle.fill").font(.caption2) }
                                    }
                                    if stopEducationOn {
                                        Text("已停")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(stopEducationOn ? .orange : .gray)

                            Button {
                                if borrowOn && borrowAmount > 0 {
                                    borrowOn = false
                                } else {
                                    activeScenario = .borrow
                                }
                            } label: {
                                VStack(spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text("💰 借款")
                                        if borrowOn { Image(systemName: "checkmark.circle.fill").font(.caption2) }
                                    }
                                    if borrowOn {
                                        Text("¥\(Int(borrowAmount))")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(borrowOn ? .orange : .gray)
                        }
                        .font(.caption)

                        // 已启用场景汇总
                        if !enabledScenarios.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "info.circle")
                                Text("已启用：\(enabledScenarios.joined(separator: "、"))")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                Spacer()
                            }
                        }

                        Text("点击场景立即模拟，可叠加「找到工作」一起算；再点一次可停用")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                    .sheet(item: $activeScenario) { scenario in
                        ScenarioSheet(scenario: scenario, initialAmount: scenario == .sellCar ? carSaleAmount : borrowAmount, initialRepayment: borrowRepayment) { params in
                            applyScenario(scenario, params: params, proxy: proxy)
                        }
                    }

                    // 目标反推
                    VStack(spacing: 14) {
                        HStack {
                            Image(systemName: "target")
                            Text("目标反推")
                                .font(.headline)
                            Spacer()
                        }

                        Text("目标：撑过多少个月？")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Picker("", selection: $targetMonths) {
                            Text("6个月").tag(6)
                            Text("12个月").tag(12)
                            Text("18个月").tag(18)
                            Text("24个月").tag(24)
                        }
                        .pickerStyle(.segmented)

                        if let target = targetResult {
                            Divider()

                            HStack {
                                Text("每月最多可花")
                                Spacer()
                                Text("¥\(Int(target.monthlySpendable))")
                                    .fontWeight(.bold)
                                    .foregroundStyle(.blue)
                            }
                            .font(.subheadline)

                            if target.isAchievable {
                                Label("当前资金可撑 \(target.targetMonths) 个月，每月还可结余 ¥\(Int(-target.cutNeeded))", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            } else {
                                VStack(alignment: .leading, spacing: 6) {
                                    Label("还差 ¥\(Int(target.cutNeeded)) / 月才能撑 \(target.targetMonths) 个月", systemImage: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                    Label("建议：每月削减 ¥\(Int(target.cutNeeded))，或找到月薪至少 ¥\(Int(target.cutNeeded + currentReport.totalMonthlyIncome)) 的工作", systemImage: "lightbulb.fill")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
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

                            // 前后指标对比表
                            comparisonRow(
                                label: "可撑月数",
                                before: "\(Int(currentReport.monthsCanSurvive)) 个月",
                                after: "\(Int(report.monthsCanSurvive)) 个月",
                                improved: report.monthsCanSurvive >= currentReport.monthsCanSurvive
                            )
                            comparisonRow(
                                label: "资金耗尽日",
                                before: formatDate(currentReport.exhaustionDate),
                                after: formatDate(report.exhaustionDate),
                                improved: report.exhaustionDate >= currentReport.exhaustionDate
                            )
                            comparisonRow(
                                label: "每日预算",
                                before: "¥\(Int(currentReport.dailyBudget))",
                                after: "¥\(Int(report.dailyBudget))",
                                improved: true
                            )
                            comparisonRow(
                                label: currentReport.monthlyShortfall > 0 ? "月缺口" : "月盈余",
                                before: "¥\(Int(abs(currentReport.monthlyShortfall)))",
                                after: "¥\(Int(abs(report.monthlyShortfall)))",
                                improved: abs(report.monthlyShortfall) <= abs(currentReport.monthlyShortfall)
                            )

                            if report.monthsCanSurvive > currentReport.monthsCanSurvive {
                                Label("改善后多撑 \(Int(report.monthsCanSurvive - currentReport.monthsCanSurvive)) 个月", systemImage: "arrow.up.right.circle.fill")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.green)
                            } else if report.monthsCanSurvive < currentReport.monthsCanSurvive {
                                Label("改善后少撑 \(Int(currentReport.monthsCanSurvive - report.monthsCanSurvive)) 个月，请调整方案", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                        .id("simResult")

                        // 资金曲线对比
                        TimelineComparisonChart(current: currentReport, simulated: report)
                    }
                }
                .padding()
                }
                .scrollDismissesKeyboard(.immediately)
                .scrollDisabled(false)
            }
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
        var categoryCuts: [String: Double] = [:]
        if foodCut > 0 { categoryCuts["食品"] = foodCut }
        if transportCut > 0 { categoryCuts["交通"] = transportCut }
        if shoppingCut > 0 { categoryCuts["购物"] = shoppingCut }
        if socialCut > 0 { categoryCuts["人情"] = socialCut }

        var changes = SimulatedChanges(
            newMonthlyIncome: newJobIncome > 0 ? newJobIncome : nil,
            findJobInMonths: newJobIncome > 0 ? findJobInMonths : nil,
            probationIncome: probationMonths > 0 && probationIncome > 0 ? probationIncome : nil,
            probationMonths: probationMonths,
            categoryCuts: categoryCuts
        )
        // 合并已启用的场景
        mergeScenarioChanges(into: &changes)
        simulatedReport = SurvivalCalculator.simulate(profile: profile, changes: changes)
    }

    /// 已启用场景的汇总文案
    private var enabledScenarios: [String] {
        var list: [String] = []
        if stopShoppingOn { list.append("停购物") }
        if stopEducationOn { list.append("停兴趣班") }
        if carSaleOn && carSaleAmount > 0 { list.append("卖车 ¥\(Int(carSaleAmount))") }
        if borrowOn && borrowAmount > 0 { list.append("借款 ¥\(Int(borrowAmount))") }
        return list
    }

    /// 把已启用的场景合并进模拟变更
    private func mergeScenarioChanges(into changes: inout SimulatedChanges) {
        if stopShoppingOn { changes.zeroOutShopping = true }
        if stopEducationOn { changes.zeroOutEducation = true }
        if carSaleOn && carSaleAmount > 0 {
            changes.removeCarLoan = true
            changes.carSaleAmount = carSaleAmount
        }
        if borrowOn && borrowAmount > 0 {
            changes.oneTimeIncome = borrowAmount
            changes.extraMonthlyRepayment = borrowRepayment
        }
    }

    private func applyScenario(_ scenario: Scenario, params: [String: Double], proxy: ScrollViewProxy) {
        hideKeyboard()
        switch scenario {
        case .sellCar:
            carSaleAmount = params["amount"] ?? 0
            carSaleOn = carSaleAmount > 0
        case .borrow:
            borrowAmount = params["amount"] ?? 0
            borrowRepayment = params["repayment"] ?? 0
            borrowOn = borrowAmount > 0
        }
        calculate()
        // sheet 关闭后滚动到结果
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation { proxy.scrollTo("simResult", anchor: .top) }
        }
    }

    private func cutField(_ label: String, value: Binding<Double>) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            TextField("0", value: value, format: .number)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 64)
                .multilineTextAlignment(.center)
        }
    }

    private func comparisonRow(label: String, before: String, after: String, improved: Bool) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Spacer()
            Text(before)
                .font(.caption)
                .foregroundStyle(.gray)
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(after)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(improved ? .green : .red)
        }
    }

    private func formatDate(_ date: Date) -> String {
        date.formatted(.dateTime.year().month().day())
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
                        y: .value("积蓄", month.savingsAfter),
                        series: .value("系列", "改善前")
                    )
                    .foregroundStyle(.gray)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                }

                ForEach(Array(simulated.timeline.prefix(12))) { month in
                    LineMark(
                        x: .value("月份", month.id),
                        y: .value("积蓄", month.savingsAfter),
                        series: .value("系列", "改善后")
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                }

                // 耗尽点标注
                if let currentExhaust = exhaustionMonth(current) {
                    RuleMark(x: .value("耗尽月", currentExhaust))
                        .foregroundStyle(.gray.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
                if let simulatedExhaust = exhaustionMonth(simulated) {
                    RuleMark(x: .value("耗尽月", simulatedExhaust))
                        .foregroundStyle(.blue.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
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

    /// 资金耗尽的月份（第一个 savingsAfter <= 0 的月份）
    private func exhaustionMonth(_ report: SurvivalReport) -> Int? {
        report.timeline.first { $0.savingsAfter <= 0 }?.id
    }
}

// MARK: - 场景参数输入
struct ScenarioSheet: View {
    let scenario: SimulatorView.Scenario
    let initialAmount: Double
    let initialRepayment: Double
    let onApply: ([String: Double]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var repayment = ""

    var body: some View {
        NavigationStack {
            Form {
                switch scenario {
                case .sellCar:
                    Section("卖车收入") {
                        TextField("卖车金额（元）", text: $amount)
                            .keyboardType(.decimalPad)
                        Text("模拟效果：车贷消失 + 一次性卖车收入")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                case .borrow:
                    Section("借款") {
                        TextField("借款总额（元）", text: $amount)
                            .keyboardType(.decimalPad)
                        TextField("每月还款（元）", text: $repayment)
                            .keyboardType(.decimalPad)
                        Text("模拟效果：一次性入账 + 每月新增还款支出")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(scenario.rawValue)
            .onAppear {
                if amount.isEmpty && initialAmount > 0 { amount = String(Int(initialAmount)) }
                if repayment.isEmpty && initialRepayment > 0 { repayment = String(Int(initialRepayment)) }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("模拟") {
                        var params: [String: Double] = [:]
                        if let a = Double(amount) { params["amount"] = a }
                        if let r = Double(repayment) { params["repayment"] = r }
                        onApply(params)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(280)])
    }
}
