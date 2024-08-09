import SwiftUI
import HealthKit
import ComposableArchitecture

struct MetricsView: View {
  
  let store: StoreOf<MetricsFeature>
  
  var body: some View {
    WithPerceptionTracking {
      TimelineView(
        MetricsTimelineSchedule(
          from: store.startDate,
          isPaused: store.isPaused
        )
      ) { context in
        
        VStack(alignment: .leading, spacing: .zero) {
          
          ElapsedTimeView(elapsedTime: store.elapsedTime)
            .fontWeight(.semibold)
            .font(.title2)
            .foregroundStyle(.yellow)
            .padding(.leading, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
          
          
          ScrollView {
            VStack(alignment: .leading, spacing: .zero) {
              
              ForEach(store.configuration, id:\.hashValue) { component in
                
                let value: String = switch component {
                case .energy:
                  store.energy
                  
                case .heartRate:
                  store.heartRate
                  
                case .distance:
                  store.distance
                  
                case .paceSplit:
                  store.paceSplit
                  
                case .paceAverage:
                  store.paceAverage
                  
                case.cadence:
                  store.cadence
                  
                }
                
                Text(value)
              }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
          
        }
        .font(.system(.title3, design: .rounded).monospacedDigit().lowercaseSmallCaps())
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(0)
        .task {
          store.send(.task)
        }
      }
    }  
  }
}

#Preview {
  MetricsView(
    store: StoreOf<MetricsFeature>(
      initialState: MetricsFeature.State(
        elapsedTime: "00:33.33",
        energy: "729 Kcal",
        heartRate: "110 BPM",
        distance: "17 Km",
        paceSplit: "05:32/Km split",
        paceAverage: "04:31/Km avg",
        cadence: "37 steps/min",
        startDate: Date(),
        isPaused: false
      ),
      reducer: { MetricsFeature() }
    )
  )
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
