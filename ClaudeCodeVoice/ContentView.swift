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
            
            Text("Audio Level: \(String(format: "%.2f", audioManager.audioLevel))")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            let logFile = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("ClaudeCodeVoice_debug.log")
            let logMessage = "[\(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium))] ContentView appeared\n"
            if let data = logMessage.data(using: .utf8) {
                try? data.write(to: logFile, options: .atomic)
            }
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