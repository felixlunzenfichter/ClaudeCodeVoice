import SwiftUI

struct TestTranscriptionView: View {
    @StateObject private var serverManager = LocalServerManager()
    @State private var testText = ""
    @State private var transcriptionHistory: [String] = []
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Test Transcription")
                .font(.largeTitle)
                .padding()
            
            TextField("Enter test transcription", text: $testText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            Button(action: sendTranscription) {
                Label("Send to macOS App", systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .disabled(testText.isEmpty)
            
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
        .padding(.top)
    }
    
    private func sendTranscription() {
        guard !testText.isEmpty else { return }
        
        serverManager.sendTestTranscription(testText)
        transcriptionHistory.append(testText)
        testText = ""
    }
}