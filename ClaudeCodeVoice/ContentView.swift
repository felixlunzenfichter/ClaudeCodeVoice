import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            VoiceTranscriptionView()
                .tabItem {
                    Label("Voice", systemImage: "mic")
                }
            
            TestTranscriptionView()
                .tabItem {
                    Label("Test", systemImage: "text.cursor")
                }
        }
    }
}