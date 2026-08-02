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
    
    // 期望
    var expectedMonthsBeforeJob: Int = 6  // 预计多久能找到工作
    
    init() {}
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
