/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 The workout metrics view.
 */

import SwiftUI
import HealthKit

struct MetricsView: View {
  @EnvironmentObject var workoutManager: WorkoutManager
  
  var pace: Double {
    workoutManager.distance > 0
    ? Double(workoutManager.builder?.elapsedTime ?? 0.0) /  workoutManager.distance
    : Double(0)
  }
  
  @State private var timeFormatter = ElapsedTimeFormatter(showSubseconds: true, suffix: "/km")
  
  var body: some View {
    TimelineView(
      MetricsTimelineSchedule(
        from: workoutManager.builder?.startDate ?? Date(),
        isPaused: workoutManager.session?.state == .paused
      )
    ) { context in
      
      VStack(alignment: .leading, spacing: .zero) {
        ElapsedTimeView(
          elapsedTime: workoutManager.builder?.elapsedTime(at: context.date) ?? 0, 
          showSubseconds: context.cadence == .live
        )
        .foregroundStyle(.yellow)
        .padding([.top, .leading], 16)
        
        ScrollView {
          VStack(alignment: .leading, spacing: .zero) {
            Text(
              Measurement(
                value: workoutManager.activeEnergy, unit: UnitEnergy.kilocalories
              )
              .formatted(
                .measurement(
                  width: .abbreviated,
                  usage: .workout,
                  numberFormatStyle: .number.precision(
                    .fractionLength(0)
                  )
                )
              )
            )
            
            Text(
              workoutManager.heartRate.formatted(
                .number.precision(
                  .fractionLength(0)
                )
              ) + " bpm"
            )
            
            Text(
              Measurement(
                value: workoutManager.distance, 
                unit: UnitLength.meters
              )
              .formatted(
                .measurement(
                  width: .abbreviated,
                  usage: .road
                )
              )
            )
            
            
            Text(NSNumber(value: pace), formatter: timeFormatter)
            
            Text("avg pace")
            Text("cadence")
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
          .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      }
      .font(.system(.title, design: .rounded).monospacedDigit().lowercaseSmallCaps())
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      .ignoresSafeArea()
      .padding(0)
      
      
    }
  }
}

struct MetricsView_Previews: PreviewProvider {
  static var previews: some View {
    MetricsView().environmentObject(WorkoutManager())
  }
}

private struct MetricsTimelineSchedule: TimelineSchedule {
  var startDate: Date
  var isPaused: Bool
  
  init(from startDate: Date, isPaused: Bool) {
    self.startDate = startDate
    self.isPaused = isPaused
  }
  
  func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
    
    var baseSchedule = PeriodicTimelineSchedule(
      from: self.startDate,
      by: (mode == .lowFrequency ? 1.0 : 1.0 / 30.0)
    )
      .entries(from: startDate, mode: mode)
    
    return AnyIterator<Date> {
      guard !isPaused else { return nil }
      return baseSchedule.next()
    }
  }
}
