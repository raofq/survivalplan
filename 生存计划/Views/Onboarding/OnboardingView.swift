import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @State private var profile: UserProfile
    @State private var showCompletion = false
    
    init(profile: UserProfile) {
        _profile = State(initialValue: profile)
    }
    
    let totalSteps = 6
    
    var body: some View {
        NavigationStack {
            VStack {
                // 进度条
                ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                Text("步骤 \(currentStep + 1) / \(totalSteps)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                
                TabView(selection: $currentStep) {
                    IncomeView(profile: $profile).tag(0)
                    SavingsView(profile: $profile).tag(1)
                    FamilyView(profile: $profile).tag(2)
                    EssentialExpenseView(profile: $profile).tag(3)
                    FlexibleExpenseView(profile: $profile).tag(4)
                    DebtAndGoalView(profile: $profile).tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button("上一步") {
                            withAnimation { currentStep -= 1 }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                    
                    if currentStep < totalSteps - 1 {
                        Button("下一步") {
                            hideKeyboard()
                            withAnimation { currentStep += 1 }
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("完成") {
                            saveAndDismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationTitle("填写信息")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if showCompletion {
                    CompletionView()
                        .transition(.opacity)
                }
            }
        }
    }
    
    private func saveAndDismiss() {
        hideKeyboard()
        modelContext.insert(profile)
        try? modelContext.save()
        withAnimation { showCompletion = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            dismiss()
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - 完成动画
struct CompletionView: View {
    @State private var scale = 0.5
    @State private var opacity = 0.0

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)
                    .scaleEffect(scale)
                    .opacity(opacity)

                Text("生存报告已生成！")
                    .font(.title2)
                    .fontWeight(.bold)
                    .opacity(opacity)

                Text("你的专属预算已经算好了")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

// MARK: - 步骤1：收入来源
struct IncomeView: View {
    @Binding var profile: UserProfile
    
    var body: some View {
        Form {
            Section {
                Toggle("领取失业金", isOn: $profile.hasUnemploymentBenefit)
                if profile.hasUnemploymentBenefit {
                    HStack {
                        Text("每月金额")
                        Spacer()
                        TextField("金额", value: $profile.unemploymentBenefit, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("元/月")
                    }
                    HStack {
                        Text("还可领取")
                        Spacer()
                        Picker("", selection: $profile.unemploymentBenefitMonths) {
                            Text("不限").tag(0)
                            ForEach([1,2,3,6,9,12,18,24], id: \.self) { m in
                                Text("\(m)个月").tag(m)
                            }
                        }
                    }
                }
                
                Toggle("有兼职/零工收入", isOn: $profile.hasPartTimeIncome)
                if profile.hasPartTimeIncome {
                    HStack {
                        Text("每月")
                        Spacer()
                        TextField("金额", value: $profile.partTimeIncome, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("元/月")
                    }
                }
                
                HStack {
                    Text("配偶收入")
                    Spacer()
                    TextField("金额", value: $profile.spouseIncome, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text("元/月")
                }
                
                HStack {
                    Text("其他收入")
                    Spacer()
                    TextField("金额", value: $profile.otherIncome, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text("元/月")
                }
            } header: {
                Text("收入来源")
            } footer: {
                Text("请如实填写，这关系到生存计算的准确性")
            }
        }
    }
}

// MARK: - 步骤2：积蓄
struct SavingsView: View {
    @Binding var profile: UserProfile
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("银行存款")
                    Spacer()
                    TextField("金额", value: $profile.savings, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text("元")
                }
                
                Toggle("有理财产品/股票/基金", isOn: $profile.hasInvestments)
                if profile.hasInvestments {
                    HStack {
                        Text("可变现金额")
                        Spacer()
                        TextField("金额", value: $profile.investments, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("元")
                    }
                }
            } header:{
                Text("积蓄")
            } footer: {
                Text("理财产品按可立即变现的金额填写")
            }
        }
    }
}

// MARK: - 步骤3：家庭成员
struct FamilyView: View {
    @Binding var profile: UserProfile
    
    var body: some View {
        Form {
            Section{
                Toggle("有配偶", isOn: $profile.hasSpouse)
                
                Stepper("子女数量: \(profile.childrenCount)", value: $profile.childrenCount, in: 0...10)
                
                Toggle("需赡养老人", isOn: $profile.needsSupportElders)
            } header: {
                Text("家庭成员")
            }

            Section {
                HStack {
                    Text("家庭每月基础开销")
                    Spacer()
                    NumberField(value: $profile.familyBaseLivingCost)
                    Text("元/月")
                }
                Button {
                    profile.familyBaseLivingCost = profile.estimatedBaseLivingCost
                } label: {
                    Label("按成员数估算（¥\(Int(profile.estimatedBaseLivingCost))/月）", systemImage: "wand.and.stars")
                        .font(.subheadline)
                }
            } header: {
                Text("生存底线")
            } footer: {
                Text("一家人每月最少要花多少（吃饭+日用品）。按成员数估算后可以手动调整")
            }
        }
    }
}

// MARK: - 步骤4：刚性支出
struct EssentialExpenseView: View {
    @Binding var profile: UserProfile
    
    var body: some View {
        Form {
            Section {
                HStack { Text("房贷"); Spacer(); NumberField(value: $profile.mortgage); Text("元/月") }
                if profile.mortgage > 0 {
                    HStack {
                        Text("剩余还款")
                        Spacer()
                        Picker("", selection: $profile.mortgageRemainingMonths) {
                            Text("不限").tag(0)
                            ForEach([12,24,36,60,84,120,180,240,300,360], id: \.self) { m in
                                Text("\(m/12)年").tag(m)
                            }
                        }
                    }
                }
                HStack { Text("车贷"); Spacer(); NumberField(value: $profile.carLoan); Text("元/月") }
                if profile.carLoan > 0 {
                    HStack {
                        Text("剩余还款")
                        Spacer()
                        Picker("", selection: $profile.carLoanRemainingMonths) {
                            Text("不限").tag(0)
                            ForEach([6,12,18,24,36,48,60], id: \.self) { m in
                                Text("\(m)个月").tag(m)
                            }
                        }
                    }
                }
                HStack { Text("物业费"); Spacer(); NumberField(value: $profile.propertyFee); Text("元/月") }
                HStack { Text("水电煤"); Spacer(); NumberField(value: $profile.utilities); Text("元/月") }
                HStack { Text("网络"); Spacer(); NumberField(value: $profile.internet); Text("元/月") }
                HStack { Text("手机"); Spacer(); NumberField(value: $profile.phone); Text("元/月") }
                HStack { Text("保险"); Spacer(); NumberField(value: $profile.insurance); Text("元/月") }
            } header:{
                Text("每月固定支出（刚性）")
            } footer: {
                Text("刚性支出是每个月必须花的钱，请尽量填写准确")
            }
        }
    }
}

// MARK: - 步骤5：弹性支出
struct FlexibleExpenseView: View {
    @Binding var profile: UserProfile
    
    var body: some View {
        Form {
            Section {
                HStack { Text("食品/买菜"); Spacer(); NumberField(value: $profile.foodBudget); Text("元/月") }
                HStack { Text("交通"); Spacer(); NumberField(value: $profile.transportBudget); Text("元/月") }
                HStack { Text("医疗"); Spacer(); NumberField(value: $profile.medicalBudget); Text("元/月") }
                HStack { Text("教育/小孩"); Spacer(); NumberField(value: $profile.educationBudget); Text("元/月") }
                HStack { Text("人情往来"); Spacer(); NumberField(value: $profile.socialBudget); Text("元/月") }
                HStack { Text("购物/娱乐"); Spacer(); NumberField(value: $profile.shoppingBudget); Text("元/月") }
            } header:{
                Text("每月弹性支出（可调整）")
            } footer: {
                Text("弹性支出是可以削减的部分，后续会给出优化建议")
            }
        }
    }
}

// MARK: - 步骤6：债务与目标
struct DebtAndGoalView: View {
    @Binding var profile: UserProfile
    
    var body: some View {
        Form {
            Section("债务（每月还款额）") {
                HStack { Text("信用卡"); Spacer(); NumberField(value: $profile.creditCardDebt); Text("元/月") }
                HStack { Text("网贷"); Spacer(); NumberField(value: $profile.onlineLoanDebt); Text("元/月") }
                HStack { Text("私人借款"); Spacer(); NumberField(value: $profile.privateLoanDebt); Text("元/月") }
            }
        }
    }
}

// MARK: - 辅助组件
struct NumberField: View {
    @Binding var value: Double
    
    var body: some View {
        TextField("金额", value: $value, format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 80)
    }
}
