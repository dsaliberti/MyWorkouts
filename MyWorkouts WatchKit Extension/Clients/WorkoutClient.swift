import ComposableArchitecture
import HealthKit

@DependencyClient
struct WorkoutClient {
  var startWorkout: @Sendable (_ workoutType: HKWorkoutActivityType) async -> Void
  var delegate: @Sendable (_ workoutType: HKWorkoutActivityType) -> AsyncStream<DelegateEvent> = { _ in .finished }
//  var startObserveWorkout: @Sendable (_ workoutType: HKWorkoutActivityType) -> AsyncStream<DelegateEvent> = { _ in .finished }
  //var observeWorkoutState: () -> AsyncStream<HKWorkoutSessionState>
  //var observeStatistics: () -> AsyncStream<Statistics>
  //  var observeState: () -> AsyncStream<HKWorkoutSessionState>
  //  var requestAuthorization: () async -> Void
  var pause: () async -> Void
  //  var pause: () async -> Void
  var resume: @Sendable () async -> Void
  var endWorkout: @Sendable () async -> Void
  //  var queryStepCount: () async -> Void
  //  var resetWorkout: () async -> Void
  
  @CasePathable
  enum DelegateEvent {
    case workoutSessionDidChangeStateTo(state: HKWorkoutSessionState)
    case workoutSessionDidFailWithError(error: Error)
    case workoutBuilderDidCollectStatistics(statistics: Statistics)
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
          
          guard session?.delegate == nil else {
            continuation.finish()
            return
          }
          
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
          
          print("WorkoutClient delegates set")
          
          continuation.onTermination = { _ in
            _ = delegate
          }
          
          // Start the workout session and begin data collection.
          let startDate = Date()
          session?.startActivity(with: startDate)
          
          Task {
            try? await builder?.beginCollection(at: startDate)
          }
        }
      }, 
//      startObserveWorkout: { workoutType in
//        AsyncStream { continuation in
////          print("workoutClient: startWorkout", workoutType)
//          let configuration = HKWorkoutConfiguration()
//          configuration.activityType = workoutType
//          configuration.locationType = .outdoor
//          
//          // Create the session and obtain the workout builder.
//          do {
//            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
//            builder = session?.associatedWorkoutBuilder()
//          } catch let error {
//            print("workoutClient: catch", error)
//            return
//          }
//          
//          // Set the workout builder's data source.
//          builder?.dataSource = HKLiveWorkoutDataSource(
//            healthStore: healthStore,
//            workoutConfiguration: configuration
//          )
//          
//          let delegate = Delegate(continuation: continuation)
//          // Setup session and builder.
//          session?.delegate = delegate
//          // WorkoutBuilder
//          builder?.delegate = delegate
//          
//          print("WorkoutClient delegates set")
//          
//          continuation.onTermination = { _ in
//            _ = delegate
//          }
//          
//          // Start the workout session and begin data collection.
//          let startDate = Date()
//          session?.startActivity(with: startDate)
//          try? await builder?.beginCollection(at: startDate)
//        }
//      }, 
      pause: {
        session?.pause()
      },
      resume: {
        session?.resume()
      },
      endWorkout: {
        session?.end()
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
      print("workoutClient delegate", toState)
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
          continuation.yield(.workoutBuilderDidCollectStatistics(statistics: convert(statistics)))
        }
        
        
      }
    }
    
    fileprivate func convert(_ statistics: HKStatistics) -> Statistics {
      
      var heartRate: Double = 0
      var averageHeartRate: Double = 0
      var activeEnergy: Double = 0
      var distance: Double = 0
      
      switch statistics.quantityType {
      case HKQuantityType.quantityType(forIdentifier: .heartRate):
        let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
        heartRate = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit) ?? 0
        averageHeartRate = statistics.averageQuantity()?.doubleValue(for: heartRateUnit) ?? 0
      
      case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
        let energyUnit = HKUnit.kilocalorie()
        activeEnergy = statistics.sumQuantity()?.doubleValue(for: energyUnit) ?? 0
      
      case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning), HKQuantityType.quantityType(forIdentifier: .distanceCycling):
        let meterUnit = HKUnit.meter()
        distance = statistics.sumQuantity()?.doubleValue(for: meterUnit) ?? 0
      
      default:
        break
      }
      
      return Statistics(
        averageHeartRate: averageHeartRate,
        heartRate: heartRate,
        activeEnergy: activeEnergy,
        distance: distance,
        steps: 0
      )
    }
  }
}

extension DependencyValues {
  var workoutClient: WorkoutClient {
    get { self[WorkoutClient.self] }
    set { self[WorkoutClient.self] = newValue }
  }
}

struct Statistics: Equatable {
  var averageHeartRate: Double = 0
  var heartRate: Double = 0
  var activeEnergy: Double = 0
  var distance: Double = 0
  var steps: Int = 0
}







//static func liveWorkoutManager() -> Self {
//    
//    let workoutManager = WorkoutManager()
//    return Self(
//      startWorkout: { workoutType in
//        print("startWorkout")
//        workoutManager.selectedWorkout = workoutType
//      },
//      observeWorkoutState: {
//        AsyncStream { continuation in
//          workoutManager.updateWorkoutState = {
//            continuation.yield($0)
//          }
//        }
//      },
//      observeStatistics: {
//        
//        AsyncStream { continuation in
//          
//          workoutManager.update = { 
//            continuation.yield($0)
//          }
//          
//        }
//      },
//      togglePause: {
//        workoutManager.togglePause()
//      },
//      endWorkout: {
//        workoutManager.endWorkout()
//      }
//    )
//  }

extension HKWorkoutSessionState {
  var name: String {
    switch self {
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
    }
  }
}
