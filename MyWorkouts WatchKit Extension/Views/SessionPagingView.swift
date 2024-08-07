import SwiftUI
import WatchKit
import ComposableArchitecture

struct SessionPagingView: View {
  @EnvironmentObject var workoutManager: WorkoutManager
  @Environment(\.isLuminanceReduced) var isLuminanceReduced
  @State private var selection: Tab = .metrics
  
  /// Child states
  var controls = ControlsFeature.State(isWorkoutRunning: true)
  var metrics = MetricsFeature.State(startDate: Date())
  
  enum Tab {
    case controls, metrics, nowPlaying
  }
  
  var body: some View {
    TabView(selection: $selection) {
      ControlsView(
        store: StoreOf<ControlsFeature>(
          initialState: controls,
          reducer: { ControlsFeature() }
        )
      )
      .tag(Tab.controls)
      .contentShape(Rectangle())
      
      MetricsView(
        store: StoreOf<MetricsFeature>(
          initialState: metrics,
          reducer: { MetricsFeature() }
        )
      )
      .tag(Tab.metrics)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      
      NowPlayingView()
        .tag(Tab.nowPlaying)
        .contentShape(Rectangle())
    }
    
    .navigationTitle(workoutManager.selectedWorkout?.name ?? "")
    .navigationBarBackButtonHidden(true)
    .navigationBarHidden(selection == .nowPlaying)
    .onChange(of: workoutManager.running) { _ in
      displayMetricsView()
    }
    .tabViewStyle(PageTabViewStyle(indexDisplayMode: isLuminanceReduced ? .never : .automatic))
    .onChange(of: isLuminanceReduced) { _ in
      displayMetricsView()
    }
  }
  
  private func displayMetricsView() {
    withAnimation {
      selection = .metrics
    }
  }
}

struct PagingView_Previews: PreviewProvider {
  static var previews: some View {
    SessionPagingView().environmentObject(WorkoutManager())
  }
}
