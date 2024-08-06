import SwiftUI
import ComposableArchitecture

@main
struct MyWorkoutsApp: App {
  @StateObject private var workoutManager = WorkoutManager()
  
  @SceneBuilder var body: some Scene {
    WindowGroup {
      NavigationView {
        WithPerceptionTracking {
          StartView(
            store: StoreOf<StartFeature>(
              initialState: StartFeature.State(), 
              reducer: { StartFeature() }
            )
          )
        }
      }
      .sheet(isPresented: $workoutManager.showingSummaryView) {
        SummaryView()
      }
      .environmentObject(workoutManager)
    }
  }
}
