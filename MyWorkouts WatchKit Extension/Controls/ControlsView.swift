import SwiftUI
import ComposableArchitecture

struct ControlsView: View {
  let store: StoreOf<ControlsFeature>
  
  var body: some View {
    WithPerceptionTracking {
      HStack {
        VStack {
          Button {
            store.send(.didTapEndWorkout)
          } label: {
            Image(systemName: "xmark")
          }
          .tint(.red)
          .font(.title2)
          Text("End")
        }
        VStack {
          Button {
            store.send(.didTapToggleWorkout)
          } label: {
            Image(systemName: store.isWorkoutRunning ? "pause" : "play")
          }
          .tint(.yellow)
          .font(.title2)
          
          Text(store.isWorkoutRunning ? "Pause" : "Resume")
        }
      }
    }
  }
}

struct ControlsView_Previews: PreviewProvider {
  static var previews: some View {
    ControlsView(
      store: StoreOf<ControlsFeature>(
        initialState: ControlsFeature.State(isWorkoutRunning: true),
        reducer: { ControlsFeature() }
      )
    )
  }
}

