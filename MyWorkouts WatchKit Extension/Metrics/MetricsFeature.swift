import Foundation
import ComposableArchitecture

@Reducer
struct MetricsFeature {
  
  @Dependency(\.workoutClient) var workoutClient
  enum CancellationID { case observations }
  
  @ObservableState
  struct State: Equatable {
    
    // Components
    enum MetricsComponent: Hashable {
      case energy
      case heartRate
      case distance
      case paceSplit
      case paceAverage
      case cadence
    }
    
    // Confirguration
    var configuration: [MetricsComponent] {
      [
        .energy,
        .heartRate,
        .distance,
        .paceSplit,
        .paceAverage,
        .cadence
      ]
    }
    
    // Data to display
    var statistics: Statistics = Statistics(
//      startDate: Date(),
//      elapsedTime: 0,
      averageHeartRate: 0,
      heartRate: 0,
      activeEnergy: 0,
      distance: 0,
      steps: 0
    )
    
    var elapsedTimeSeconds: Int = 0
    var elapsedTime: String = "-"
    var energy: String = "-"
    var heartRate: String = "-"
    var distance: String = "-"
    var paceSplit: String = "-"
    var paceAverage: String = "-"
    var cadence: String = "-"
    
    var startDate: Date
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
      formatData(state: &state)
      return .none
      
    case let .workoutUpdated(statistics):
      print("metrics workoutUpdated")
      state.statistics = statistics
      formatData(state: &state)
      
      return .none
    }
  }
  
  func formatData(state: inout State) {
    
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
    
    state.paceSplit = Duration
      .seconds(state.statistics.splitPace)
      .formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2)))
      .appending("/Km cur pace")
    
    let km = state.statistics.distance / 1000
    print("km", km)
    print("sec", state.elapsedTimeSeconds)
    
    let pace: Double = (state.statistics.distance > 0)
    ? Double(state.elapsedTimeSeconds) / km
    : Double(0)
    
    print("pace km", pace) 
    
    state.paceAverage = Duration
      .seconds(pace)
      .formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2)))
      .appending("/Km avg pace")
    
    let minutes = Int(state.elapsedTimeSeconds / 60)
    
    let cadence = minutes > 0
    ? state.statistics.steps/minutes
    : 0
    
    state.cadence = String(format: "%d steps/min", cadence)
  }
}
