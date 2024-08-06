import SwiftUI
import HealthKit
import ComposableArchitecture

struct StartView: View {
  @Perception.Bindable var store: StoreOf<StartFeature>
  
  var body: some View {
    
    List(store.workoutTypes) { workoutType in
      WithPerceptionTracking {
        
//        Button {
//          store.send(.isSelectedWorkoutChanged(workoutType))
//        } label: {
//          Text(workoutType.name)
//        }
        
        NavigationLink(
          workoutType.name, 
          destination: SessionPagingView(),
          tag: workoutType, 
          selection: $store.selectedWorkout.sending(\.isSelectedWorkoutChanged)
        )
        .padding(EdgeInsets(top: 15, leading: 5, bottom: 15, trailing: 5))
      }
      .listStyle(.carousel)
      .navigationBarTitle("Workouts")
      //    .onAppear {
      //      workoutManager.requestAuthorization()
      //    }
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
