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
    
    var cadence: Double {
        Double(workoutManager.steps) / max(Double(Int((workoutManager.builder?.elapsedTime ?? 0) / 60)), 1.0)
    }
    
    var minutes: Int {
        Int((workoutManager.builder?.elapsedTime ?? 0) / 60)
    }
    
    @State private var timeFormatter = ElapsedTimeFormatter(showSubseconds: false, suffix: "/km")
    
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
                    showSubseconds: false //context.cadence == .live
                )
                .font(.title2)
                .foregroundStyle(.yellow)
                .padding(.leading, 16)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: .zero) {
                        /// Energy `0 Kcal` 
                        Text(
                            Measurement(
                                value: max(0, workoutManager.activeEnergy), unit: UnitEnergy.kilocalories
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
                        
                        /// HR `0 BPM`
                        Text(
                            workoutManager.heartRate.formatted(
                                .number.precision(
                                    .fractionLength(0)
                                )
                            ) + " bpm"
                        )
                        
                        /// Distance
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
                        
                        /// Live Pace `00:00/Km`
                        Text(NSNumber(value: pace), formatter: timeFormatter)
                        
                        /// Average Pace 
                        Text("avg pace")
                        
                        /// Cadence: number of steps per minute
                        /// stride frequency, step frequency, foot turnover
                        Text("\(workoutManager.steps/max(1,minutes), specifier: "%d steps/min")")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                
            }
            .font(.system(.title2, design: .rounded).monospacedDigit().lowercaseSmallCaps())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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
