import Foundation
import HealthKit

class WorkoutManager: NSObject, ObservableObject {
  
  var update: (Statistics) -> Void = { _ in }
  var updateWorkoutState: (HKWorkoutSessionState) -> Void = { _ in }
  var selectedWorkout: HKWorkoutActivityType? {
    didSet {
      guard let selectedWorkout = selectedWorkout else { return }
      startWorkout(workoutType: selectedWorkout)
    }
  }
  
  deinit {
    print("deinited")
  }
  
  @Published var showingSummaryView: Bool = false {
    didSet {
      if showingSummaryView == false {
        resetWorkout()
      }
    }
  }
  
  let healthStore = HKHealthStore()
  var session: HKWorkoutSession?
  var builder: HKLiveWorkoutBuilder?
  
  // Start the workout.
  func startWorkout(workoutType: HKWorkoutActivityType) {
    print("workoutManager: startWorkout", workoutType)
    let configuration = HKWorkoutConfiguration()
    configuration.activityType = workoutType
    configuration.locationType = .outdoor
    
    // Create the session and obtain the workout builder.
    do {
      session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
      builder = session?.associatedWorkoutBuilder()
    } catch let error {
      print("workoutManager: catch", error)
      return
    }
    
    // Setup session and builder.
    session?.delegate = self
    builder?.delegate = self
    
    // Set the workout builder's data source.
    builder?.dataSource = HKLiveWorkoutDataSource(
      healthStore: healthStore,
      workoutConfiguration: configuration
    )
    
    // Start the workout session and begin data collection.
    let startDate = Date()
    
    session?.startActivity(with: startDate)
    builder?.beginCollection(withStart: startDate) { (success, error) in
      // The workout has started.
      print("workoutManager: builder started", success, error.debugDescription)
    }
    
    print("workoutManager: session / delegate", session.debugDescription, session?.delegate.debugDescription)
    
  }
  
  // Request authorization to access HealthKit.
  func requestAuthorization() {
    // The quantity type to write to the health store.
    let typesToShare: Set = [
      HKQuantityType.workoutType()
    ]
    
    // The quantity types to read from the health store.
    let typesToRead: Set = [
      HKQuantityType.quantityType(forIdentifier: .heartRate)!,
      HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
      HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
      HKQuantityType.quantityType(forIdentifier: .distanceCycling)!,
      HKQuantityType.quantityType(forIdentifier: .stepCount)!,
      HKQuantityType.quantityType(forIdentifier: .runningSpeed)!,
      HKObjectType.activitySummaryType()
    ]
    
    // Request authorization for those quantity types.
    healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { (success, error) in
      // Handle error.
    }
  }
  
  // MARK: - Session State Control
  
  // The app's workout state.
  @Published var running = false
  
  func togglePause() {
    if running == true {
      self.pause()
    } else {
      resume()
    }
  }
  
  func pause() {
    session?.pause()
  }
  
  func resume() {
    session?.resume()
  }
  
  func endWorkout() {
    session?.end()
    showingSummaryView = true
  }
  
  // MARK: - Workout Metrics
  @Published var averageHeartRate: Double = 0
  @Published var heartRate: Double = 0
  @Published var activeEnergy: Double = 0
  @Published var distance: Double = 0
  @Published var steps: Int = 0
  @Published var workout: HKWorkout?
  
  var workoutStartedAt: Date? = nil
  
  func updateForStatistics(_ statistics: HKStatistics?) {
    guard let statistics = statistics else { return }
    
    //        queryStepCount()
    
    DispatchQueue.main.async {
      switch statistics.quantityType {
      case HKQuantityType.quantityType(forIdentifier: .heartRate):
        let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
        self.heartRate = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit) ?? 0
        self.averageHeartRate = statistics.averageQuantity()?.doubleValue(for: heartRateUnit) ?? 0
      case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
        let energyUnit = HKUnit.kilocalorie()
        self.activeEnergy = statistics.sumQuantity()?.doubleValue(for: energyUnit) ?? 0
      case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning), HKQuantityType.quantityType(forIdentifier: .distanceCycling):
        let meterUnit = HKUnit.meter()
        self.distance = statistics.sumQuantity()?.doubleValue(for: meterUnit) ?? 0
      default:
        return
      }
      
      self.update(
        Statistics(
          //startDate: self.workoutStartedAt ?? Date(),
          //elapsedTime: Double(self.builder?.elapsedTime ?? 0.0),
          averageHeartRate: self.averageHeartRate,
          heartRate: self.heartRate,
          activeEnergy: self.activeEnergy,
          distance: self.distance
        )
      )
    }
  }
  
  func queryStepCount() {
    let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let startDate = workoutStartedAt ?? Date()
    let endDate = Date()
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
    
    let query = HKStatisticsQuery(quantityType: stepCountType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
      if let error = error {
        print("Error fetching step count: \(error.localizedDescription)")
        return
      }
      
      if let result = result, let sum = result.sumQuantity() {
        let stepCount = sum.doubleValue(for: HKUnit.count())
        DispatchQueue.main.async {
          self.steps = Int(stepCount)
        }
      }
    }
    HKHealthStore().execute(query)
  }
  
  func resetWorkout() {
    selectedWorkout = nil
    builder = nil
    workout = nil
    session = nil
    activeEnergy = 0
    averageHeartRate = 0
    heartRate = 0
    distance = 0
  }
}

// MARK: - HKWorkoutSessionDelegate
extension WorkoutManager: HKWorkoutSessionDelegate {
  func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                      from fromState: HKWorkoutSessionState, date: Date) {
    
    print("workoutManager: state changed", toState)
    
    updateWorkoutState(toState)
    
    if fromState == .notStarted && toState == .running {
      workoutStartedAt = Date()
    }
    
    DispatchQueue.main.async {
      self.running = toState == .running
    }
    
    // Wait for the session to transition states before ending the builder.
    if toState == .ended {
      builder?.endCollection(withEnd: date) { (success, error) in
        self.builder?.finishWorkout { (workout, error) in
          DispatchQueue.main.async {
            self.workout = workout
          }
        }
      }
    }
  }
  
  func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
    print("session did fail", error.localizedDescription.debugDescription)
  }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
  func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
    
  }
  
  func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
    for type in collectedTypes {
      guard let quantityType = type as? HKQuantityType else {
        return // Nothing to do.
      }
      
      let statistics = workoutBuilder.statistics(for: quantityType)
      
      // Update the published values.
      updateForStatistics(statistics)
    }
  }
}
