import ComposableArchitecture
import HealthKit

@DependencyClient
struct WorkoutClient {
  var startWorkout: @Sendable (_ workoutType: HKWorkoutActivityType) async -> Void
  var delegate: @Sendable (_ workoutType: HKWorkoutActivityType) -> AsyncStream<DelegateEvent> = { _ in .finished }
  //  var requestAuthorization: () async -> Void
  var pause: () async -> Void
  var resume: @Sendable () async -> Void
  var endWorkout: @Sendable () async -> Void
  var finishWorkout: @Sendable () async throws -> HKWorkout?
  
  @CasePathable
  enum DelegateEvent {
    case workoutSessionDidChangeStateTo(state: HKWorkoutSessionState)
    case workoutSessionDidFailWithError(error: Error)
    case workoutBuilderDidCollectStatistics(StatisticsField)
  }
}

extension WorkoutClient: DependencyKey {
  static let liveValue = live()
  
  static let healthStore = HKHealthStore()
  static var session: HKWorkoutSession?
  static var builder: HKLiveWorkoutBuilder?
  
  static func live() -> Self {
    
    return Self.init(
      startWorkout: { workoutType in
        print("workoutClient: startWorkout", workoutType)
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = workoutType
        configuration.locationType = .outdoor
        
        // Create the session and obtain the workout builder.
        do {
          session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
          builder = session?.associatedWorkoutBuilder()
          
        } catch let error {
          print("workoutClient: catch", error)
          return
        }
        
        // Set the workout builder's data source.
        builder?.dataSource = HKLiveWorkoutDataSource(
          healthStore: healthStore,
          workoutConfiguration: configuration
        )
        
        // Start the workout session and begin data collection.
        let startDate = Date()
        
        session?.startActivity(with: startDate)
        
        try? await builder?.beginCollection(at: startDate)
        
      },
      delegate: { workoutType in
        
        AsyncStream { continuation in
          let configuration = HKWorkoutConfiguration()
          configuration.activityType = workoutType
          configuration.locationType = .outdoor
          
          // Create the session and obtain the workout builder.
          do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()
          } catch let error {
            print("workoutClient: catch", error)
            return
          }
          
          // Set the workout builder's data source.
          builder?.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
          )
          
          let delegate = Delegate(continuation: continuation)
          
          // Setup session and builder.
          session?.delegate = delegate
          
          // WorkoutBuilder
          builder?.delegate = delegate
          
          print("WorkoutClient delegates set", session)
          
          continuation.onTermination = { _ in
            _ = delegate
          }
          
          // Start the workout session and begin data collection.
          let startDate = Date()
          session?.startActivity(with: startDate)
          
          builder?.beginCollection(withStart: startDate, completion: { _,error in print(error) })
        }
      },
      pause: {
        session?.pause()
      },
      resume: {
        session?.resume()
      },
      endWorkout: {
        print("endWorkout", session, Self.session?.state.name, session?.delegate)
        session?.end()
        Task {
          try? await builder?.endCollection(at: Date())
        }
      }, 
      finishWorkout: {
        try await builder?.finishWorkout()          
      }
    )
  }
}

extension WorkoutClient {
  class Delegate: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    let continuation: AsyncStream<WorkoutClient.DelegateEvent>.Continuation
    
    init(continuation: AsyncStream<WorkoutClient.DelegateEvent>.Continuation) {
      self.continuation = continuation
      print("WorkoutClient HK Delegate initted")
    }
    
    deinit {
      print("WorkoutClient HK Delegate deinitted properly")
    }
    
    
    /*
     HKWorkoutSessionDelegate
     */
    func workoutSession(
      _ workoutSession: HKWorkoutSession,
      didChangeTo toState: HKWorkoutSessionState,
      from fromState: HKWorkoutSessionState,
      date: Date
    ) {
      print("workoutClient delegate", toState.name)
      self.continuation.yield(.workoutSessionDidChangeStateTo(state: toState))
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
      print("workoutSession didFail", error)
      self.continuation.yield(.workoutSessionDidFailWithError(error: error))
    }
    
    
    /*
     HKLiveWorkoutBuilderDelegate
     */
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) { }
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
      for type in collectedTypes {
        guard let quantityType = type as? HKQuantityType else {
          return // Nothing to do.
        }
        
        if let statistics = workoutBuilder.statistics(for: quantityType) {
          continuation.yield(.workoutBuilderDidCollectStatistics(convert(statistics)))
        }
        
        
      }
    }
    
    fileprivate func convert(_ statistics: HKStatistics) -> StatisticsField {
      
      switch statistics.quantityType {
      case HKQuantityType.quantityType(forIdentifier: .heartRate):
        let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
        return .heartRate(statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit) ?? 0)
//        averageHeartRate = statistics.averageQuantity()?.doubleValue(for: heartRateUnit) ?? 0
      
      case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
        let energyUnit = HKUnit.kilocalorie()
        return .activeEnergy(statistics.sumQuantity()?.doubleValue(for: energyUnit) ?? 0)
      
      case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning), HKQuantityType.quantityType(forIdentifier: .distanceCycling):
        let meterUnit = HKUnit.meter()
        return .distance(statistics.sumQuantity()?.doubleValue(for: meterUnit) ?? 0)
        
      default:
        return .steps(0)
      }
    }
  }
}

extension DependencyValues {
  var workoutClient: WorkoutClient {
    get { self[WorkoutClient.self] }
    set { self[WorkoutClient.self] = newValue }
  }
}

enum StatisticsField {
  case averageHeartRate(Double)
  case heartRate(Double)
  case activeEnergy(Double)
  case distance(Double)
  case steps(Int)
}

struct Statistics: Equatable {
  var averageHeartRate: Double = 0
  var heartRate: Double = 0
  var activeEnergy: Double = 0
  var distance: Double = 0
  var steps: Int = 0
}

// Debug helper
extension HKWorkoutSessionState {
  var name: String {
    return switch self {
    case .notStarted:
      "notStarted"
    case .running:
      "running"
    case .ended:
      "ended"
    case .paused:
      "paused"
    case .prepared:
      "prepared"
    case .stopped:
      "stopped"
    @unknown default:
      "unknown"
    }
  }
}
