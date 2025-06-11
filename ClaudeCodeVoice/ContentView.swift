import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var audioManager: AudioManager
    
    init() {
        let manager = AudioManager()
        _audioManager = State(initialValue: manager)
    }
    
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
            
            // Test permission request directly
            Task {
                let status = AVCaptureDevice.authorizationStatus(for: .audio)
                let statusLog = "[\(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium))] Direct test - status: \(status.rawValue)\n"
                if let data = statusLog.data(using: .utf8) {
                    if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
                }
                
                if status == .notDetermined {
                    AVCaptureDevice.requestAccess(for: .audio) { granted in
                        let grantLog = "[\(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium))] Direct test - granted: \(granted)\n"
                        if let data = grantLog.data(using: .utf8) {
                            if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
                        }
                    }
                }
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