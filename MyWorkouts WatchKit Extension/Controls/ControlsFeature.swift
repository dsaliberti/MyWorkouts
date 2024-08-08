import HealthKit
import Foundation
import ComposableArchitecture

@Reducer
struct ControlsFeature {
  @Dependency(\.workoutClient) var workoutClient
  enum CancellationID { case observations }
  
  @ObservableState
  struct State: Equatable {
    var isWorkoutRunning: Bool
  }
  
  enum Action {
    case task
    case didTapEndWorkout
    case didTapToggleWorkout
    case delegate(Delegate)
    
    enum Delegate {
      case didTapEndWorkout
      case didTapToggleWorkout
    }
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .task:
        return .none
        
      case .didTapEndWorkout:
        print("controls didTapEndWorkout")
        return .send(.delegate(.didTapEndWorkout))
        
      case .didTapToggleWorkout:
        return .run { [isRunning = state.isWorkoutRunning] _ in
          if isRunning {
            await workoutClient.pause()
          } else {
            await workoutClient.resume()
          }
        }
        
        /// Delegate should be always handled by the parent domain
      case .delegate:
        return .none
      }
    }
  }
}
