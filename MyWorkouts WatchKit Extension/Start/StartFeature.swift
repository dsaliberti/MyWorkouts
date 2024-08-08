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
    
    // Child state
    @Presents var session: SessionPagingFeature.State? = nil
    
    
  }
  
  enum Action {
    case task
    case isSelectedWorkoutChanged(HKWorkoutActivityType?)
    case workoutStateChanged(HKWorkoutSessionState)
    case workoutUpdated(Statistics)
    case session(PresentationAction<SessionPagingFeature.Action>)
  }
  
  var body: some ReducerOf<Self> {
    Reduce(self.core)
    .ifLet(
      \.$session, 
       action: \.session
    ) { 
      SessionPagingFeature()
    }
  }
  
  func core(state: inout State, action: Action) -> Effect<Action> {
    switch action {
      
    case .task:
      return .none
      
    case let .isSelectedWorkoutChanged(selectedType):
      
      guard let selectedType else { return .none }
      
      // presents Session
      state.session = SessionPagingFeature.State(selectedWorkout: selectedType)
      
      return .none
//        guard let selectedType else { return .none }
//        
//        return .run { send in
//          await workoutClient.startWorkout(selectedType)
        
//          for await delegateEvents in workoutClient.delegate() {
//            
//            switch delegateEvents {
//            case let .workoutSessionDidChangeStateTo(state: state):
//              await send(.workoutStateChanged(state))
//            default: break
//            }
//          }
//        }
//        .cancellable(id: CancellationID.observations, cancelInFlight: true)
      
    case .workoutStateChanged(let newState):
      print("~> workoutStateChanged", newState.name)
      return .none

    case .workoutUpdated(let stats):
      print("~> workoutUpdated", stats)
      return .none
      
    case .session:
      return .none
    }
  }
}

