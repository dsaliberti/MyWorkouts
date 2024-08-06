import Foundation
import ComposableArchitecture

@Reducer
struct MetricsFeature {
  
  @Dependency(\.workoutClient) var workoutClient
  enum CancellationID { case observations }
  
  @ObservableState
  struct State {
    var elapsedTime: String = ""
    var energy: String = ""
    var heartRate: String = ""
    var distance: String = ""
    var paceSplit: String = ""
    var paceAverage: String = ""
    var cadence: String = ""
    
    var startDate: Date? = nil
    var isPaused: Bool = false
  }
  
  enum Action {
    case task
    case workoutUpdated(Statistics)
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .task:
        return .run { send in
          for await stats in workoutClient.observeStatistics() {
            await send(.workoutUpdated(stats))
          }
        }
        .cancellable(id: CancellationID.observations, cancelInFlight: true)
        
      case let .workoutUpdated(statistics):
        
        let duration = Duration.seconds(statistics.elapsedTime)
        state.elapsedTime = duration.formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2)))
        
        state.startDate = statistics.startDate
        
        state.energy = Measurement(value: max(0, statistics.activeEnergy), unit: UnitEnergy.kilocalories)
          .formatted(
            .measurement(
              width: .abbreviated,
              usage: .workout,
              numberFormatStyle: .number.precision(
                .fractionLength(0)
              )
            )
          ) 
        
        state.heartRate = statistics.heartRate.formatted(
          .number.precision(
            .fractionLength(0)
          )
        )
        .appending(" bpm")
        
        state.distance = Measurement(
          value: statistics.distance,
          unit: UnitLength.meters
        )
        .formatted(
          .measurement(
            width: .abbreviated,
            usage: .road
          )
        )
        
        state.paceSplit = "00:00/Km"
        
        let pace: Double = (statistics.distance > 0)
        ? Double(statistics.elapsedTime) / statistics.distance
        : Double(0)
        
        state.paceAverage = Duration
          .seconds(pace)
          .formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2)))
          .appending("/Km")
        
        let minutes = Int((statistics.elapsedTime ?? 0) / 60)
        state.cadence = String(format: "%d steps/min", (statistics.steps/max(1,minutes)))
        
        return .none
        
      }
    }
  }
}
