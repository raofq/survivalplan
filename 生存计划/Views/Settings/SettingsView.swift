import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - 设置页
struct SettingsView: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var expenses: [ExpenseRecord]
    @State private var showResetConfirmation = false
    @State private var showExportSuccess = false
    @State private var selectedSection: SettingsSection?
    @State private var localProfile: UserProfile

    init(profile: UserProfile) {
        self.profile = profile
        _localProfile = State(initialValue: profile)
    }

    enum SettingsSection: String, CaseIterable, Identifiable {
        case profile = "个人信息"
        case budget = "预算调整"
        case data = "数据管理"
        case about = "关于"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .profile: return "person.fill"
            case .budget: return "wallet.bifold.fill"
            case .data: return "externaldrive.fill"
            case .about: return "info.circle.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // 快速概览
                Section {
                    VStack(spacing: 4) {
                        HStack {
                            Text("可用资金")
                            Spacer()
                            Text(formatCurrency(profile.savings + profile.investments))
                                .fontWeight(.bold)
                                .foregroundStyle(.blue)
                        }
                        HStack {
                            Text("月支出")
                            Spacer()
                            Text(formatCurrency(monthlyExpenses))
                                .foregroundStyle(.red)
                        }
                        HStack {
                            Text("月收入")
                            Spacer()
                            Text(formatCurrency(monthlyIncome))
                                .foregroundStyle(.green)
                        }
                    }
                    .font(.subheadline)
                } header: {
                    Label("财务快照", systemImage: "chart.pie")
                }

                // 分区导航
                Section {
                    NavigationLink {
                        ProfileEditorView(profile: profile)
                    } label: {
                        Label("个人信息", systemImage: "person.fill")
                    }

                    NavigationLink {
                        BudgetAdjustView(profile: profile)
                    } label: {
                        Label("预算调整", systemImage: "slider.horizontal.3")
                    }

                    NavigationLink {
                        DataManageView(profile: profile, expenses: expenses)
                    } label: {
                        Label("数据管理", systemImage: "externaldrive.fill")
                    }

                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("关于", systemImage: "info.circle.fill")
                    }
                }

                // 下方危险操作
                Section {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        Label("重置所有数据", systemImage: "trash")
                    }
                } footer: {
                    Text("重置将删除所有数据，此操作不可撤销")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .alert("确认重置", isPresented: $showResetConfirmation) {
                Button("取消", role: .cancel) {}
                Button("重置", role: .destructive) { resetAllData() }
            } message: {
                Text("将删除所有用户数据和支出记录，此操作不可撤销。")
            }
        }
    }

    private var monthlyIncome: Double {
        var income = profile.partTimeIncome + profile.spouseIncome + profile.otherIncome
        if profile.hasUnemploymentBenefit {
            income += profile.unemploymentBenefit
        }
        return income
    }

    private var monthlyExpenses: Double {
        profile.mortgage + profile.carLoan + profile.propertyFee
            + profile.utilities + profile.internet + profile.phone + profile.insurance
            + profile.foodBudget + profile.transportBudget + profile.medicalBudget
            + profile.educationBudget + profile.socialBudget + profile.shoppingBudget
            + profile.creditCardDebt + profile.onlineLoanDebt + profile.privateLoanDebt
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "¥"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "¥0"
    }

    private func resetAllData() {
        // 删除所有支出记录
        for expense in expenses {
            modelContext.delete(expense)
        }
        // 删除用户档案
        modelContext.delete(profile)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - 个人信息编辑
struct ProfileEditorView: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var local: UserProfile

    init(profile: UserProfile) {
        self.profile = profile
        _local = State(initialValue: profile)
    }

    var body: some View {
        Form {
            Section("收入来源") {
                Toggle("领取失业金", isOn: $local.hasUnemploymentBenefit)
                if local.hasUnemploymentBenefit {
                    labeledField("每月金额", value: $local.unemploymentBenefit, suffix: "元/月")
                    Picker("还可领取", selection: $local.unemploymentBenefitMonths) {
                        Text("不限").tag(0)
                        ForEach([1, 2, 3, 6, 9, 12, 18, 24], id: \.self) { m in
                            Text("\(m)个月").tag(m)
                        }
                    }
                }
                Toggle("有兼职收入", isOn: $local.hasPartTimeIncome)
                if local.hasPartTimeIncome {
                    labeledField("每月", value: $local.partTimeIncome, suffix: "元/月")
                }
                labeledField("配偶收入", value: $local.spouseIncome, suffix: "元/月")
                labeledField("其他收入", value: $local.otherIncome, suffix: "元/月")
            }

            Section("积蓄") {
                labeledField("银行存款", value: $local.savings, suffix: "元")
                Toggle("有理财产品", isOn: $local.hasInvestments)
                if local.hasInvestments {
                    labeledField("可变现金额", value: $local.investments, suffix: "元")
                }
            }

            Section("家庭成员") {
                Toggle("有配偶", isOn: $local.hasSpouse)
                Stepper("子女数量: \(local.childrenCount)", value: $local.childrenCount, in: 0...10)
                Toggle("需赡养老人", isOn: $local.needsSupportElders)
            }

            Section("刚性支出（月）") {
                labeledField("房贷", value: $local.mortgage, suffix: "元/月")
                if local.mortgage > 0 {
                    Picker("剩余还款", selection: $local.mortgageRemainingMonths) {
                        Text("不限").tag(0)
                        ForEach([12, 24, 36, 60, 84, 120, 180, 240, 300, 360], id: \.self) { m in
                            Text("\(m / 12)年").tag(m)
                        }
                    }
                }
                labeledField("车贷", value: $local.carLoan, suffix: "元/月")
                if local.carLoan > 0 {
                    Picker("剩余还款", selection: $local.carLoanRemainingMonths) {
                        Text("不限").tag(0)
                        ForEach([6, 12, 18, 24, 36, 48, 60], id: \.self) { m in
                            Text("\(m)个月").tag(m)
                        }
                    }
                }
                labeledField("物业费", value: $local.propertyFee, suffix: "元/月")
                labeledField("水电煤", value: $local.utilities, suffix: "元/月")
                labeledField("网络", value: $local.internet, suffix: "元/月")
                labeledField("手机", value: $local.phone, suffix: "元/月")
                labeledField("保险", value: $local.insurance, suffix: "元/月")
            }

            Section("弹性支出（月）") {
                labeledField("食品", value: $local.foodBudget, suffix: "元/月")
                labeledField("交通", value: $local.transportBudget, suffix: "元/月")
                labeledField("医疗", value: $local.medicalBudget, suffix: "元/月")
                labeledField("教育", value: $local.educationBudget, suffix: "元/月")
                labeledField("人情", value: $local.socialBudget, suffix: "元/月")
                labeledField("购物", value: $local.shoppingBudget, suffix: "元/月")
            }

            Section("债务（月还款额）") {
                labeledField("信用卡", value: $local.creditCardDebt, suffix: "元/月")
                labeledField("网贷", value: $local.onlineLoanDebt, suffix: "元/月")
                labeledField("私人借款", value: $local.privateLoanDebt, suffix: "元/月")
            }

            Section("预期") {
                Picker("预计多久能找到工作", selection: $local.expectedMonthsBeforeJob) {
                    Text("1个月").tag(1)
                    Text("3个月").tag(3)
                    Text("6个月").tag(6)
                    Text("12个月").tag(12)
                    Text("不确定").tag(24)
                }
                .pickerStyle(.segmented)
            }
        }
        .navigationTitle("个人信息")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save(); dismiss() }
            }
        }
    }

    private func save() {
        profile.hasUnemploymentBenefit = local.hasUnemploymentBenefit
        profile.unemploymentBenefit = local.unemploymentBenefit
        profile.unemploymentBenefitMonths = local.unemploymentBenefitMonths
        profile.hasPartTimeIncome = local.hasPartTimeIncome
        profile.partTimeIncome = local.partTimeIncome
        profile.spouseIncome = local.spouseIncome
        profile.otherIncome = local.otherIncome
        profile.savings = local.savings
        profile.hasInvestments = local.hasInvestments
        profile.investments = local.investments
        profile.hasSpouse = local.hasSpouse
        profile.childrenCount = local.childrenCount
        profile.needsSupportElders = local.needsSupportElders
        profile.mortgage = local.mortgage
        profile.mortgageRemainingMonths = local.mortgageRemainingMonths
        profile.carLoan = local.carLoan
        profile.carLoanRemainingMonths = local.carLoanRemainingMonths
        profile.propertyFee = local.propertyFee
        profile.utilities = local.utilities
        profile.internet = local.internet
        profile.phone = local.phone
        profile.insurance = local.insurance
        profile.foodBudget = local.foodBudget
        profile.transportBudget = local.transportBudget
        profile.medicalBudget = local.medicalBudget
        profile.educationBudget = local.educationBudget
        profile.socialBudget = local.socialBudget
        profile.shoppingBudget = local.shoppingBudget
        profile.creditCardDebt = local.creditCardDebt
        profile.onlineLoanDebt = local.onlineLoanDebt
        profile.privateLoanDebt = local.privateLoanDebt
        profile.expectedMonthsBeforeJob = local.expectedMonthsBeforeJob
        try? modelContext.save()
    }

    private func labeledField(_ label: String, value: Binding<Double>, suffix: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("金额", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(suffix)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - 预算调整
struct BudgetAdjustView: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var localFood: Double
    @State private var localTransport: Double
    @State private var localMedical: Double
    @State private var localEducation: Double
    @State private var localSocial: Double
    @State private var localShopping: Double

    init(profile: UserProfile) {
        self.profile = profile
        _localFood = State(initialValue: profile.foodBudget)
        _localTransport = State(initialValue: profile.transportBudget)
        _localMedical = State(initialValue: profile.medicalBudget)
        _localEducation = State(initialValue: profile.educationBudget)
        _localSocial = State(initialValue: profile.socialBudget)
        _localShopping = State(initialValue: profile.shoppingBudget)
    }

    var totalBefore: Double {
        profile.foodBudget + profile.transportBudget + profile.medicalBudget
            + profile.educationBudget + profile.socialBudget + profile.shoppingBudget
    }

    var totalAfter: Double {
        localFood + localTransport + localMedical + localEducation + localSocial + localShopping
    }

    var body: some View {
        Form {
            Section("弹性支出（月）") {
                budgetRow(label: "食品", value: $localFood, icon: "cart.fill")
                budgetRow(label: "交通", value: $localTransport, icon: "bus.fill")
                budgetRow(label: "医疗", value: $localMedical, icon: "cross.fill")
                budgetRow(label: "教育", value: $localEducation, icon: "book.fill")
                budgetRow(label: "人情", value: $localSocial, icon: "heart.fill")
                budgetRow(label: "购物", value: $localShopping, icon: "bag.fill")
            }

            Section {
                HStack {
                    Text("调整前月总计")
                    Spacer()
                    Text("¥\(Int(totalBefore))")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("调整后月总计")
                    Spacer()
                    Text("¥\(Int(totalAfter))")
                        .fontWeight(.bold)
                        .foregroundStyle(totalAfter <= totalBefore ? .green : .red)
                }
                if totalAfter < totalBefore {
                    HStack {
                        Text("每月节省")
                        Spacer()
                        Text("¥\(Int(totalBefore - totalAfter))")
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                    }
                }
            } header: {
                Text("汇总")
            }

            Section {
                Button("保存调整") {
                    save()
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .fontWeight(.semibold)
            }
        }
        .navigationTitle("预算调整")
    }

    private func budgetRow(label: String, value: Binding<Double>, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(label)
            Spacer()
            TextField("金额", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text("元/月")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func save() {
        profile.foodBudget = localFood
        profile.transportBudget = localTransport
        profile.medicalBudget = localMedical
        profile.educationBudget = localEducation
        profile.socialBudget = localSocial
        profile.shoppingBudget = localShopping
        try? modelContext.save()
    }
}

// MARK: - 数据管理
struct DataManageView: View {
    let profile: UserProfile
    let expenses: [ExpenseRecord]
    @Environment(\.modelContext) private var modelContext
    @State private var showExportSuccess = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("总记录数")
                    Spacer()
                    Text("\(expenses.count) 条")
                        .foregroundStyle(.secondary)
                }

                Button {
                    exportCSV()
                } label: {
                    Label("导出 CSV", systemImage: "square.and.arrow.up")
                }
                .disabled(expenses.isEmpty)

                if showExportSuccess {
                    Text("CSV 已生成，请分享到文件或邮件")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            } header: {
                Text("支出记录")
            }

            Section {
                NavigationLink {
                    WorkoutListView()
                } label: {
                    Label("运动打卡", systemImage: "figure.walk")
                }

                NavigationLink {
                    StudyListView()
                } label: {
                    Label("学习记录", systemImage: "book.fill")
                }
            } header: {
                Text("模块管理")
            } footer: {
                Text("新模块正在开发中，欢迎反馈建议")
            }
        }
        .navigationTitle("数据管理")
    }

    private func exportCSV() {
        var csv = "日期,类别,金额,备注,是否刚性\n"
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"

        for e in expenses {
            csv += "\(f.string(from: e.date)),\(e.category),\(e.amount),\(e.note),\(e.isEssential)\n"
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("survival_plan_export.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)

        // Save to clipboard and show success
        UIPasteboard.general.string = csv
        showExportSuccess = true
    }
}

// MARK: - 运动打卡列表（占位）
struct WorkoutListView: View {
    var body: some View {
        List {
            Text("运动打卡功能开发中")
                .foregroundStyle(.secondary)
        }
        .navigationTitle("运动打卡")
    }
}

// MARK: - 学习记录列表（占位）
struct StudyListView: View {
    var body: some View {
        List {
            Text("学习记录功能开发中")
                .foregroundStyle(.secondary)
        }
        .navigationTitle("学习记录")
    }
}

// MARK: - 关于
struct AboutView: View {
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("应用名称")
                    Spacer()
                    Text("生存计划")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("技术栈")
                    Spacer()
                    Text("SwiftUI + SwiftData")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label("应用信息", systemImage: "apps.ipad")
            }

            Section {
                Text("「生存计划」帮助你在职业空窗期管理财务，知道钱在哪，日子就能过下去。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } header: {
                Label("关于", systemImage: "text.alignleft")
            }

            Section {
                Label("数据仅存储在你的设备上，不上传任何服务器", systemImage: "lock.shield.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } header: {
                Label("隐私", systemImage: "hand.raised.fill")
            } footer: {
                Text("所有财务数据通过 SwiftData 本地存储，App 不联网、不收集任何数据。")
            }

            Section {
                Link(destination: URL(string: "https://github.com/raofq/survivalplan")!) {
                    Label("GitHub 仓库", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            } header: {
                Label("开源", systemImage: "globe")
            }
        }
        .navigationTitle("关于")
    }
}
