import Foundation

// MARK: - 每日发帖计数（App 层，免费用户 3 条/天；Pro 不限）
/// 用 UserDefaults 记录「日期 + 当日已发数」，跨重启保持；日期变化自动清零。
enum DailyPostCounter {
    private static let countKey = "circle_post_count"
    private static let dateKey = "circle_post_date"

    /// 免费用户每日上限（后端另有 20 条/天防刷底线）
    static let freeDailyLimit = 3

    /// 今日已发数量
    static func todayCount() -> Int {
        guard UserDefaults.standard.string(forKey: dateKey) == todayString() else { return 0 }
        return UserDefaults.standard.integer(forKey: countKey)
    }

    /// 今日剩余可发次数（Pro 不限；免费用户 = 上限 - 已发）
    static func remaining() -> Int {
        if ProFeatures.circlePostLimit { return Int.max }
        return max(0, freeDailyLimit - todayCount())
    }

    /// 发帖成功后调用
    static func increment() {
        UserDefaults.standard.set(todayString(), forKey: dateKey)
        UserDefaults.standard.set(todayCount() + 1, forKey: countKey)
    }

    /// 今日是否还能发（Pro 恒 true）
    static func canPostToday() -> Bool {
        ProFeatures.circlePostLimit || todayCount() < freeDailyLimit
    }

    private static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
