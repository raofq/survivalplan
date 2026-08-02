import Foundation

// MARK: - 生存报告
struct SurvivalReport {
    let totalMonthlyIncome: Double
    let totalSavings: Double
    let essentialExpenses: Double      // 当前月刚性支出
    let flexibleExpenses: Double       // 弹性月支出
    let totalMonthlyExpenses: Double   // 当前月总支出
    let monthlyShortfall: Double       // 当前月资金缺口
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
    let educationBudget: Double
    let socialBudget: Double
    let shoppingBudget: Double
    
    // 时间线数据
    let timeline: [MonthSnapshot]      // 逐月投影
}

struct MonthSnapshot: Identifiable {
    let id: Int                        // 月份序号（1开始）
    let income: Double
    let expenses: Double
    let net: Double
    let savingsAfter: Double           // 月末剩余积蓄
}

// MARK: - 生存计算器
struct SurvivalCalculator {
    
    /// 计算某个月的具体收支（考虑时间窗口）
    private static func monthFinances(profile: UserProfile, month: Int) -> (income: Double, essential: Double) {
        // 收入：失业金仅在有额度且未到期时计入；兼职收入仅在开启开关时计入
        var income = profile.spouseIncome + profile.otherIncome
        if profile.hasPartTimeIncome {
            income += profile.partTimeIncome
        }
        if profile.hasUnemploymentBenefit {
            if profile.unemploymentBenefitMonths == 0 || month <= profile.unemploymentBenefitMonths {
                income += profile.unemploymentBenefit
            }
        }
        
        // 刚性支出：房贷/车贷仅在有额度且未到期时计入
        var essential = profile.propertyFee
            + profile.utilities
            + profile.internet
            + profile.phone
            + profile.insurance
            + profile.creditCardDebt
            + profile.onlineLoanDebt
            + profile.privateLoanDebt
        
        if profile.mortgageRemainingMonths == 0 || month <= profile.mortgageRemainingMonths {
            essential += profile.mortgage
        }
        if profile.carLoanRemainingMonths == 0 || month <= profile.carLoanRemainingMonths {
            essential += profile.carLoan
        }
        
        return (income, essential)
    }
    
    static func calculate(from profile: UserProfile) -> SurvivalReport {
        // 积蓄
        let totalSavings = profile.savings + profile.investments
        
        // 弹性月支出（固定不变）
        let flexible = profile.foodBudget
            + profile.transportBudget
            + profile.medicalBudget
            + profile.educationBudget
            + profile.socialBudget
            + profile.shoppingBudget
        
        // 当前月（第1个月）的情况
        let (currentIncome, currentEssential) = monthFinances(profile: profile, month: 1)
        let currentTotal = currentEssential + flexible
        let currentShortfall = currentTotal - currentIncome
        
        // 逐月投影
        var timeline: [MonthSnapshot] = []
        var remaining = totalSavings
        var monthsCanSurvive = 999.0
        let maxProjection = 600 // 最多投影600个月（50年）
        
        for month in 1...maxProjection {
            let (mIncome, mEssential) = monthFinances(profile: profile, month: month)
            let mTotal = mEssential + flexible
            let mNet = mIncome - mTotal
            
            remaining += mNet
            
            timeline.append(MonthSnapshot(
                id: month,
                income: mIncome,
                expenses: mTotal,
                net: mNet,
                savingsAfter: max(remaining, 0)
            ))
            
            if remaining <= 0 && monthsCanSurvive == 999 {
                monthsCanSurvive = Double(month)
                // 继续投影以显示负值趋势
            }
        }
        
        // 资金耗尽日
        let exhaustionMonths = Int(monthsCanSurvive)
        let exhaustion: Date
        if exhaustionMonths >= maxProjection {
            exhaustion = Calendar.current.date(byAdding: .year, value: 50, to: Date()) ?? Date()
        } else {
            exhaustion = Calendar.current.date(byAdding: .month, value: exhaustionMonths, to: Date()) ?? Date()
        }
        
        // 每日/每周预算（基于当前月）
        let daily = currentTotal > 0 ? currentTotal / 30.0 : 0
        let weekly = currentTotal > 0 ? currentTotal / 4.0 : 0
        
        // 警戒线
        let warning = monthsCanSurvive < 3
        let warningMsg: String
        if monthsCanSurvive < 3 {
            warningMsg = "⚠️ 资金仅够维持 \(Int(monthsCanSurvive)) 个月，低于3个月安全线，建议立即削减开支"
        } else if monthsCanSurvive < 6 {
            warningMsg = "🟡 资金可维持 \(Int(monthsCanSurvive)) 个月，建议积极寻找收入来源"
        } else if monthsCanSurvive < 12 {
            warningMsg = "🟢 资金可维持 \(Int(monthsCanSurvive)) 个月，状况尚可但需规划"
        } else {
            warningMsg = "✅ 资金可维持 \(Int(monthsCanSurvive)) 个月以上，状况良好"
        }
        
        // 各分类每日预算
        let total = currentTotal
        let foodPct = total > 0 ? profile.foodBudget / total : 0
        let transportPct = total > 0 ? profile.transportBudget / total : 0
        let medicalPct = total > 0 ? profile.medicalBudget / total : 0
        let educationPct = total > 0 ? profile.educationBudget / total : 0
        let socialPct = total > 0 ? profile.socialBudget / total : 0
        let shoppingPct = total > 0 ? profile.shoppingBudget / total : 0
        
        return SurvivalReport(
            totalMonthlyIncome: currentIncome,
            totalSavings: totalSavings,
            essentialExpenses: currentEssential,
            flexibleExpenses: flexible,
            totalMonthlyExpenses: currentTotal,
            monthlyShortfall: currentShortfall,
            monthsCanSurvive: monthsCanSurvive,
            exhaustionDate: exhaustion,
            dailyBudget: daily,
            weeklyBudget: weekly,
            isWarning: warning,
            warningMessage: warningMsg,
            foodBudget: daily * foodPct,
            transportBudget: daily * transportPct,
            medicalBudget: daily * medicalPct,
            educationBudget: daily * educationPct,
            socialBudget: daily * socialPct,
            shoppingBudget: daily * shoppingPct,
            timeline: timeline
        )
    }
    
    // MARK: - 模拟器
    static func simulate(profile: UserProfile, changes: SimulatedChanges) -> SurvivalReport {
        // 基于原始 profile 创建临时副本用于计算
        let temp = UserProfile()
        temp.hasUnemploymentBenefit = profile.hasUnemploymentBenefit
        temp.unemploymentBenefit = profile.unemploymentBenefit
        temp.unemploymentBenefitMonths = profile.unemploymentBenefitMonths
        temp.hasPartTimeIncome = profile.hasPartTimeIncome
        temp.partTimeIncome = changes.newMonthlyIncome ?? profile.partTimeIncome
        temp.spouseIncome = profile.spouseIncome
        temp.otherIncome = profile.otherIncome
        temp.savings = profile.savings + (changes.oneTimeIncome ?? 0)
        temp.investments = profile.investments
        temp.mortgage = profile.mortgage
        temp.mortgageRemainingMonths = profile.mortgageRemainingMonths
        temp.carLoan = profile.carLoan
        temp.carLoanRemainingMonths = profile.carLoanRemainingMonths
        temp.propertyFee = profile.propertyFee
        temp.utilities = profile.utilities
        temp.internet = profile.internet
        temp.phone = profile.phone
        temp.insurance = profile.insurance
        temp.creditCardDebt = profile.creditCardDebt
        temp.onlineLoanDebt = profile.onlineLoanDebt
        temp.privateLoanDebt = profile.privateLoanDebt
        if let reduce = changes.reduceMonthlyExpense {
            temp.foodBudget = max(0, profile.foodBudget - reduce * 0.3)
            temp.shoppingBudget = max(0, profile.shoppingBudget - reduce * 0.4)
            temp.transportBudget = max(0, profile.transportBudget - reduce * 0.15)
            temp.socialBudget = max(0, profile.socialBudget - reduce * 0.15)
        } else {
            temp.foodBudget = profile.foodBudget
            temp.shoppingBudget = profile.shoppingBudget
            temp.transportBudget = profile.transportBudget
            temp.socialBudget = profile.socialBudget
        }
        temp.medicalBudget = profile.medicalBudget
        temp.educationBudget = profile.educationBudget
        
        return calculate(from: temp)
    }
}

struct SimulatedChanges {
    var newMonthlyIncome: Double?           // 找到工作后的月收入
    var reduceMonthlyExpense: Double?       // 每月削减开支
    var oneTimeIncome: Double?              // 一次性收入（卖车等）
    var findJobInMonths: Int?               // 几个月后找到工作
}
