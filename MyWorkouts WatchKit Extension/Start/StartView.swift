import SwiftUI
import HealthKit
import ComposableArchitecture

struct StartView: View {
  @Perception.Bindable var store: StoreOf<StartFeature>
  
  var body: some View {
    WithPerceptionTracking {
      NavigationStack {
        List(store.workoutTypes) { workoutType in
          Button {
            store.send(.isSelectedWorkoutChanged(workoutType))
          } label: {
            Text(workoutType.name)
          }
          .padding(EdgeInsets(top: 15, leading: 5, bottom: 15, trailing: 5))
          .listStyle(.carousel)
          .navigationBarTitle("Workouts")
          //    .onAppear {
          //      workoutManager.requestAuthorization()
          //    }
        }
        .navigationDestination(item: $store.scope(state: \.session, action: \.session)) { store in 
          SessionPagingView(store: store)
        }
      }
      .navigationBarHidden(true)
    }
  }
}

extension HKWorkoutActivityType: Identifiable {
  public var id: UInt {
    rawValue
  }
  
  var name: String {
    switch self {
    case .running:
      return "Run"
    case .cycling:
      return "Bike"
    case .walking:
      return "Walk"
    default:
      return ""
    }
  }
}


#Preview {
  StartView(
    store: StoreOf<StartFeature>(
      initialState: StartFeature.State(), 
      reducer: { StartFeature() }
    )
  )
}
