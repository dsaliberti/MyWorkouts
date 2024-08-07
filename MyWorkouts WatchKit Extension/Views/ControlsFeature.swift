import HealthKit
import Foundation
import ComposableArchitecture

@Reducer
struct ControlsFeature {
  @Dependency(\.workoutClient) var workoutClient
  enum CancellationID { case observations }
  
  @ObservableState
  struct State {
    var isWorkoutRunning: Bool
  }
  
  enum Action {
    case task
    case didTapEndWorkout
    case didTapToggleWorkout
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .task:
        return .none
        
      case .didTapEndWorkout:
        return .run { _ in
          await workoutClient.endWorkout()
        }
        
      case .didTapToggleWorkout:
        return .run { [isRunning = state.isWorkoutRunning] _ in
          if isRunning {
            await workoutClient.pause()
          } else {
            await workoutClient.resume()
          }
        }
      }
    }
  }
}
