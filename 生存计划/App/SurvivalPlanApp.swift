import SwiftUI
import SwiftData

@main
struct SurvivalPlanApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [UserProfile.self, ExpenseRecord.self, WorkoutRecord.self, StudyRecord.self, Post.self])
    }
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
