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
          
//          for await delegateEvents in workoutClient.delegate() {
//            
//            switch delegateEvents {
//            case let .workoutSessionDidChangeStateTo(state: state):
//              await send(.workoutStateChanged(state))
//            default: break
//            }
//          }
        }
//        .cancellable(id: CancellationID.observations, cancelInFlight: true)
        
      case .workoutStateChanged(let newState):
        print("~> workoutStateChanged", newState.name)
        return .none

      case .workoutUpdated(let stats):
        print("~> workoutUpdated", stats)
        return .none
      }
    }
  }
}

