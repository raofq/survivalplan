import Foundation
import UserNotifications

// MARK: - 本地通知管理
// 纯本地通知，不依赖服务器：
// 1. 每日 20:00 推送当天支出总结 + 资金状态
// 2. 每周日 20:00 推送本周支出周报
enum NotificationManager {
    
    /// 请求通知权限（首次启动调用）
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    /// 调度所有定时通知（App 启动或数据变更后调用）
    static func scheduleAll(profile: UserProfile) {
        scheduleDailySummary(profile: profile)
        scheduleWeeklyReport()
    }
    
    /// 每日 20:00 支出总结 + 资金预警
    static func scheduleDailySummary(profile: UserProfile) {
        let report = SurvivalCalculator.calculate(from: profile)
        
        var body: String
        if report.monthsCanSurvive < 3 {
            body = "⚠️ 资金仅够维持 \(Int(report.monthsCanSurvive)) 个月！今日预算 ¥\(Int(report.dailyBudget))"
        } else if report.isWarning {
            body = "资金可撑 \(Int(report.monthsCanSurvive)) 个月，今日预算 ¥\(Int(report.dailyBudget))"
        } else {
            body = "今日预算 ¥\(Int(report.dailyBudget))，记得记账"
        }
        
        let content = UNMutableNotificationContent()
        content.title = "生存计划"
        content.body = body
        content.sound = .default
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: 20, minute: 0),
            repeats: true
        )
        
        let request = UNNotificationRequest(
            identifier: "daily-summary",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    /// 每周日 20:00 周报
    static func scheduleWeeklyReport() {
        let content = UNMutableNotificationContent()
        content.title = "本周支出报告"
        content.body = "打开生存计划查看本周支出分析、资金走势和健康状态"
        content.sound = .default
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: 20, minute: 0, weekday: 1), // 周日=1
            repeats: true
        )
        
        let request = UNNotificationRequest(
            identifier: "weekly-report",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    /// 立即推送一条预警（记账后超支时调用）
    static func sendImmediateAlert(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "immediate-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    /// 移除所有已调度的通知（重置数据时调用）
    static func removeAllScheduled() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
