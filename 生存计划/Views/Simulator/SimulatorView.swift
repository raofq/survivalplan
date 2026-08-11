import SwiftUI
import Charts

struct SimulatorView: View {
    let profile: UserProfile
    
    @State private var newJobIncome: Double = 0
    @State private var newJobIncomeText: String = ""
    @State private var probationIncome: Double = 0
    @State private var probationIncomeText: String = ""
    @State private var probationMonths: Int = 0
    @State private var foodCut: Double = 0
    @State private var transportCut: Double = 0
    @State private var shoppingCut: Double = 0
    @State private var socialCut: Double = 0
    @State private var oneTimeIncome: Double = 0
    @State private var findJobInMonths: Int = 3
    @State private var showResult = false
    @State private var simulatedReport: SurvivalReport?
    @State private var reportCache: SurvivalReport?
    @State private var targetMonths = 12
    @State private var showProLock = false
    @State private var proLockFeature = "场景模拟"
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
        // 缓存计算结果：避免每次按键 body 重算触发全量生存计算（卡顿主因）
        reportCache ?? SurvivalCalculator.calculate(from: profile)
    }

    private var targetResult: SurvivalTarget? {
        // 联动：模拟过就用模拟后的收支，没模拟过用原始数据
        SurvivalCalculator.projectTarget(report: simulatedReport ?? currentReport, targetMonths: targetMonths, baseline: profile.familyBaseLivingCost)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if reportCache != nil {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                    // 当前状况
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                            Text(L("当前状况"))
                                .font(.headline)
                            Spacer()
                        }
                        HStack {
                            Text(L("可支撑"))
                            Text(Lf("%lld 个月", Int(currentReport.monthsCanSurvive)))
                                .fontWeight(.bold)
                                .foregroundStyle(.blue)
                            Spacer()
                            Text("每日 ¥\(Int(currentReport.dailyBudget.rounded()))")
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                    
                    // 模拟条件
                    VStack(spacing: 16) {
                        Text(L("如果…会怎样？"))
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("找到月薪多少的工作？"))
                                .font(.subheadline)
                            HStack {
                                SafeMoneyField(text: $newJobIncomeText, placeholder: L("月薪"))
                                    .onChange(of: newJobIncomeText) { _, new in
                                        newJobIncome = Double(new) ?? 0
                                    }
                                Text(L("元/月"))
                                    .font(.subheadline)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Text(L("试用期（选填）"))
                                    .font(.subheadline)
                                if !ProFeatures.simulatorTrialParams {
                                    ProLock.badge()
                                }
                            }
                            HStack {
                                SafeMoneyField(text: $probationIncomeText, placeholder: L("试用期月薪"))
                                    .disabled(!ProFeatures.simulatorTrialParams)
                                    .opacity(ProFeatures.simulatorTrialParams ? 1 : 0.4)
                                    .onChange(of: probationIncomeText) { _, new in
                                        probationIncome = Double(new) ?? 0
                                    }
                                Text(L("元/月"))
                                    .font(.subheadline)
                            }
                            Picker("", selection: $probationMonths) {
                                Text(L("无试用期")).tag(0)
                                Text(L("1个月")).tag(1)
                                Text(L("2个月")).tag(2)
                                Text(L("3个月")).tag(3)
                                Text(L("6个月")).tag(6)
                            }
                            .pickerStyle(.segmented)
                            .disabled(!ProFeatures.simulatorTrialParams)
                            .opacity(ProFeatures.simulatorTrialParams ? 1 : 0.4)
                            if !ProFeatures.simulatorTrialParams {
                                Button {
                                    proLockFeature = "试用期参数"
                                    showProLock = true
                                } label: {
                                    Label(L("试用期参数是 Pro 功能"), systemImage: "lock.fill")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("削减开支（按百分比）"))
                                .font(.subheadline)
                            HStack(spacing: 8) {
                                cutField("食品", value: $foodCut)
                                cutField("交通", value: $transportCut)
                                cutField("购物", value: $shoppingCut)
                                cutField("人情", value: $socialCut)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("预计几个月后找到工作？"))
                                .font(.subheadline)
                            Picker("", selection: $findJobInMonths) {
                                Text(L("1个月")).tag(1)
                                Text(L("3个月")).tag(3)
                                Text(L("6个月")).tag(6)
                                Text(L("12个月")).tag(12)
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
                            Text(L("场景模拟"))
                                .font(.headline)
                            if !ProFeatures.simulatorScenarios {
                                ProLock.badge()
                            }
                            Spacer()
                        }

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
                            scenarioButton(
                                emoji: "🚗", title: "卖车",
                                isOn: carSaleOn,
                                statusText: carSaleOn ? "\(money(carSaleAmount))" : "未启用"
                            ) {
                                proGate {
                                    if carSaleOn && carSaleAmount > 0 {
                                        carSaleOn = false
                                    } else {
                                        activeScenario = .sellCar
                                    }
                                }
                            }

                            scenarioButton(
                                emoji: "✂️", title: "停购物",
                                isOn: stopShoppingOn,
                                statusText: stopShoppingOn ? "已停" : "未启用"
                            ) {
                                proGate {
                                    stopShoppingOn.toggle()
                                    calculate()
                                    withAnimation { proxy.scrollTo("simResult", anchor: .top) }
                                }
                            }

                            scenarioButton(
                                emoji: "🎒", title: "停补课",
                                isOn: stopEducationOn,
                                statusText: stopEducationOn ? "已停" : "未启用"
                            ) {
                                proGate {
                                    stopEducationOn.toggle()
                                    calculate()
                                    withAnimation { proxy.scrollTo("simResult", anchor: .top) }
                                }
                            }

                            scenarioButton(
                                emoji: "💰", title: "借款",
                                isOn: borrowOn,
                                statusText: borrowOn ? "\(money(borrowAmount))" : "未启用"
                            ) {
                                proGate {
                                    if borrowOn && borrowAmount > 0 {
                                        borrowOn = false
                                    } else {
                                        activeScenario = .borrow
                                    }
                                }
                            }
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

                        Text(L("点击场景立即模拟，可叠加「找到工作」一起算；再点一次可停用"))
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
                            Text(L("目标反推"))
                                .font(.headline)
                            Spacer()
                        }

                        Text(L("目标：撑过多少个月？"))
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Picker("", selection: $targetMonths) {
                            Text(L("6个月")).tag(6)
                            Text(L("12个月")).tag(12)
                            Text(L("18个月")).tag(18)
                            Text(L("24个月")).tag(24)
                        }
                        .pickerStyle(.segmented)

                        if let target = targetResult {
                            Divider()

                            // 计算过程：积蓄 ÷ 目标月数
                            HStack {
                                Text(Lf("积蓄 %@ ÷ %lld 个月", money(currentReport.totalSavings), target.targetMonths))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("= ¥\(Int(target.monthlySpendable.rounded()))/月")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Text(L("每月最多可花"))
                                    .font(.subheadline)
                                Spacer()
                                Text("\(money(target.monthlySpendable))")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.blue)
                            }

                            // 低于生存底线提醒
                            if target.belowBaseline {
                                Label("低于家庭生存底线（¥\(Int(profile.familyBaseLivingCost.rounded()))/月），光靠削减撑不过去，必须找到收入", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }

                            HStack {
                                Text(L("当前每月支出"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(money(currentReport.totalMonthlyExpenses))")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }

                            if target.isAchievable {
                                Label(Lf("每月支出在额度内，按现状能撑满 %lld 个月，每月还能剩 %@", target.targetMonths, money(-target.cutNeeded)), systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            } else {
                                VStack(alignment: .leading, spacing: 6) {
                                    Label(Lf("每月支出比额度多 %@，按现状撑不到 %lld 个月", money(target.cutNeeded), target.targetMonths), systemImage: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                    Label("方案一：每月削减开支 ¥\(Int(target.cutNeeded))", systemImage: "scissors")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                    if ProFeatures.targetJobAdvice {
                                        Label("方案二：找月薪 ≥ ¥\(Int(target.cutNeeded + currentReport.totalMonthlyIncome)) 的工作（当前收入 ¥\(Int(currentReport.totalMonthlyIncome)) + 缺口 ¥\(Int(target.cutNeeded))）", systemImage: "briefcase.fill")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    } else {
                                        HStack(spacing: 4) {
                                            Label(L("方案二：找工作的具体建议"), systemImage: "lock.fill")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                            Spacer()
                                            ProLock.badge()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                    
                    // 计算按钮
                    Button(action: calculate) {
                        Text(L("看看变化"))
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.blue, in: .capsule)
                    }
                    
                    // 模拟结果（独立 View：输入变化不重绘此区，消除卡顿）
                    if let report = simulatedReport {
                        SimulationResultCard(current: currentReport, simulated: report).equatable()
                    }
                }
                .padding()
                }
                .scrollDismissesKeyboard(.immediately)
                .scrollDisabled(false)
            }

                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .listStyle(.grouped)
        .scrollIndicators(.hidden)
        .navigationTitle("模拟器")
        .hideKeyboardOnTap()
            .onAppear {
                // 每次进入都重算基准报告（后台算，首进不冻结 UI）：设置改动后模拟器基准实时联动
                let d = UserProfileDraft(profile: profile)   // 主线程取值快照——后台不碰 @Model
                Task.detached(priority: .userInitiated) {
                    let r = SurvivalCalculator.calculate(from: d)
                    await MainActor.run { reportCache = r }
                }
                if newJobIncomeText.isEmpty && newJobIncome > 0 { newJobIncomeText = String(Int(newJobIncome)) }
                if probationIncomeText.isEmpty && probationIncome > 0 { probationIncomeText = String(Int(probationIncome)) }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L("完成")) {
                        hideKeyboard()
                    }
                }
            }
            .alert("Pro 专属功能", isPresented: $showProLock) {
                Button(L("去解锁")) {
                    StoreManager.shared.showPaywall = true
                }
                Button("好", role: .cancel) {}
            } message: {
                Text(ProLock.message(for: proLockFeature))
            }
        }
    }

    /// Pro 功能门：未解锁时弹提示，不解锁不执行
    private func proGate(_ action: @escaping () -> Void) {
        if ProFeatures.simulatorScenarios {
            action()
        } else {
            showProLock = true
        }
    }
    private func calculate() {
        hideKeyboard()
        // 百分比 → 实际削减金额（基于对应分类的月预算）
        let base = currentReport
        var categoryCuts: [String: Double] = [:]
        if foodCut > 0 { categoryCuts["食品"] = base.foodBudget * 30 * foodCut / 100 }
        if transportCut > 0 { categoryCuts["交通"] = base.transportBudget * 30 * transportCut / 100 }
        if shoppingCut > 0 { categoryCuts["购物"] = base.shoppingBudget * 30 * shoppingCut / 100 }
        if socialCut > 0 { categoryCuts["人情"] = base.socialBudget * 30 * socialCut / 100 }

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
        if stopEducationOn { list.append("停补课") }
        if carSaleOn && carSaleAmount > 0 { list.append("卖车 ¥\(Int(carSaleAmount.rounded()))") }
        if borrowOn && borrowAmount > 0 { list.append("借款 ¥\(Int(borrowAmount.rounded()))") }
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

    /// 场景按钮：统一结构（图标+名称+勾选占位+状态行），选中与否只差底色和勾选
    private func scenarioButton(emoji: String, title: String, isOn: Bool, statusText: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Text(emoji)
                    Text(L(title))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .opacity(isOn ? 1 : 0)   // 占位保持宽度，避免跳动
                }
                Text(L(statusText))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(isOn ? .orange : .gray)
    }

    private func cutField(_ label: String, value: Binding<Double>) -> some View {
        VStack(spacing: 2) {
            Text(L(label))
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 2) {
                TextField("0", value: value, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                Text("%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    private func comparisonRow(label: String, before: String, after: String, improved: Bool) -> some View {
        HStack(spacing: 8) {
            Text(L(label))
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
                Text(L("资金曲线对比"))
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
                    Text(L("改善前"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(.blue)
                        .frame(width: 16, height: 2.5)
                    Text(L("改善后"))
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
                        Text(L("模拟效果：车贷消失 + 一次性卖车收入"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                case .borrow:
                    Section("借款") {
                        TextField("借款总额（元）", text: $amount)
                            .keyboardType(.decimalPad)
                        TextField("每月还款（元）", text: $repayment)
                            .keyboardType(.decimalPad)
                        Text(L("模拟效果：一次性入账 + 每月新增还款支出"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.grouped)
        .scrollIndicators(.hidden)
        .navigationTitle(scenario.rawValue)
            .onAppear {
                if amount.isEmpty && initialAmount > 0 { amount = String(Int(initialAmount)) }
                if repayment.isEmpty && initialRepayment > 0 { repayment = String(Int(initialRepayment)) }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("取消")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("模拟")) {
                        AnalyticsService.shared.track("action_simulate")
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

// MARK: - 模拟结果卡（独立 View：输入变化时避免整区重绘，消除输入卡顿）
struct SimulationResultCard: View, Equatable {
    let current: SurvivalReport
    let simulated: SurvivalReport

    var body: some View {
        VStack(spacing: 12) {
            Text(L("模拟结果"))
                .font(.headline)

            comparisonRow(
                label: "可撑月数",
                before: Lf("%lld 个月", Int(current.monthsCanSurvive)),
                after: Lf("%lld 个月", Int(simulated.monthsCanSurvive)),
                improved: simulated.monthsCanSurvive >= current.monthsCanSurvive
            )
            comparisonRow(
                label: "资金耗尽日",
                before: formatDate(current.exhaustionDate),
                after: formatDate(simulated.exhaustionDate),
                improved: simulated.exhaustionDate >= current.exhaustionDate
            )
            comparisonRow(
                label: "每日预算",
                before: "\(money(current.dailyBudget))",
                after: "\(money(simulated.dailyBudget))",
                improved: true
            )
            comparisonRow(
                label: current.monthlyShortfall > 0 ? "月缺口" : "月盈余",
                before: "\(money(abs(current.monthlyShortfall)))",
                after: "\(money(abs(simulated.monthlyShortfall)))",
                improved: abs(simulated.monthlyShortfall) <= abs(current.monthlyShortfall)
            )

            if simulated.monthsCanSurvive > current.monthsCanSurvive {
                Label(Lf("改善后多撑 %lld 个月", Int(simulated.monthsCanSurvive - current.monthsCanSurvive)), systemImage: "arrow.up.right.circle.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
            } else if simulated.monthsCanSurvive < current.monthsCanSurvive {
                Label(Lf("改善后少撑 %lld 个月，请调整方案", Int(current.monthsCanSurvive - simulated.monthsCanSurvive)), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .id("simResult")

        // 资金曲线对比
        TimelineComparisonChart(current: current, simulated: simulated)
    }

    private func comparisonRow(label: String, before: String, after: String, improved: Bool) -> some View {
        HStack(spacing: 8) {
            Text(L(label))
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
}
