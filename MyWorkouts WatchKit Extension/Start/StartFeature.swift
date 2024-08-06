import HealthKit
import Foundation
import ComposableArchitecture

@Reducer
struct StartFeature {
  //@EnvironmentObject var workoutManager: WorkoutManager
  
  @Dependency(\.workoutClient) var workoutClient
  enum CancellationID { case observations }
  
  @ObservableState
  struct State {
    
    let workoutTypes: [HKWorkoutActivityType] = [.cycling, .running, .walking]
    
    var selectedWorkout: HKWorkoutActivityType? = nil
  }
  
  enum Action {
    case task
    case isSelectedWorkoutChanged(HKWorkoutActivityType?)
    case workoutStateChanged(HKWorkoutSessionState)
    case workoutUpdated(Statistics)
  }
  
  var body: some ReducerOf<Self> {
//    BindingReducer()
    Reduce { state, action in
      switch action {
        
      case .task:
        return .none
        
      case let .isSelectedWorkoutChanged(selectedType):
        state.selectedWorkout = selectedType
        
        guard let selectedType else { return .none }
        
        return .run { send in
          await workoutClient.startWorkout(selectedType)
          
          for await workoutStates in workoutClient.observeWorkoutState() {
            await send(.workoutStateChanged(workoutStates))
          }
        }
        .cancellable(id: CancellationID.observations, cancelInFlight: true)
        
      case .workoutStateChanged(let newState):
        print("~> workoutStateChanged", newState)
        return .none

      case .workoutUpdated(let stats):
        print("~> workoutUpdated", stats)
        return .none
      }
    }
  }
}

