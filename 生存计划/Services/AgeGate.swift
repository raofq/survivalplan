import SwiftUI
import UIKit

// ⚠️ 未注册进 project.pbxproj，不参与编译（备用实现）。
// Declared Age Range API 为 iOS 18+ API，当前工具链 Xcode 15.2（iOS 17 SDK）无法编译；
// 升级 Xcode 16+ / macOS 14+ 后，用 add_swift_files.py 或手动注册本文件即可启用。
// 配套：App Store 年龄分级问卷「社交媒体」应选"是" +「禁止未满13周岁使用社交媒体」选"是"。

/// 社交功能年龄门禁（Declared Age Range API，iOS 18+）。
/// 对应 App Store 年龄分级声明「禁止未满 13 周岁的用户使用社交媒体」。
/// 仅 .age15To17 / .age18Plus 放行（.age12To14 含 12 岁，保守拦截）。
enum AgeGate {
    static func isEligible(_ range: AgeRangeDeclaration?) -> Bool {
        range == .age15To17 || range == .age18Plus
    }

    static func currentEligible() -> Bool {
        isEligible(UIApplication.shared.declaredAgeRange)
    }

    /// 未声明时弹系统年龄确认弹窗；返回是否达标（13+）。
    /// 已声明过则直接判断，不重复弹窗。
    static func requestEligibility() async -> Bool {
        if currentEligible() { return true }
        guard let range = try? await UIApplication.shared.requestAgeRangeDeclaration(
            consentPromptTitle: L("确认年龄"),
            consentPromptMessage: L("圈子包含社交功能，需确认你的年龄后方可使用。"),
            confirmationButtonTitle: L("继续")
        ) else { return false }
        return isEligible(range)
    }
}

/// 圈子 Tab 门禁壳：未通过年龄验证时显示提示页，不加载社交内容。
struct CircleTabView: View {
    @State private var authorized = AgeGate.currentEligible()
    @State private var needsCheck = !AgeGate.currentEligible()

    var body: some View {
        Group {
            if authorized {
                CircleView()
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 46))
                        .foregroundStyle(.orange)
                    Text(L("未满 13 岁无法使用圈子"))
                        .font(.headline)
                    Text(L("圈子是社交功能，仅限 13 岁及以上用户使用。"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button(L("重新确认年龄")) {
                        Task { authorized = await AgeGate.requestEligibility() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(28)
            }
        }
        .task {
            guard needsCheck else { return }
            authorized = await AgeGate.requestEligibility()
            needsCheck = false
        }
    }
}
