import SwiftUI

struct VoiceTranscriptionView: View {
    @StateObject private var transcriptionManager = OpenAITranscriptionManager()
    @StateObject private var serverManager = LocalServerManager()
    @State private var transcriptionHistory: [String] = []
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Voice Transcription")
                .font(.largeTitle)
                .padding()
            
            if let error = transcriptionManager.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
            
            VStack {
                Image(systemName: transcriptionManager.isListening ? "mic.fill" : "mic")
                    .font(.system(size: 50))
                    .foregroundColor(transcriptionManager.isListening ? .green : .gray)
                
                Text(transcriptionManager.isListening ? "Listening..." : "Tap to start")
                    .font(.headline)
            }
            .padding()
            .onTapGesture {
                toggleListening()
            }
            
            if !transcriptionManager.transcriptionText.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Current Transcription:")
                        .font(.headline)
                    
                    Text(transcriptionManager.transcriptionText)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                    
                    Button("Send to macOS App") {
                        sendTranscription()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
            }
            
            if !transcriptionHistory.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("History:")
                        .font(.headline)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(transcriptionHistory.reversed(), id: \.self) { item in
                                Text("• \(item)")
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .onReceive(transcriptionManager.$transcriptionText) { newText in
            if !newText.isEmpty && transcriptionManager.isListening {
                sendTranscription()
            }
        }
    }
    
    private func toggleListening() {
        if transcriptionManager.isListening {
            transcriptionManager.stopListening()
        } else {
            transcriptionManager.startListening()
        }
    }
    
    private func sendTranscription() {
        let text = transcriptionManager.transcriptionText
        guard !text.isEmpty else { return }
        
        serverManager.sendTestTranscription(text)
        transcriptionHistory.append(text)
        transcriptionManager.transcriptionText = ""
    }
}