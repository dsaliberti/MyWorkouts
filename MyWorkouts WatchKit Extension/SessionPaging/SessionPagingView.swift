import SwiftUI
import WatchKit
import ComposableArchitecture

struct SessionPagingView: View {
  @Environment(\.isLuminanceReduced) var isLuminanceReduced
  @State private var selection: Tab = .metrics
  
  @Perception.Bindable var store: StoreOf<SessionPagingFeature>
  
  enum Tab {
    case controls, metrics, nowPlaying
  }
  
  var body: some View {
    WithPerceptionTracking {
      TabView(selection: $selection) {
        ControlsView(
          store: store.scope(
            state: \.controls,
            action: \.controls
          )
        )
        .tag(Tab.controls)
        .contentShape(Rectangle())
        
        MetricsView(
          store: store.scope(
            state: \.metrics,
            action: \.metrics
          ) 
        )
        .tag(Tab.metrics)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        
        NowPlayingView()
          .tag(Tab.nowPlaying)
          .contentShape(Rectangle())
      }
      .task { 
        await store.send(.task).finish()
      }
      .navigationTitle(store.workoutName)
      .navigationBarBackButtonHidden(true)
      .navigationBarHidden(selection == .nowPlaying)
      .sheet(
        isPresented: $store.isShowingSummary.sending(\.didDismissSummary)
      ) {
        SummaryView()
      }
      
//    .onChange(of: workoutManager.running) { _ in
//      displayMetricsView()
//    }
//    .tabViewStyle(PageTabViewStyle(indexDisplayMode: isLuminanceReduced ? .never : .automatic))
//    .onChange(of: isLuminanceReduced) { _ in
//      displayMetricsView()
//    }
    }
  }
  private func displayMetricsView() {
    withAnimation {
      selection = .metrics
    }
  }
}

#Preview {
  SessionPagingView(
    store: StoreOf<SessionPagingFeature>(
      initialState: SessionPagingFeature.State(),
      reducer: { SessionPagingFeature() }
    )
  )
  //.environmentObject(WorkoutManager())
}
