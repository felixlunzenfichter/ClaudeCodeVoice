import AVFoundation
import SwiftUI

class AudioManager: NSObject, ObservableObject {
    @Published var audioLevel: Float = 0.0
    @Published var isRecording = false
    
    private var audioEngine: AVAudioEngine!
    private var inputNode: AVAudioInputNode!
    private var audioSession: AVAudioSession!
    
    override init() {
        super.init()
        setupAudio()
    }
    
    private func setupAudio() {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine.inputNode
        audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.record, mode: .measurement)
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    func startRecording() {
        Task {
            await requestMicrophonePermission()
            
            guard AVAudioSession.sharedInstance().recordPermission == .granted else {
                print("Microphone permission not granted")
                return
            }
            
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.processAudioBuffer(buffer)
            }
            
            do {
                try audioEngine.start()
                DispatchQueue.main.async {
                    self.isRecording = true
                }
            } catch {
                print("Failed to start audio engine: \(error)")
            }
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        
        var sum: Float = 0.0
        for channel in 0..<channelCount {
            for frame in 0..<frameLength {
                let sample = channelData[channel][frame]
                sum += sample * sample
            }
        }
        
        let rms = sqrt(sum / Float(channelCount * frameLength))
        let avgPower = 20 * log10(rms)
        
        let minDb: Float = -80.0
        let maxDb: Float = -10.0
        let normalizedLevel = (avgPower - minDb) / (maxDb - minDb)
        
        DispatchQueue.main.async {
            self.audioLevel = max(0.0, min(1.0, normalizedLevel))
        }
    }
    
    private func requestMicrophonePermission() async {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .undetermined:
            await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { _ in
                    continuation.resume()
                }
            }
        case .denied:
            print("Microphone access denied")
        case .granted:
            print("Microphone access granted")
        @unknown default:
            break
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        inputNode.removeTap(onBus: 0)
        isRecording = false
    }
    
    deinit {
        stopRecording()
    }
}