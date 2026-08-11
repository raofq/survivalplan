import Foundation
import SwiftUI

/// 应用内语言管理：跟随系统 / 简体中文 / 英文
/// 切换即时生效（通过根视图 .environment(\.locale) 注入）
enum LanguageManager {
    static let key = "app_language"
    static let system = "system"

    static var current: String {
        UserDefaults.standard.string(forKey: key) ?? system
    }

    static var currentLocale: Locale {
        switch current {
        case "zh-Hans": return Locale(identifier: "zh-Hans")
        case "en": return Locale(identifier: "en")
        default: return Locale.current
        }
    }

    /// 显示名（设置页用）
    static var displayName: String {
        switch current {
        case "zh-Hans": return "简体中文"
        case "en": return "English"
        default: return "跟随系统 / System"
        }
    }

    static func set(_ lang: String) {
        UserDefaults.standard.set(lang, forKey: key)
        // 同步 AppleLanguages：影响 bundle 级本地化（非 SwiftUI 字符串）
        var langs: [String] = []
        switch lang {
        case "zh-Hans": langs = ["zh-Hans"]
        case "en": langs = ["en"]
        default: langs = []
        }
        UserDefaults.standard.set(langs, forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }

    /// 当前是否中文界面（跟随系统时按系统语言判断）
    static var isChinese: Bool {
        switch current {
        case "zh-Hans": return true
        case "en": return false
        default: return Locale.current.language.languageCode?.identifier == "zh"
        }
    }
}

/// 数据驱动字符串本地化：中文界面直接返回原文（key 即中文，无 zh 表可查），
/// 英文界面直接查 en.lproj 翻译表（绕过 NSLocalizedString 的 AppleLanguages 缓存——
/// 运行时切语言立即生效，无需杀进程重启）。
func L(_ key: String) -> String {
    if LanguageManager.isChinese {
        return key
    }
    if let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
       let enBundle = Bundle(path: path) {
        let v = enBundle.localizedString(forKey: key, value: key, table: nil)
        return v.isEmpty ? key : v
    }
    return key
}

/// 格式化字符串本地化：中文模式直接 format 中文模板，英文模式查 en 表 format。
/// 用于带 %lld/%@ 参数的文案（如预警消息），避免 NSLocalizedString 中文回退英文。
func Lf(_ format: String, _ args: CVarArg...) -> String {
    if LanguageManager.isChinese {
        return String(format: format, args)
    }
    return String(format: L(format), args)
}

/// 金额格式化：中文界面 ¥1234，英文界面 $1234（符号随语言）。
func money(_ amount: Double) -> String {
    let v = Int(amount.rounded())
    if LanguageManager.isChinese {
        return "¥\(v)"
    }
    return "$\(v)"
}

// MARK: - 点击空白收起键盘（background 手势——不拦截前方控件）
extension View {
    func hideKeyboardOnTap() -> some View {
        background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        )
    }
}
