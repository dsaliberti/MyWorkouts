import SwiftUI

struct ElapsedTimeView: View {
  var elapsedTime = "00:00"
  
  var body: some View {
    Text(elapsedTime)
  }
}

struct ElapsedTime_Previews: PreviewProvider {
  static var previews: some View {
    ElapsedTimeView()
  }
}
