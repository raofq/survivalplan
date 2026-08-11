import Foundation
import SwiftData

// MARK: - 用户档案
@Model
final class UserProfile {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    
    // 收入
    var hasUnemploymentBenefit: Bool = false
    var unemploymentBenefit: Double = 0
    var unemploymentBenefitMonths: Int = 0  // 剩余可领月数，0=不限
    var hasPartTimeIncome: Bool = false
    var partTimeIncome: Double = 0
    var spouseIncome: Double = 0
    var otherIncome: Double = 0
    
    // 积蓄
    var savings: Double = 0
    var hasInvestments: Bool = false
    var investments: Double = 0
    
    // 家庭成员
    var hasSpouse: Bool = false
    var childrenCount: Int = 0
    var childrenAges: [Int] = []
    var needsSupportElders: Bool = false
    
    // 刚性支出（月）
    var mortgage: Double = 0              // 房贷/月
    var mortgageRemainingMonths: Int = 0  // 剩余还款月数，0=已还清/无
    var carLoan: Double = 0               // 车贷/月
    var carLoanRemainingMonths: Int = 0   // 剩余还款月数，0=已还清/无
    var propertyFee: Double = 0    // 物业
    var utilities: Double = 0      // 水电煤
    var internet: Double = 0       // 网络
    var phone: Double = 0          // 手机
    var insurance: Double = 0      // 保险
    
    // 弹性支出（月）
    var foodBudget: Double = 0     // 食品
    var transportBudget: Double = 0 // 交通
    var medicalBudget: Double = 0   // 医疗
    var educationBudget: Double = 0 // 教育
    var socialBudget: Double = 0    // 人情
    var shoppingBudget: Double = 0  // 购物
    
    // 债务
    var creditCardDebt: Double = 0
    var onlineLoanDebt: Double = 0
    var privateLoanDebt: Double = 0

    // 失业情况
    var unemploymentDate: Date? = nil     // 失业起始日（时间锚点，用于计算已失业天数）
    var expectedMonthlySalary: Double = 0 // 期望月薪（与模拟器反推联动）

    // 生存底线：家庭每月最少开销（吃饭+日用品等），用于目标反推/模拟器
    var familyBaseLivingCost: Double = 0

    init() {}
}

// MARK: - 个人信息编辑用值类型副本
/// @Model 不能放 @State（引用类型 + SwiftData 观察与 @State 双重管理，iOS 17.4 真机会死锁）。
/// 编辑时用此值类型副本，保存时 apply 写回。
struct UserProfileDraft {
    var hasUnemploymentBenefit: Bool
    var unemploymentBenefit: Double
    var unemploymentBenefitMonths: Int
    var hasPartTimeIncome: Bool
    var partTimeIncome: Double
    var spouseIncome: Double
    var otherIncome: Double
    var savings: Double
    var hasInvestments: Bool
    var investments: Double
    var hasSpouse: Bool
    var childrenCount: Int
    var childrenAges: [Int]
    var needsSupportElders: Bool
    var mortgage: Double
    var mortgageRemainingMonths: Int
    var carLoan: Double
    var carLoanRemainingMonths: Int
    var propertyFee: Double
    var utilities: Double
    var internet: Double
    var phone: Double
    var insurance: Double
    var foodBudget: Double
    var transportBudget: Double
    var medicalBudget: Double
    var educationBudget: Double
    var socialBudget: Double
    var shoppingBudget: Double
    var creditCardDebt: Double
    var onlineLoanDebt: Double
    var privateLoanDebt: Double
    var unemploymentDate: Date?
    var expectedMonthlySalary: Double
    var familyBaseLivingCost: Double

    init(profile: UserProfile) {
        hasUnemploymentBenefit = profile.hasUnemploymentBenefit
        unemploymentBenefit = profile.unemploymentBenefit
        unemploymentBenefitMonths = profile.unemploymentBenefitMonths
        hasPartTimeIncome = profile.hasPartTimeIncome
        partTimeIncome = profile.partTimeIncome
        spouseIncome = profile.spouseIncome
        otherIncome = profile.otherIncome
        savings = profile.savings
        hasInvestments = profile.hasInvestments
        investments = profile.investments
        hasSpouse = profile.hasSpouse
        childrenCount = profile.childrenCount
        childrenAges = profile.childrenAges
        needsSupportElders = profile.needsSupportElders
        mortgage = profile.mortgage
        mortgageRemainingMonths = profile.mortgageRemainingMonths
        carLoan = profile.carLoan
        carLoanRemainingMonths = profile.carLoanRemainingMonths
        propertyFee = profile.propertyFee
        utilities = profile.utilities
        internet = profile.internet
        phone = profile.phone
        insurance = profile.insurance
        foodBudget = profile.foodBudget
        transportBudget = profile.transportBudget
        medicalBudget = profile.medicalBudget
        educationBudget = profile.educationBudget
        socialBudget = profile.socialBudget
        shoppingBudget = profile.shoppingBudget
        creditCardDebt = profile.creditCardDebt
        onlineLoanDebt = profile.onlineLoanDebt
        privateLoanDebt = profile.privateLoanDebt
        unemploymentDate = profile.unemploymentDate
        expectedMonthlySalary = profile.expectedMonthlySalary
        familyBaseLivingCost = profile.familyBaseLivingCost
    }

    func apply(to profile: UserProfile) {
        profile.hasUnemploymentBenefit = hasUnemploymentBenefit
        profile.unemploymentBenefit = unemploymentBenefit
        profile.unemploymentBenefitMonths = unemploymentBenefitMonths
        profile.hasPartTimeIncome = hasPartTimeIncome
        profile.partTimeIncome = partTimeIncome
        profile.spouseIncome = spouseIncome
        profile.otherIncome = otherIncome
        profile.savings = savings
        profile.hasInvestments = hasInvestments
        profile.investments = investments
        profile.hasSpouse = hasSpouse
        profile.childrenCount = childrenCount
        profile.childrenAges = childrenAges
        profile.needsSupportElders = needsSupportElders
        profile.mortgage = mortgage
        profile.mortgageRemainingMonths = mortgageRemainingMonths
        profile.carLoan = carLoan
        profile.carLoanRemainingMonths = carLoanRemainingMonths
        profile.propertyFee = propertyFee
        profile.utilities = utilities
        profile.internet = internet
        profile.phone = phone
        profile.insurance = insurance
        profile.foodBudget = foodBudget
        profile.transportBudget = transportBudget
        profile.medicalBudget = medicalBudget
        profile.educationBudget = educationBudget
        profile.socialBudget = socialBudget
        profile.shoppingBudget = shoppingBudget
        profile.creditCardDebt = creditCardDebt
        profile.onlineLoanDebt = onlineLoanDebt
        profile.privateLoanDebt = privateLoanDebt
        profile.unemploymentDate = unemploymentDate
        profile.expectedMonthlySalary = expectedMonthlySalary
        profile.familyBaseLivingCost = familyBaseLivingCost
    }

    /// 按家庭成员估算的生存底线（与 UserProfile.estimatedBaseLivingCost 同逻辑）
    var estimatedBaseLivingCost: Double {
        Double(1 + (hasSpouse ? 1 : 0) + childrenCount + (needsSupportElders ? 1 : 0)) * 1500
    }
}

// MARK: - 家庭成员估算
extension UserProfile {
    /// 家庭成员总数（含自己）
    var familyMemberCount: Int {
        1 + (hasSpouse ? 1 : 0) + childrenCount + (needsSupportElders ? 1 : 0)
    }

    /// 按家庭成员估算的生存底线（人均 ¥1500/月，吃饭+日用品），用于一键填入 familyBaseLivingCost
    var estimatedBaseLivingCost: Double {
        Double(familyMemberCount) * 1500
    }
}

// MARK: - 支出记录
@Model
final class ExpenseRecord {
    var id: UUID = UUID()
    var date: Date = Date()
    var category: String = ""
    var amount: Double = 0
    var note: String = ""
    var isEssential: Bool = false  // 是否刚性支出
    
    init(category: String, amount: Double, note: String = "", isEssential: Bool = false) {
        self.category = category
        self.amount = amount
        self.note = note
        self.isEssential = isEssential
    }
}

// MARK: - 运动打卡
@Model
final class WorkoutRecord {
    var id: UUID = UUID()
    var date: Date = Date()
    var type: String = ""      // 散步/跑步/居家健身
    var duration: Int = 0      // 分钟
    var note: String = ""
    
    init() {
    }
}

// MARK: - 学习记录
@Model
final class StudyRecord {
    var id: UUID = UUID()
    var date: Date = Date()
    var skill: String = ""
    var content: String = ""
    var duration: Int = 0
    
    init() {
    }
}
