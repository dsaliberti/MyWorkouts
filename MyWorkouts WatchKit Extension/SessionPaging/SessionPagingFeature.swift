import Foundation
import ComposableArchitecture
import enum HealthKit.HKWorkoutSessionState
import enum HealthKit.HKWorkoutActivityType

@Reducer
struct SessionPagingFeature {
  
  @Dependency(\.workoutClient) var workoutClient
  @Dependency(\.dismiss) var dismiss
  @Dependency(\.continuousClock) var clock
  
  enum CancellationID { 
    case observations
    case clock
  }
  
  @ObservableState
  struct State: Equatable {
    
    var selectedWorkout: HKWorkoutActivityType? = nil
    
    /// Child states
    var controls = ControlsFeature.State(isWorkoutRunning: true)
    var metrics = MetricsFeature.State(startDate: Date())
    
    var elapsedTimeSeconds: Int = 0
    var elapsedTime: String = "00:00"
    var workoutName: String = ""
    var status: Status = .notStarted
    var statistics = Statistics()
    var startDate: Date? = nil
    var lastSplitStartDate: Date = Date()
    var isShowingSummary = false
    
    // Split
    var currentSplit: Int = 0
    var elapsedTimeSplitSeconds: Double = 0
    var distanceSplitKm: Double = 0
    
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
    case tick
    case stepsUpdated(Int)
    case speedUpdated(Double)
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
      guard let selectedWorkout = state.selectedWorkout else { return .none }
      
      return .run { send in
        
        print("SessionPagingFeature starting and observing workoutClient.delegate")
        
        for await delegateEvents in workoutClient.delegate(workoutType: selectedWorkout) {
          
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
      
    case .tick:
      state.elapsedTimeSeconds += 1
      
      let duration = Duration.seconds(state.elapsedTimeSeconds)
      state.elapsedTime = duration.formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2)))
      
      // pass data to child domains
      state.metrics.elapsedTimeSeconds = state.elapsedTimeSeconds
      state.metrics.elapsedTime = state.elapsedTime
      
      // Split
      let currentKilometer = Int(state.statistics.distance / 10)
      
      // detect
      if currentKilometer > state.currentSplit {
        print("new split detected")
        // new split, reset
        state.elapsedTimeSplitSeconds = 0
        state.distanceSplitKm = 0
        
        state.currentSplit = currentKilometer
      }
      
      // calculate
      let paceSplit = state.distanceSplitKm > 0 
      ? state.elapsedTimeSplitSeconds / state.distanceSplitKm
      : 0
      
      state.statistics.splitPace = paceSplit
      state.metrics.statistics.splitPace = paceSplit
      
      /// Fetch steps only after some time elapsed
      /// and in a reasonable frequency
      if state.elapsedTimeSeconds > 5, let startDate = state.startDate {
        
        if state.elapsedTimeSeconds % 5 == 0 {
          
          return .merge(
            fetchSteps(startDate: startDate),
            querySpeed(startDate: startDate)
          )
          
        }
      }
      
      return .none
      
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
        
      case let .splitPace(value):
        state.statistics.splitPace = value
        
      case let .steps(value):
        state.statistics.steps = value
      }
      
      return .send(.metrics(.workoutUpdated(state.statistics)))
      
    case let .workoutStateChanged(workoutState):
      switch workoutState {
      case .notStarted, .prepared:
        state.status = State.Status.notStarted
      
      case .running:
        
        if state.status == .notStarted {
          state.startDate = Date()
        }
        
        state.status = .running
        state.controls.isWorkoutRunning = true
        
        return startClock()
        
      case .ended, .stopped:
        state.status = .ended
        state.controls.isWorkoutRunning = false
        state.isShowingSummary = true
        
        return .concatenate(
          .run { send in
            let workout = try await workoutClient.finishWorkout()
            
            print("Final workout:", workout.debugDescription)
          },
          .cancel(id: CancellationID.clock)
        )
          
      case .paused:
        state.status = .paused
        state.controls.isWorkoutRunning = false
        return Effect.cancel(id: CancellationID.clock)
        
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
    
    case let .stepsUpdated(value):
      print("steps", value)
      state.statistics.steps = value
      return .none
      
    case let .speedUpdated(value):
      state.statistics.splitPace = value
      print("pace", value)
      return .none
    }
  }
  
  func startClock() -> Effect<Action> {
    return .run { send in
      for await _ in self.clock.timer(interval: .seconds(1)) {
        await send(.tick)
      }
    }
    .cancellable(id: CancellationID.clock, cancelInFlight: true)
  }
  
  func fetchSteps(startDate: Date) -> Effect<Action> {
    
    return .run { send in
      await send(.stepsUpdated(try workoutClient.queryStepsCount(startDate: startDate)))
    }
  }
  
  func querySpeed(startDate: Date) -> Effect<Action> {
    
    return .run { send in
      await send(.speedUpdated(try workoutClient.queryRunningSpeed(startDate: startDate)))
    }
  }
}
