import Foundation

// MARK: - 生存报告
struct SurvivalReport {
    let totalMonthlyIncome: Double
    let totalSavings: Double
    let essentialExpenses: Double      // 刚性月支出
    let flexibleExpenses: Double       // 弹性月支出
    let totalMonthlyExpenses: Double   // 总月支出
    let monthlyShortfall: Double       // 月资金缺口
    let monthsCanSurvive: Double       // 可支撑月数
    let exhaustionDate: Date           // 资金耗尽日
    let dailyBudget: Double            // 每日预算
    let weeklyBudget: Double           // 每周预算
    let isWarning: Bool                // 是否低于警戒线
    let warningMessage: String
    
    // 各月预算
    let foodBudget: Double
    let transportBudget: Double
    let medicalBudget: Double
    let socialBudget: Double
    let shoppingBudget: Double
}

// MARK: - 生存计算器
struct SurvivalCalculator {
    
    static func calculate(from profile: UserProfile) -> SurvivalReport {
        // 月收入
        let income = profile.unemploymentBenefit
            + profile.partTimeIncome
            + profile.spouseIncome
            + profile.otherIncome
        
        // 积蓄
        let savings = profile.savings + profile.investments
        
        // 刚性月支出
        let essential = profile.mortgage
            + profile.carLoan
            + profile.propertyFee
            + profile.utilities
            + profile.internet
            + profile.phone
            + profile.insurance
            + profile.creditCardDebt
            + profile.onlineLoanDebt
            + profile.privateLoanDebt
        
        // 弹性月支出
        let flexible = profile.foodBudget
            + profile.transportBudget
            + profile.medicalBudget
            + profile.educationBudget
            + profile.socialBudget
            + profile.shoppingBudget
        
        let totalMonthly = essential + flexible
        let shortfall = totalMonthly - income
        
        // 可用资金 = 积蓄 + 每月结余 × 预计失业月数
        let monthlySurplus = income - totalMonthly
        let availableFunds: Double
        if monthlySurplus >= 0 {
            // 收支平衡或有结余
            availableFunds = savings + monthlySurplus * Double(profile.expectedMonthsBeforeJob)
        } else {
            // 每月有缺口，积蓄在消耗
            availableFunds = savings
        }
        
        // 可支撑月数
        let months: Double
        if totalMonthly <= 0 {
            months = 999
        } else if monthlySurplus >= 0 {
            months = 999 // 收支平衡，理论上无限
        } else {
            months = availableFunds / abs(monthlySurplus)
        }
        
        // 资金耗尽日
        let exhaustion = Calendar.current.date(byAdding: .month, value: Int(months), to: Date()) ?? Date()
        
        // 每日/每周预算
        let daily = totalMonthly / 30.0
        let weekly = totalMonthly / 4.0
        
        // 警戒线（可用资金不足3个月支出）
        let warning = availableFunds < essential * 3
        let warningMsg: String
        if warning {
            warningMsg = "⚠️ 资金仅够维持 \(Int(months)) 个月，低于3个月安全线，建议立即削减开支"
        } else if months < 6 {
            warningMsg = "🟡 资金可维持 \(Int(months)) 个月，建议积极寻找收入来源"
        } else {
            warningMsg = "🟢 资金状况相对安全，但建议做好长期规划"
        }
        
        // 各分类每日预算
        let total = totalMonthly
        let foodPct = total > 0 ? profile.foodBudget / total : 0
        let transportPct = total > 0 ? profile.transportBudget / total : 0
        let medicalPct = total > 0 ? profile.medicalBudget / total : 0
        let socialPct = total > 0 ? profile.socialBudget / total : 0
        let shoppingPct = total > 0 ? profile.shoppingBudget / total : 0
        
        return SurvivalReport(
            totalMonthlyIncome: income,
            totalSavings: savings,
            essentialExpenses: essential,
            flexibleExpenses: flexible,
            totalMonthlyExpenses: totalMonthly,
            monthlyShortfall: shortfall,
            monthsCanSurvive: months,
            exhaustionDate: exhaustion,
            dailyBudget: daily,
            weeklyBudget: weekly,
            isWarning: warning,
            warningMessage: warningMsg,
            foodBudget: daily * foodPct,
            transportBudget: daily * transportPct,
            medicalBudget: daily * medicalPct,
            socialBudget: daily * socialPct,
            shoppingBudget: daily * shoppingPct
        )
    }
    
    // MARK: - 模拟器
    static func simulate(profile: UserProfile, changes: SimulatedChanges) -> SurvivalReport {
        var modified = profile
        if let newIncome = changes.newMonthlyIncome {
            modified.partTimeIncome = newIncome
        }
        if let reduceExpense = changes.reduceMonthlyExpense {
            modified.foodBudget = max(0, modified.foodBudget - reduceExpense * 0.3)
            modified.shoppingBudget = max(0, modified.shoppingBudget - reduceExpense * 0.4)
            modified.transportBudget = max(0, modified.transportBudget - reduceExpense * 0.15)
            modified.socialBudget = max(0, modified.socialBudget - reduceExpense * 0.15)
        }
        if let sellAsset = changes.oneTimeIncome {
            modified.savings += sellAsset
        }
        if let newJobMonths = changes.findJobInMonths {
            modified.expectedMonthsBeforeJob = newJobMonths
        }
        return calculate(from: modified)
    }
}

struct SimulatedChanges {
    var newMonthlyIncome: Double?           // 找到工作后的月收入
    var reduceMonthlyExpense: Double?       // 每月削减开支
    var oneTimeIncome: Double?              // 一次性收入（卖车等）
    var findJobInMonths: Int?               // 几个月后找到工作
}
