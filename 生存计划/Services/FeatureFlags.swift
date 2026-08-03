import SwiftUI

// MARK: - 付费墙配置（Freemium + 买断）
/// 所有 Pro 功能点集中定义。当前 `isPro` 写死 false（开发期）；
/// 接入 StoreKit 内购后，由购买状态驱动。
/// 原则：免费区 = 救命功能（记账/预算/模拟核心/圈子基础参与）；
///       Pro 区 = 提升功能（高级模拟/求职加成/数据资产）。
enum ProFeatures {
    /// 是否已解锁 Pro（一次性买断）。临时写死，接内购后改为 StoreKit 查询
    static var isPro = false

    // MARK: - 模拟器
    /// 场景预设（卖车 / 停购物 / 停补课 / 借款）
    static var simulatorScenarios: Bool { isPro }
    /// 试用期参数（试用期月薪 / 试用月数）
    static var simulatorTrialParams: Bool { isPro }
    /// 目标反推「找工作方案」建议（方案二）
    static var targetJobAdvice: Bool { isPro }

    // MARK: - 圈子
    /// 求职加成：工作帖高级筛选 / 岗位订阅推送
    static var circleJobBoost: Bool { isPro }
    /// 发帖不限次（免费用户每日 3 条；后端另有 20 条/天防刷底线）
    static var circlePostLimit: Bool { isPro }
    /// AI 简历生成
    static var aiResume: Bool { isPro }

    // MARK: - 数据与同步
    /// iCloud 同步（记账 + 参数 + 设置跨设备）
    static var cloudSync: Bool { isPro }
    /// 完整数据导出（全部模块 + 图片）；基础 CSV 导出保持免费
    static var fullExport: Bool { isPro }
    /// 云端推送（岗位订阅 / 圈子互动提醒）；本地提醒（预算超支/耗尽日）免费
    static var cloudNotifications: Bool { isPro }
}

// MARK: - Pro 锁定提示
enum ProLock {
    /// 未解锁时点击 Pro 功能的提示文案
    static func message(for feature: String) -> String {
        "「\(feature)」是 Pro 专属功能，买断解锁后可用（内购即将上线）"
    }

    /// Pro 标识角标（列表行/按钮上的小锁或皇冠）
    static func badge(_ text: String = "Pro") -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.orange.opacity(0.15), in: .capsule)
            .foregroundStyle(.orange)
    }
}
