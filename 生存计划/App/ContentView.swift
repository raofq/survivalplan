import SwiftUI
import SwiftData

// MARK: - 欢迎页
struct WelcomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showSetup = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue.gradient)
                
                Text(L("生存计划"))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(L("知道钱在哪，日子就能过下去"))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(icon: "dollarsign.circle", text: "清楚的财务状况分析")
                    FeatureRow(icon: "calendar.day.timeline.left", text: "详细到天的生存预算")
                    FeatureRow(icon: "exclamationmark.triangle", text: "智能资金警戒线预警")
                    FeatureRow(icon: "arrow.triangle.2.circlepath", text: "「如果…会怎样」模拟器")
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                Button(action: { showSetup = true }) {
                    Text(L("开始规划"))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.blue, in: .capsule)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
            .fullScreenCover(isPresented: $showSetup) {
                OnboardingView(profile: UserProfile())
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)
            Text(L(text))
                .font(.subheadline)
        }
    }
}

// MARK: - 主 Tab 页
struct MainTabView: View {
    let profile: UserProfile
    
    var body: some View {
        TabView {
            DashboardView(profile: profile)
                .tabItem { Label(L("看板"), systemImage: "house.fill") }
                .onAppear { AnalyticsService.shared.track("view_tab", params: ["tab": "看板"]) }
            
            BudgetView(profile: profile)
                .tabItem { Label(L("预算"), systemImage: "wallet.pass.fill") }
                .onAppear { AnalyticsService.shared.track("view_tab", params: ["tab": "预算"]) }
            
            SimulatorView(profile: profile)
                .tabItem { Label(L("模拟"), systemImage: "arrow.triangle.2.circlepath") }
                .onAppear { AnalyticsService.shared.track("view_tab", params: ["tab": "模拟"]) }

            CircleView()
                .tabItem { Label(L("圈子"), systemImage: "person.3.fill") }
                .onAppear { AnalyticsService.shared.track("view_tab", params: ["tab": "圈子"]) }
        }
    }
}
