import Foundation
import ComposableArchitecture

@Reducer
struct MetricsFeature {
  
  @Dependency(\.workoutClient) var workoutClient
  enum CancellationID { case observations }
  
  @ObservableState
  struct State: Equatable {
    var statistics: Statistics = Statistics(
      startDate: Date(),
      elapsedTime: 0,
      averageHeartRate: 0,
      heartRate: 0,
      activeEnergy: 0,
      distance: 0,
      steps: 0
    )
    
    var elapsedTime: String = "-"
    var energy: String = "-"
    var heartRate: String = "-"
    var distance: String = "-"
    var paceSplit: String = "-"
    var paceAverage: String = "-"
    var cadence: String = "-"
    
    var startDate: Date? = nil
    var isPaused: Bool = false
  }
  
  enum Action {
    case task
    case workoutUpdated(Statistics)
  }
  
  var body: some ReducerOf<Self> {
    Reduce(self.core)
  }
  
  func core(state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .task:
      print("task")
      formatData(state: &state)
      
      return .concatenate(
        .cancel(id: CancellationID.observations), 
          .run { send in
            for await stats in workoutClient.observeStatistics() {
              print("stats updated on task")
              await send(.workoutUpdated(stats))
            }
          }
          .cancellable(id: CancellationID.observations, cancelInFlight: true)
      )
      
    case let .workoutUpdated(statistics):
      print("workoutUpdated")
      state.statistics = statistics
      formatData(state: &state)
      return .none
    }
  }
  
  func formatData(state: inout State) {
    print("formatData")
    let duration = Duration.seconds(state.statistics.elapsedTime)
    state.elapsedTime = duration.formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2)))
    
    state.startDate = state.statistics.startDate
    
    state.energy = Measurement(value: max(0, state.statistics.activeEnergy), unit: UnitEnergy.kilocalories)
      .formatted(
        .measurement(
          width: .abbreviated,
          usage: .workout,
          numberFormatStyle: .number.precision(
            .fractionLength(0)
          )
        )
      ) 
    
    state.heartRate = state.statistics.heartRate.formatted(
      .number.precision(
        .fractionLength(0)
      )
    )
    .appending(" bpm")
    
    state.distance = Measurement(
      value: state.statistics.distance,
      unit: UnitLength.meters
    )
    .formatted(
      .measurement(
        width: .abbreviated,
        usage: .road
      )
    )
    
    state.paceSplit = "00:00/Km"
    
    let pace: Double = (state.statistics.distance > 0)
    ? Double(state.statistics.elapsedTime) / state.statistics.distance
    : Double(0)
    
    state.paceAverage = Duration
      .seconds(pace)
      .formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2)))
      .appending("/Km")

    let minutes = Int(state.statistics.elapsedTime / 60)
    state.cadence = String(format: "%d steps/min", (state.statistics.steps/max(1,minutes)))
  }
}
