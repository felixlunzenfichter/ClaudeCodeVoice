import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var audioManager = AudioManager()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Voice Activity")
                .font(.title)
                .padding()
            
            AudioLevelView(audioLevel: audioManager.audioLevel)
                .frame(height: 100)
                .padding()
            
            Text(audioManager.isRecording ? "Listening..." : "Starting...")
                .foregroundColor(audioManager.isRecording ? .green : .gray)
        }
        .padding()
        .onAppear {
            audioManager.startRecording()
        }
    }
}

struct AudioLevelView: View {
    let audioLevel: Float
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.3))
                
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.green)
                    .frame(width: geometry.size.width * CGFloat(audioLevel))
                    .animation(.linear(duration: 0.05), value: audioLevel)
            }
        }
    }
}