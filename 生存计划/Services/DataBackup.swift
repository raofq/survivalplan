import Foundation
import SwiftData

// MARK: - 数据备份（JSON，Pro 功能）
/// 备份范围：UserProfile + 支出/运动/学习记录（排除圈子 Post——圈子以后端云端为准）
struct BackupData: Codable {
    var version: Int = 1
    var exportedAt: Date = Date()
    var profile: ProfileDTO?
    var expenses: [ExpenseDTO] = []
    var workouts: [WorkoutDTO] = []
    var studies: [StudyDTO] = []
}

struct ProfileDTO: Codable {
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

    init(from p: UserProfile) {
        hasUnemploymentBenefit = p.hasUnemploymentBenefit
        unemploymentBenefit = p.unemploymentBenefit
        unemploymentBenefitMonths = p.unemploymentBenefitMonths
        hasPartTimeIncome = p.hasPartTimeIncome
        partTimeIncome = p.partTimeIncome
        spouseIncome = p.spouseIncome
        otherIncome = p.otherIncome
        savings = p.savings
        hasInvestments = p.hasInvestments
        investments = p.investments
        hasSpouse = p.hasSpouse
        childrenCount = p.childrenCount
        needsSupportElders = p.needsSupportElders
        mortgage = p.mortgage
        mortgageRemainingMonths = p.mortgageRemainingMonths
        carLoan = p.carLoan
        carLoanRemainingMonths = p.carLoanRemainingMonths
        propertyFee = p.propertyFee
        utilities = p.utilities
        internet = p.internet
        phone = p.phone
        insurance = p.insurance
        foodBudget = p.foodBudget
        transportBudget = p.transportBudget
        medicalBudget = p.medicalBudget
        educationBudget = p.educationBudget
        socialBudget = p.socialBudget
        shoppingBudget = p.shoppingBudget
        creditCardDebt = p.creditCardDebt
        onlineLoanDebt = p.onlineLoanDebt
        privateLoanDebt = p.privateLoanDebt
        unemploymentDate = p.unemploymentDate
        expectedMonthlySalary = p.expectedMonthlySalary
        familyBaseLivingCost = p.familyBaseLivingCost
    }

    func apply(to p: UserProfile) {
        p.hasUnemploymentBenefit = hasUnemploymentBenefit
        p.unemploymentBenefit = unemploymentBenefit
        p.unemploymentBenefitMonths = unemploymentBenefitMonths
        p.hasPartTimeIncome = hasPartTimeIncome
        p.partTimeIncome = partTimeIncome
        p.spouseIncome = spouseIncome
        p.otherIncome = otherIncome
        p.savings = savings
        p.hasInvestments = hasInvestments
        p.investments = investments
        p.hasSpouse = hasSpouse
        p.childrenCount = childrenCount
        p.needsSupportElders = needsSupportElders
        p.mortgage = mortgage
        p.mortgageRemainingMonths = mortgageRemainingMonths
        p.carLoan = carLoan
        p.carLoanRemainingMonths = carLoanRemainingMonths
        p.propertyFee = propertyFee
        p.utilities = utilities
        p.internet = internet
        p.phone = phone
        p.insurance = insurance
        p.foodBudget = foodBudget
        p.transportBudget = transportBudget
        p.medicalBudget = medicalBudget
        p.educationBudget = educationBudget
        p.socialBudget = socialBudget
        p.shoppingBudget = shoppingBudget
        p.creditCardDebt = creditCardDebt
        p.onlineLoanDebt = onlineLoanDebt
        p.privateLoanDebt = privateLoanDebt
        p.unemploymentDate = unemploymentDate
        p.expectedMonthlySalary = expectedMonthlySalary
        p.familyBaseLivingCost = familyBaseLivingCost
    }
}

struct ExpenseDTO: Codable {
    var id: UUID
    var date: Date
    var category: String
    var amount: Double
    var note: String
    var isEssential: Bool

    init(from e: ExpenseRecord) {
        id = e.id
        date = e.date
        category = e.category
        amount = e.amount
        note = e.note
        isEssential = e.isEssential
    }

    func toRecord() -> ExpenseRecord {
        let r = ExpenseRecord(category: category, amount: amount, note: note, isEssential: isEssential)
        r.id = id
        r.date = date
        return r
    }
}

struct WorkoutDTO: Codable {
    var id: UUID
    var date: Date
    var type: String
    var duration: Int
    var note: String

    init(from w: WorkoutRecord) {
        id = w.id
        date = w.date
        type = w.type
        duration = w.duration
        note = w.note
    }

    func toRecord() -> WorkoutRecord {
        let r = WorkoutRecord()
        r.id = id
        r.date = date
        r.type = type
        r.duration = duration
        r.note = note
        return r
    }
}

struct StudyDTO: Codable {
    var id: UUID
    var date: Date
    var skill: String
    var content: String
    var duration: Int

    init(from s: StudyRecord) {
        id = s.id
        date = s.date
        skill = s.skill
        content = s.content
        duration = s.duration
    }

    func toRecord() -> StudyRecord {
        let r = StudyRecord()
        r.id = id
        r.date = date
        r.skill = skill
        r.content = content
        r.duration = duration
        return r
    }
}

// MARK: - 备份 / 恢复
enum DataBackup {
    static func encode(profile: UserProfile, expenses: [ExpenseRecord], workouts: [WorkoutRecord], studies: [StudyRecord]) throws -> Data {
        let data = BackupData(
            profile: ProfileDTO(from: profile),
            expenses: expenses.map { ExpenseDTO(from: $0) },
            workouts: workouts.map { WorkoutDTO(from: $0) },
            studies: studies.map { StudyDTO(from: $0) }
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(data)
    }

    static func decode(_ data: Data) throws -> BackupData {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BackupData.self, from: data)
    }

    /// 恢复：清空现有记录 → 回写 profile → 插入记录
    @MainActor
    static func restore(_ backup: BackupData, into context: ModelContext, existingProfile: UserProfile) throws {
        try context.delete(model: ExpenseRecord.self)
        try context.delete(model: WorkoutRecord.self)
        try context.delete(model: StudyRecord.self)
        if let profile = backup.profile {
            profile.apply(to: existingProfile)
        }
        for e in backup.expenses { context.insert(e.toRecord()) }
        for w in backup.workouts { context.insert(w.toRecord()) }
        for s in backup.studies { context.insert(s.toRecord()) }
        try context.save()
    }
}
