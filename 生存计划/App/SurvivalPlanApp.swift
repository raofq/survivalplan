import SwiftUI
import SwiftData

@main
struct SurvivalPlanApp: App {
    @StateObject private var store = StoreManager.shared
    @State private var locale = LanguageManager.currentLocale
    @State private var languageVersion = 0

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environment(\.locale, locale)
                // 语言切换时强制重建整棵视图树（SwiftUI Text 查表走 bundle 语言，
                // 仅改 environment locale 不生效——用 .id 重建让所有 Text 重新解析）
                .id(languageVersion)
                .sheet(isPresented: $store.showPaywall) {
                    PaywallView()
                        .environmentObject(store)
                }
                .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
                    locale = LanguageManager.currentLocale
                    languageVersion += 1
                }
        }
        .modelContainer(for: [UserProfile.self, ExpenseRecord.self, WorkoutRecord.self, StudyRecord.self, Post.self])
    }
}

extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var showOnboarding = false
    
    var body: some View {
        if let profile = profiles.first, !showOnboarding {
            MainTabView(profile: profile)
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView(profile: profile)
                }
                .onAppear {
                    AnalyticsService.shared.track("app_open")
                    NotificationManager.requestAuthorization()
                    NotificationManager.scheduleAll(profile: profile)
                }
        } else {
            WelcomeView()
        }
    }
}

#Preview {
    ContentView()
}
