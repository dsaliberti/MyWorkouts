import ComposableArchitecture
import HealthKit

struct WorkoutClient {
  var startWorkout: (_ workoutType: HKWorkoutActivityType) async -> Void
  var observeWorkoutState: () -> AsyncStream<HKWorkoutSessionState>
  var observeStatistics: () -> AsyncStream<Statistics>
  //  var observeState: () -> AsyncStream<HKWorkoutSessionState>
  //  var requestAuthorization: () async -> Void
  var togglePause: () async -> Void
  //  var pause: () async -> Void
  //  var resume: () async -> Void
  var endWorkout: () async -> Void
  //  var queryStepCount: () async -> Void
  //  var resetWorkout: () async -> Void
}

extension WorkoutClient: DependencyKey {
  static let liveValue = live()
  
  static func live() -> Self {
    
    let workoutManager = WorkoutManager()
    return Self(
      startWorkout: { workoutType in
        print("startWorkout")
        workoutManager.selectedWorkout = workoutType
      },
      observeWorkoutState: {
        AsyncStream { continuation in
          workoutManager.updateWorkoutState = {
            continuation.yield($0)
          }
        }
      },
      observeStatistics: {
        
        AsyncStream { continuation in
          
          workoutManager.update = { 
            continuation.yield($0)
          }
          
        }
      },
      togglePause: {
        workoutManager.togglePause()
      },
      endWorkout: {
        workoutManager.endWorkout()
      }
    )
  }
}

extension DependencyValues {
  var workoutClient: WorkoutClient {
    get { self[WorkoutClient.self] }
    set { self[WorkoutClient.self] = newValue }
  }
}

struct Statistics {
  var startDate: Date
  var elapsedTime: Double = 0
  var averageHeartRate: Double = 0
  var heartRate: Double = 0
  var activeEnergy: Double = 0
  var distance: Double = 0
  var steps: Int = 0
}
