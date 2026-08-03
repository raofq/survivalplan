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

    /// 模拟「找到工作」的收入切换（支持试用期）
    struct JobSimulation {
        let startMonth: Int          // 第几个月开始上班
        let probationMonths: Int     // 试用月数（0 = 无试用期）
        let probationIncome: Double  // 试用期月薪
        let regularIncome: Double    // 转正月薪
    }
    
    /// 计算某个月的具体收支（考虑时间窗口）
    /// - Parameter simulatedJob: 模拟「找到工作」的收入切换（生效月起失业金/兼职停发，收入替换为新工资）
    private static func monthFinances(profile: UserProfile, month: Int, simulatedJob: JobSimulation? = nil) -> (income: Double, essential: Double) {
        let income: Double
        if let job = simulatedJob, month >= job.startMonth {
            // 找到工作后：失业金停发、兼职由新工作替代，收入 = 新工资 + 配偶 + 其他
            let jobIncome: Double
            if job.probationMonths > 0 && month < job.startMonth + job.probationMonths {
                jobIncome = job.probationIncome
            } else {
                jobIncome = job.regularIncome
            }
            income = jobIncome + profile.spouseIncome + profile.otherIncome
        } else {
            // 收入：失业金仅在有额度且未到期时计入；兼职收入仅在开启开关时计入
            var base = profile.spouseIncome + profile.otherIncome
            if profile.hasPartTimeIncome {
                base += profile.partTimeIncome
            }
            if profile.hasUnemploymentBenefit {
                if profile.unemploymentBenefitMonths == 0 || month <= profile.unemploymentBenefitMonths {
                    base += profile.unemploymentBenefit
                }
            }
            income = base
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
        calculate(from: profile, simulatedJob: nil)
    }

    /// 内部计算入口，支持模拟收入切换
    private static func calculate(from profile: UserProfile, simulatedJob: JobSimulation?) -> SurvivalReport {
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
        let (currentIncome, currentEssential) = monthFinances(profile: profile, month: 1, simulatedJob: simulatedJob)
        let currentTotal = currentEssential + flexible
        let currentShortfall = currentTotal - currentIncome
        
        // 逐月投影
        var timeline: [MonthSnapshot] = []
        var remaining = totalSavings
        var monthsCanSurvive = 999.0
        let maxProjection = 600 // 最多投影600个月（50年）
        
        for month in 1...maxProjection {
            let (mIncome, mEssential) = monthFinances(profile: profile, month: month, simulatedJob: simulatedJob)
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
        temp.partTimeIncome = profile.partTimeIncome
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

        // 场景：卖车（车贷消失 + 一次性收入）
        if changes.removeCarLoan {
            temp.carLoan = 0
            temp.carLoanRemainingMonths = 0
            temp.savings += changes.carSaleAmount
        }
        // 场景：停购物/娱乐（购物+人情预算归零）
        if changes.zeroOutShopping {
            temp.shoppingBudget = 0
            temp.socialBudget = 0
        }
        // 场景：停兴趣班（教育预算归零）
        if changes.zeroOutEducation {
            temp.educationBudget = 0
        }
        // 场景：借款月还款（计入刚性支出）
        if changes.extraMonthlyRepayment > 0 {
            temp.privateLoanDebt += changes.extraMonthlyRepayment
        }

        // 分类级削减（优先于总额削减）
        if !changes.categoryCuts.isEmpty {
            for (cat, cut) in changes.categoryCuts {
                switch cat {
                case "食品": temp.foodBudget = max(0, profile.foodBudget - cut)
                case "交通": temp.transportBudget = max(0, profile.transportBudget - cut)
                case "医疗": temp.medicalBudget = max(0, profile.medicalBudget - cut)
                case "教育": temp.educationBudget = max(0, profile.educationBudget - cut)
                case "人情": temp.socialBudget = max(0, profile.socialBudget - cut)
                case "购物": temp.shoppingBudget = max(0, profile.shoppingBudget - cut)
                default: break
                }
            }
        }
        
        // 模拟「找到工作」：生效月（第 N 个月）起收入切换为新工资
        let simulatedJob: JobSimulation?
        if let income = changes.newMonthlyIncome, income > 0 {
            let hasProbation = changes.probationMonths > 0 && (changes.probationIncome ?? 0) > 0
            simulatedJob = JobSimulation(
                startMonth: changes.findJobInMonths ?? 1,
                probationMonths: hasProbation ? changes.probationMonths : 0,
                probationIncome: hasProbation ? (changes.probationIncome ?? income) : income,
                regularIncome: income
            )
        } else {
            simulatedJob = nil
        }

        return calculate(from: temp, simulatedJob: simulatedJob)
    }
}

struct SimulatedChanges {
    var newMonthlyIncome: Double?           // 找到工作后的月收入
    var reduceMonthlyExpense: Double?       // 每月削减开支
    var oneTimeIncome: Double?              // 一次性收入（卖车等）
    var findJobInMonths: Int?               // 几个月后找到工作
    var probationIncome: Double?            // 试用期月薪（nil = 无试用期）
    var probationMonths: Int = 0            // 试用月数
    var categoryCuts: [String: Double] = [:] // 分类级削减：分类 → 每月削减金额

    // 场景预设（精细控制）
    var removeCarLoan: Bool = false         // 卖车：车贷消失
    var carSaleAmount: Double = 0           // 卖车收入
    var zeroOutShopping: Bool = false       // 停购物/娱乐：购物+人情归零
    var zeroOutEducation: Bool = false      // 停兴趣班：教育归零
    var extraMonthlyRepayment: Double = 0   // 借款月还款（新增刚性支出）
}

// MARK: - 目标反推
struct SurvivalTarget {
    let targetMonths: Int          // 目标撑几个月
    let monthlySpendable: Double   // 积蓄 ÷ 目标月数 = 每月最多可花
    let cutNeeded: Double          // 需要削减的月支出（>0 表示还差，<=0 表示已达标）
    let isAchievable: Bool
    let belowBaseline: Bool        // 每月可花是否低于生存底线
}

extension SurvivalCalculator {
    /// 目标反推：给定目标月数，计算每月最多可花多少、还差多少需要削减/增收
    /// - Parameters:
    ///   - report: 用于反推的收支快照（可传模拟后的报告，实现联动）
    ///   - baseline: 家庭生存底线（每月最少开销）；可花额度低于它时给出提醒
    static func projectTarget(report: SurvivalReport, targetMonths: Int, baseline: Double = 0) -> SurvivalTarget {
        let monthlySpendable = report.totalSavings / Double(max(targetMonths, 1))
        let cutNeeded = report.totalMonthlyExpenses - monthlySpendable
        return SurvivalTarget(
            targetMonths: targetMonths,
            monthlySpendable: monthlySpendable,
            cutNeeded: cutNeeded,
            isAchievable: cutNeeded <= 0,
            belowBaseline: baseline > 0 && monthlySpendable < baseline
        )
    }
}
