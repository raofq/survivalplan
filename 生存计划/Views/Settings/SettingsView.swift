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
    @State private var showProfileEditor = false
    @State private var showBudgetAdjust = false
    @State private var showDataManage = false
    @State private var showAbout = false
    @State private var showExportSuccess = false
    @State private var selectedSection: SettingsSection?
    @State private var localProfile: UserProfile
    @State private var languageSelection: String = LanguageManager.current

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
        // 注意：不建内层 NavigationStack——iOS 17.4 嵌套栈内层 NavigationLink push 失效（真机）
        // 直接使用外层（Dashboard）导航栈
        List {
                // 语言设置
                Section {
                    Picker(selection: $languageSelection, label: Label(L("语言 / Language"), systemImage: "globe")) {
                        Text(L("跟随系统 / System")).tag("system")
                        Text(L("简体中文")).tag("zh-Hans")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.menu)
                    .onChange(of: languageSelection) { _, newValue in
                        LanguageManager.set(newValue)
                        NotificationCenter.default.post(name: .languageDidChange, object: nil)
                    }
                } header: {
                    Text(L("语言 / Language"))
                }
                // 快速概览
                Section {
                    VStack(spacing: 4) {
                        HStack {
                            Text(L("可用资金"))
                            Spacer()
                            Text(formatCurrency(profile.savings + profile.investments))
                                .fontWeight(.bold)
                                .foregroundStyle(.blue)
                        }
                        HStack {
                            Text(L("月支出"))
                            Spacer()
                            Text(formatCurrency(monthlyExpenses))
                                .foregroundStyle(.red)
                        }
                        HStack {
                            Text(L("月收入"))
                            Spacer()
                            Text(formatCurrency(monthlyIncome))
                                .foregroundStyle(.green)
                        }
                    }
                    .font(.subheadline)
                } header: {
                    Label(L("财务快照"), systemImage: "chart.pie")
                }

                // 分区导航
                Section {
                    // Pro 升级入口
                    Button {
                        StoreManager.shared.showPaywall = true
                    } label: {
                        HStack {
                            Label(L("升级 Pro"), systemImage: ProFeatures.isPro ? "crown.fill" : "crown")
                                .foregroundStyle(.orange)
                            Spacer()
                            if ProFeatures.isPro {
                                Text(L("已解锁"))
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            } else {
                                ProLock.badge()
                            }
                        }
                    }

                    Button { showProfileEditor = true } label: {
                        Label(L("个人信息"), systemImage: "person.fill")
                    }
                    .buttonStyle(.plain)

                    Button { showBudgetAdjust = true } label: {
                        Label(L("预算调整"), systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(.plain)

                    Button { showDataManage = true } label: {
                        Label(L("数据管理"), systemImage: "externaldrive.fill")
                    }
                    .buttonStyle(.plain)

                    Button { showAbout = true } label: {
                        Label(L("关于"), systemImage: "info.circle.fill")
                    }
                    .buttonStyle(.plain)
                }

                // 下方危险操作
                Section {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        Label(L("重置所有数据"), systemImage: "trash")
                    }
                } footer: {
                    Text(L("重置将删除所有数据，此操作不可撤销"))
                }
            }
            .sheet(isPresented: $showProfileEditor) { NavigationStack { ProfileEditorView(profile: profile) } }
            .sheet(isPresented: $showBudgetAdjust) { NavigationStack { BudgetAdjustView(profile: profile) } }
            .sheet(isPresented: $showDataManage) { NavigationStack { DataManageView(profile: profile, expenses: expenses) } }
            .sheet(isPresented: $showAbout) { NavigationStack { AboutView() } }
            .listStyle(.insetGrouped)
        .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("完成")) { dismiss() }
                }
            }
            .alert("确认重置", isPresented: $showResetConfirmation) {
                Button("取消", role: .cancel) {}
                Button("重置", role: .destructive) { resetAllData() }
            } message: {
                Text(L("将删除所有用户数据和支出记录，此操作不可撤销。"))
            }
    }

    private var monthlyIncome: Double {
        var income = profile.spouseIncome + profile.otherIncome
        if profile.hasPartTimeIncome {
            income += profile.partTimeIncome
        }
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
        return money(value)

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
    @State private var local: UserProfileDraft

    init(profile: UserProfile) {
        self.profile = profile
        _local = State(initialValue: UserProfileDraft(profile: profile))
    }

    var body: some View {
        Form {
            // 失业情况（时间锚点）
            Section {
                DatePicker("失业日期", selection: Binding(
                    get: { local.unemploymentDate ?? Date() },
                    set: { local.unemploymentDate = $0 }
                ), displayedComponents: .date)
                if local.unemploymentDate != nil {
                    Button("清除失业日期", role: .destructive) {
                        local.unemploymentDate = nil
                    }
                    .font(.caption)
                }
                if let date = local.unemploymentDate {
                    let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
                    Label("已失业 \(max(days, 0)) 天", systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(L("失业情况"))
            } footer: {
                Text(L("记录失业起始日，看板会显示已坚持天数"))
            }

            Section("收入来源") {
                Toggle("领取失业金", isOn: $local.hasUnemploymentBenefit)
                if local.hasUnemploymentBenefit {
                    labeledField("每月金额", value: $local.unemploymentBenefit, suffix: "元/月")
                    Picker("还可领取", selection: $local.unemploymentBenefitMonths) {
                        Text(L("不限")).tag(0)
                        ForEach([1, 2, 3, 6, 9, 12, 18, 24], id: \.self) { m in
                            Text(Lf("%lld个月", m)).tag(m)
                        }
                    }
                }
                Toggle("有兼职收入", isOn: $local.hasPartTimeIncome)
                if local.hasPartTimeIncome {
                    labeledField("每月", value: $local.partTimeIncome, suffix: "元/月")
                }
                labeledField("配偶收入", value: $local.spouseIncome, suffix: "元/月")
                labeledField("其他收入", value: $local.otherIncome, suffix: "元/月")
                labeledField("期望月薪", value: $local.expectedMonthlySalary, suffix: "元/月")
            }

            Section {
                labeledField("家庭每月基础开销", value: $local.familyBaseLivingCost, suffix: "元/月")
                Button {
                    local.familyBaseLivingCost = local.estimatedBaseLivingCost
                } label: {
                    Label("按成员数估算（¥\(Int(local.estimatedBaseLivingCost.rounded()))/月）", systemImage: "wand.and.stars")
                        .font(.caption)
                }
            } header: {
                Text(L("生存底线"))
            } footer: {
                Text(L("一家人每月最少要花多少（吃饭+日用品）。模拟器「目标反推」会用这个数字计算底线"))
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
                        Text(L("不限")).tag(0)
                        ForEach([12, 24, 36, 60, 84, 120, 180, 240, 300, 360], id: \.self) { m in
                            Text(Lf("%lld年", m / 12)).tag(m)
                        }
                    }
                }
                labeledField("车贷", value: $local.carLoan, suffix: "元/月")
                if local.carLoan > 0 {
                    Picker("剩余还款", selection: $local.carLoanRemainingMonths) {
                        Text(L("不限")).tag(0)
                        ForEach([6, 12, 18, 24, 36, 48, 60], id: \.self) { m in
                            Text(Lf("%lld个月", m)).tag(m)
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

        }
        .listStyle(.insetGrouped)
        .navigationTitle("个人信息")
        .hideKeyboardOnTap()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L("取消")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(L("保存")) {
                    save()
                    withAnimation { showSavedToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        dismiss()
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showSavedToast {
                Text(L("已保存 ✓"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.75), in: .capsule)
                    .foregroundStyle(.white)
                    .padding(.bottom, 30)
                    .transition(.opacity)
            }
        }
    }

    @State private var showSavedToast = false

    private func save() {
        local.apply(to: profile)
        try? modelContext.save()
    }

    private func labeledField(_ label: String, value: Binding<Double>, suffix: String) -> some View {
        MoneyInputRow(label: label, value: value, suffix: suffix)
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
                    Text(L("调整前月总计"))
                    Spacer()
                    Text("\(money(totalBefore))")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(L("调整后月总计"))
                    Spacer()
                    Text("\(money(totalAfter))")
                        .fontWeight(.bold)
                        .foregroundStyle(totalAfter <= totalBefore ? .green : .red)
                }
                if totalAfter < totalBefore {
                    HStack {
                        Text(L("每月节省"))
                        Spacer()
                        Text(money(totalBefore - totalAfter))
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                    }
                }
            } header: {
                Text(L("汇总"))
            }

            Section {
                Button(L("保存调整")) {
                    save()
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .fontWeight(.semibold)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("预算调整")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(L("完成")) { dismiss() }
            }
        }
    }

    private func budgetRow(label: String, value: Binding<Double>, icon: String) -> some View {
        BudgetInputRow(label: label, value: value, icon: icon)
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
    @Environment(\.dismiss) private var dismiss
    @Query private var workouts: [WorkoutRecord]
    @Query private var studies: [StudyRecord]
    @State private var showExportSuccess = false
    @State private var showBackupSuccess = false
    @State private var showRestoreConfirm = false
    @State private var showRestoreResult = false
    @State private var restoreMessage = ""
    @State private var backupDocument: BackupFileDocument?
    @State private var showFileExporter = false
    @State private var showFileImporter = false
    @State private var showProLock = false
    @State private var showWorkoutList = false
    @State private var showStudyList = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Text(L("总记录数"))
                    Spacer()
                    Text("\(expenses.count) 条")
                        .foregroundStyle(.secondary)
                }

                Button {
                    exportCSV()
                } label: {
                    Label(L("导出 CSV（基础）"), systemImage: "square.and.arrow.up")
                }
                .disabled(expenses.isEmpty)

                if showExportSuccess {
                    Text(L("CSV 已生成，请分享到文件或邮件"))
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            } header: {
                Text(L("支出记录"))
            }

            // Pro：JSON 备份 / 恢复
            Section {
                Button {
                    guard ProFeatures.fullExport else { showProLock = true; return }
                    do {
                        let data = try DataBackup.encode(profile: profile, expenses: expenses, workouts: workouts, studies: studies)
                        backupDocument = BackupFileDocument(data: data)
                        showFileExporter = true
                    } catch {
                        restoreMessage = "备份失败：\(error.localizedDescription)"
                        showRestoreResult = true
                    }
                } label: {
                    Label(L("备份到文件（JSON）"), systemImage: ProFeatures.fullExport ? "externaldrive.fill" : "lock.fill")
                }

                Button {
                    guard ProFeatures.fullExport else { showProLock = true; return }
                    showFileImporter = true
                } label: {
                    Label(L("从文件恢复（JSON）"), systemImage: ProFeatures.fullExport ? "arrow.down.doc.fill" : "lock.fill")
                }

                if showBackupSuccess {
                    Text(L("备份已生成，请选择保存位置"))
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            } header: {
                HStack(spacing: 6) {
                    Text(L("完整备份"))
                    if !ProFeatures.fullExport {
                        ProLock.badge()
                    }
                }
            } footer: {
                Text(L("备份包含个人信息、支出、打卡和学习记录；恢复会覆盖当前数据（圈子帖子除外）。"))
            }

            Section {
                Button { showWorkoutList = true } label: {
                    Label(L("运动打卡"), systemImage: "figure.walk")
                }
                .buttonStyle(.plain)

                Button { showStudyList = true } label: {
                    Label(L("学习记录"), systemImage: "book.fill")
                }
                .buttonStyle(.plain)
            } header: {
                Text(L("模块管理"))
            } footer: {
                Text(L("新模块正在开发中，欢迎反馈建议"))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("数据管理")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(L("完成")) { dismiss() }
            }
        }
        .sheet(isPresented: $showWorkoutList) { NavigationStack { WorkoutListView() } }
        .sheet(isPresented: $showStudyList) { NavigationStack { StudyListView() } }
        .fileExporter(isPresented: $showFileExporter, document: backupDocument, contentType: .json, defaultFilename: "survival_plan_backup") { result in
            if case .success = result {
                showBackupSuccess = true
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            do {
                let data = try Data(contentsOf: url)
                let backup = try DataBackup.decode(data)
                pendingBackup = backup
                showRestoreConfirm = true
            } catch {
                restoreMessage = "文件无效或格式不匹配：\(error.localizedDescription)"
                showRestoreResult = true
            }
        }
        .alert("恢复数据？", isPresented: $showRestoreConfirm) {
            Button("恢复", role: .destructive) {
                doRestore()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(L("恢复将覆盖当前的支出、打卡和学习记录，此操作不可撤销。"))
        }
        .alert(restoreTitle, isPresented: $showRestoreResult) {
            Button(L("好")) {}
        } message: {
            Text(restoreMessage)
        }
        .alert("Pro 专属功能", isPresented: $showProLock) {
            Button(L("去解锁")) {
                StoreManager.shared.showPaywall = true
            }
            Button("好", role: .cancel) {}
        } message: {
            Text(ProLock.message(for: "完整备份/恢复"))
        }
    }

    @State private var pendingBackup: BackupData?
    private var restoreTitle: String { "备份/恢复" }

    @MainActor
    private func doRestore() {
        guard let backup = pendingBackup else { return }
        do {
            try DataBackup.restore(backup, into: modelContext, existingProfile: profile)
            restoreMessage = "恢复成功：\(backup.expenses.count) 条支出、\(backup.workouts.count) 条运动、\(backup.studies.count) 条学习记录"
        } catch {
            restoreMessage = "恢复失败：\(error.localizedDescription)"
        }
        showRestoreResult = true
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

// MARK: - 备份文件（FileDocument）
struct BackupFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - 运动打卡列表
struct WorkoutListView: View {
    @Query(sort: \WorkoutRecord.date, order: .reverse) private var records: [WorkoutRecord]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                HStack(spacing: 0) {
                    StatItem(value: "\(records.count)", label: "总次数", color: .blue)
                    StatItem(value: "\(records.reduce(0) { $0 + $1.duration })" + L("分"), label: "总时长", color: .green)
                    StatItem(value: "\(streakDays)", label: "连续天数", color: .orange)
                }
            }

            Section {
                if records.isEmpty {
                    Text(L("还没有运动记录，去「圈子 → 运动」打个卡吧"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(records) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.type)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if !record.note.isEmpty {
                                    Text(record.note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(record.duration) 分钟")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.green)
                                Text(record.date, format: .dateTime.month().day().hour().minute())
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            modelContext.delete(records[index])
                        }
                        try? modelContext.save()
                    }
                }
            } header: {
                Text(L("记录"))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("运动打卡")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(L("完成")) { dismiss() }
            }
        }
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
}

// MARK: - 学习记录列表
struct StudyListView: View {
    @Query(sort: \StudyRecord.date, order: .reverse) private var records: [StudyRecord]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                HStack(spacing: 0) {
                    StatItem(value: "\(records.count)", label: "总次数", color: .blue)
                    StatItem(value: "\(records.reduce(0) { $0 + $1.duration })" + L("分"), label: "总时长", color: .green)
                    StatItem(value: "\(Set(records.map { $0.skill }).count)", label: "技能数", color: .purple)
                }
            }

            Section {
                if records.isEmpty {
                    Text(L("还没有学习记录，去「圈子 → 学习」充充电吧"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(records) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.skill)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if !record.content.isEmpty {
                                    Text(record.content)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(record.duration) 分钟")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)
                                Text(record.date, format: .dateTime.month().day().hour().minute())
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            modelContext.delete(records[index])
                        }
                        try? modelContext.save()
                    }
                }
            } header: {
                Text(L("记录"))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("学习记录")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(L("完成")) { dismiss() }
            }
        }
    }
}

// MARK: - 关于
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    /// 隐私政策 URL：英文界面带 ?lang=en，其余默认中文
    private var privacyPolicyURL: URL {
        let base = "https://survivalplan.bbroot.com/privacy"
        return LanguageManager.isChinese ? URL(string: base)! : URL(string: base + "?lang=en")!
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text(L("应用名称"))
                    Spacer()
                    Text(L("生存计划"))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(L("版本"))
                    Spacer()
                    Text("\(appVersion) (\(appBuild))")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(L("技术栈"))
                    Spacer()
                    Text("SwiftUI + SwiftData")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label(L("应用信息"), systemImage: "apps.ipad")
            }

            Section {
                Text(L("「生存计划」帮助你在职业空窗期管理财务，知道钱在哪，日子就能过下去。"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } header: {
                Label(L("关于"), systemImage: "text.alignleft")
            }

            Section {
                Label(L("财务数据仅存储在你的设备上"), systemImage: "lock.shield.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Label(L("圈子内容会上传到社区服务器"), systemImage: "arrow.up.doc.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Link(destination: privacyPolicyURL) {
                    Label(L("隐私政策"), systemImage: "doc.text.fill")
                }
            } header: {
                Label(L("隐私"), systemImage: "hand.raised.fill")
            } footer: {
                Text(L("记账、预算、打卡数据通过 SwiftData 本地存储，不离开设备。圈子模块的帖子、评论、点赞会发送到社区服务器（用于多人互助），不包含你的姓名等真实身份信息。"))
            }

            Section {
                Link(destination: URL(string: "https://github.com/raofq/survivalplan/issues")!) {
                    Label(L("反馈与建议"), systemImage: "envelope.fill")
                }
                Link(destination: URL(string: "https://github.com/raofq/survivalplan")!) {
                    Label(L("GitHub 仓库"), systemImage: "chevron.left.forwardslash.chevron.right")
                }
            } header: {
                Label(L("链接"), systemImage: "globe")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("关于")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(L("完成")) { dismiss() }
            }
        }
    }
}

// MARK: - 整行可点击聚焦的输入行（点 label/空白也能聚焦 TextField，解决点击不生效）
struct MoneyInputRow: View {
    let label: String
    @Binding var value: Double
    let suffix: String
    @State private var text: String = ""
    @State private var syncing = false   // 防重入：切断 onChange 双向同步死循环（崩溃日志 #3）

    var body: some View {
        HStack {
            Text(L(label))
            Spacer()
            SafeMoneyField(text: $text, placeholder: L("金额"))
                .frame(width: 80)
                .onChange(of: text) { _, new in
                    guard !syncing else { return }
                    syncing = true
                    value = Double(new.replacingOccurrences(of: ",", with: "")) ?? 0
                    syncing = false
                }
            Text(L(suffix))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 8)   // 数字与单位拉开距离
        }
        .onAppear {
            if text.isEmpty { text = Self.fmt(value) }
        }
        .onChange(of: value) { _, new in
            guard !syncing else { return }
            let f = Self.fmt(new)
            if text != f {
                syncing = true
                text = f
                syncing = false
            }
        }
    }

    static func fmt(_ v: Double) -> String {
        v == 0 ? "" : String(format: "%.2f", v).replacingOccurrences(of: ".00", with: "")
    }
}

struct BudgetInputRow: View {
    let label: String
    @Binding var value: Double
    let icon: String
    @State private var text: String = ""
    @State private var syncing = false

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(L(label))
            Spacer()
            SafeMoneyField(text: $text, placeholder: L("金额"))
                .frame(width: 80)
                .onChange(of: text) { _, new in
                    guard !syncing else { return }
                    syncing = true
                    value = Double(new.replacingOccurrences(of: ",", with: "")) ?? 0
                    syncing = false
                }
            Text(L("元/月"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 8)   // 数字与单位拉开距离
        }
        .onAppear {
            if text.isEmpty { text = Self.fmt(value) }
        }
        .onChange(of: value) { _, new in
            guard !syncing else { return }
            let f = Self.fmt(new)
            if text != f {
                syncing = true
                text = f
                syncing = false
            }
        }
    }

    static func fmt(_ v: Double) -> String {
        v == 0 ? "" : String(format: "%.2f", v).replacingOccurrences(of: ".00", with: "")
    }
}





// MARK: - UIKit 安全金额输入（iOS 17.4 真机 SwiftUI TextField 死锁 bug 家族：
// UIFieldEditor 布局循环 / undoManager 无限递归 / AttributeGraph 更新循环——统一用 UITextField 桥接绕开）
final class SafeTextField: UITextField {
    override var undoManager: UndoManager? { nil }   // 切断 undoManager 无限递归（崩溃 #4）
}

struct SafeMoneyField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var alignment: NSTextAlignment = .right   // 默认右对齐（行内金额）；快速记账用 .left 与备注一致

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> SafeTextField {
        let tf = SafeTextField()
        tf.keyboardType = .decimalPad
        tf.textAlignment = alignment
        tf.placeholder = placeholder
        tf.font = .systemFont(ofSize: 17)
        tf.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        return tf
    }

    func updateUIView(_ tf: SafeTextField, context: Context) {
        tf.placeholder = placeholder   // 语言切换后更新提示词
        tf.textAlignment = alignment   // Form 可能重置对齐——每次更新强制
        if tf.text != text && !tf.isFirstResponder {
            tf.text = text
        }
    }

    class Coordinator: NSObject {
        let parent: SafeMoneyField
        init(_ p: SafeMoneyField) { parent = p }
        @objc func textChanged(_ tf: UITextField) {
            parent.text = tf.text ?? ""
        }
    }
}
