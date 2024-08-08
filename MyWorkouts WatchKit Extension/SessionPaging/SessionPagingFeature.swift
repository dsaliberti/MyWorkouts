import Foundation
import ComposableArchitecture
import enum HealthKit.HKWorkoutSessionState
import enum HealthKit.HKWorkoutActivityType

@Reducer
struct SessionPagingFeature {
  
  @Dependency(\.workoutClient) var workoutClient
  @Dependency(\.dismiss) var dismiss
  enum CancellationID { case observations }
  
  @ObservableState
  struct State: Equatable {
    
    var selectedWorkout: HKWorkoutActivityType? = nil
    
    /// Child states
    var controls = ControlsFeature.State(isWorkoutRunning: true)
    var metrics = MetricsFeature.State(startDate: Date())
    
    var workoutName: String = ""
    var status: Status = .notStarted
    var statistics = Statistics()
    var isShowingSummary = false
    
    enum Status {
      case notStarted
      case running
      case paused
      case ended
    }
  }
  
  enum Action {
    case task
    case workoutUpdated(StatisticsField)
    case workoutStateChanged(HKWorkoutSessionState)
    case controls(ControlsFeature.Action)
    case metrics(MetricsFeature.Action)
    case didDismissSummary(Bool)
  }
  
  var body: some ReducerOf<Self> {
    Reduce(self.core)
    Scope(state: \.controls, action: \.controls) {
      ControlsFeature()
    }
    Scope(state: \.metrics, action: \.metrics) {
      MetricsFeature()
    }
  }
  
  func core(state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .task:
      print("task")
      
      return .run { send in
        
        print("SessionPagingFeature starting and observing workoutClient.delegate")
        
        for await delegateEvents in workoutClient.delegate(workoutType: .running) {
          
          switch delegateEvents {
          case let .workoutBuilderDidCollectStatistics(statisticsField):
            print(">", statisticsField)
            
            await send(.workoutUpdated(statisticsField))
            
          case let .workoutSessionDidChangeStateTo(state: workoutState):
            print(">", workoutState.name)
            await send(.workoutStateChanged(workoutState))
            
          case let .workoutSessionDidFailWithError(error: error):
            print(error)
          }
        }
      }
      .cancellable(id: CancellationID.observations, cancelInFlight: true)
      
    case let .workoutUpdated(statisticsField):
      
      switch statisticsField {
      case let .averageHeartRate(value):
        state.statistics.averageHeartRate = value  
      case let .heartRate(value):
        state.statistics.heartRate = value 
      case let .activeEnergy(value):
        state.statistics.activeEnergy = value 
      case let .distance(value):
        state.statistics.distance = value 
      case let .steps(value):
        state.statistics.steps = value 
      }
      
      return .send(.metrics(.workoutUpdated(state.statistics)))
      
    case let .workoutStateChanged(workoutState):
      switch workoutState {
      case .notStarted, .prepared:
        state.status = State.Status.notStarted
      case .running:
        state.status = .running
        
      case .ended, .stopped:
        state.status = .ended
        state.isShowingSummary = true
        
        return .run { send in
          let workout = try await workoutClient.finishWorkout()
          
          //workout.duration
          
        }
        
      case .paused:
        state.status = .paused
      default: break      
      }
      
      return .none
      
    case let .didDismissSummary(value):
      state.isShowingSummary = value
      
      if state.status == .ended && !value {
        return .run { _ in
          
          await dismiss()
        } 
      }
      
      return .none
      
    case .controls(.delegate(.didTapEndWorkout)):
      print("end now!")
      
      return .run { _ in
        await workoutClient.endWorkout()
      }
      
    case .controls, .metrics:
      return .none
    }
  }
}
