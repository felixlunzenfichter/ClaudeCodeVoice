import Foundation
import AVFoundation

class OpenAITranscriptionManager: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var transcriptionText = ""
    @Published var errorMessage: String?
    
    private var audioEngine = AVAudioEngine()
    private var webSocketTask: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private var clientSecret: String?
    
    override init() {
        super.init()
        requestMicrophonePermission()
    }
    
    private func requestMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if !granted {
                DispatchQueue.main.async {
                    self.errorMessage = "Microphone access denied"
                }
            }
        }
    }
    
    func startListening() {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            errorMessage = "OpenAI API key not found"
            return
        }
        
        createSession(apiKey: apiKey)
    }
    
    func stopListening() {
        isListening = false
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        webSocketTask?.cancel()
        webSocketTask = nil
    }
    
    private func createSession(apiKey: String) {
        let url = URL(string: "https://api.openai.com/v1/realtime/transcription_sessions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = """
        {
          "input_audio_transcription": {
            "model": "gpt-4o-transcribe",
            "language": "en"
          },
          "turn_detection": {
            "type": "server_vad",
            "threshold": 0.5,
            "prefix_padding_ms": 300,
            "silence_duration_ms": 500
          }
        }
        """
        request.httpBody = requestBody.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let secretObj = json["client_secret"] as? [String: Any],
                   let secretValue = secretObj["value"] as? String {
                    self.clientSecret = secretValue
                    self.connectWebSocket(clientSecret: secretValue)
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to parse session response"
                }
            }
        }.resume()
    }
    
    private func connectWebSocket(clientSecret: String) {
        let url = URL(string: "wss://api.openai.com/v1/realtime")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(clientSecret)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")
        
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        
        DispatchQueue.main.async {
            self.isListening = true
        }
        
        setupAudioEngine()
        receiveMessages()
    }
    
    private func setupAudioEngine() {
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.sendAudioBuffer(buffer: buffer)
        }
        
        do {
            try audioEngine.start()
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to start audio engine"
            }
        }
    }
    
    private func sendAudioBuffer(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameLength = Int(buffer.frameLength)
        var int16Data = [Int16](repeating: 0, count: frameLength)
        
        for i in 0..<frameLength {
            let sample = channelData[i]
            int16Data[i] = Int16(max(-32768, min(32767, sample * 32768)))
        }
        
        let data = int16Data.withUnsafeBufferPointer { Data(buffer: $0) }
        let base64Audio = data.base64EncodedString()
        
        let message = """
        {
            "type": "input_audio_buffer.append",
            "audio": "\(base64Audio)"
        }
        """
        
        webSocketTask?.send(.string(message)) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }
    
    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                if case .string(let text) = message {
                    self.handleMessage(text)
                }
                self.receiveMessages()
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.errorMessage = "WebSocket error: \(error.localizedDescription)"
                    self.stopListening()
                }
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let eventType = json["type"] as? String else { return }
        
        switch eventType {
        case "conversation.item.input_audio_transcription.completed":
            if let transcript = json["transcript"] as? String {
                DispatchQueue.main.async {
                    self.transcriptionText = transcript
                }
            }
            
        case "error":
            if let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                DispatchQueue.main.async {
                    self.errorMessage = message
                }
            }
            
        default:
            break
        }
    }
}