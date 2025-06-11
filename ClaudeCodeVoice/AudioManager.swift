import AVFoundation
import SwiftUI
import Observation

@Observable
class AudioManager: NSObject {
    var audioLevel: Float = 0.0
    var isRecording = false
    
    private var audioEngine: AVAudioEngine!
    private var inputNode: AVAudioInputNode!
    
    override init() {
        super.init()
        print("AudioManager init")
        setupAudio()
    }
    
    private func setupAudio() {
        print("Setting up audio...")
        audioEngine = AVAudioEngine()
        inputNode = audioEngine.inputNode
        print("Audio setup complete")
    }
    
    func startRecording() {
        Task {
            print("Starting recording...")
            await requestMicrophonePermission()
            
            guard await checkMicrophonePermission() else {
                print("Microphone permission not granted")
                return
            }
            
            print("Permission granted, setting up audio...")
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            print("Recording format: \(recordingFormat)")
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.processAudioBuffer(buffer)
            }
            
            do {
                try audioEngine.start()
                print("Audio engine started successfully")
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
        
        let minDb: Float = -60.0
        let maxDb: Float = -10.0
        let normalizedLevel = (avgPower - minDb) / (maxDb - minDb)
        
        DispatchQueue.main.async {
            self.audioLevel = max(0.0, min(1.0, normalizedLevel))
            if normalizedLevel > 0.01 {
                print("Audio level: \(normalizedLevel), RMS: \(rms), Power: \(avgPower) dB")
            }
        }
    }
    
    private func checkMicrophonePermission() async -> Bool {
        #if os(macOS)
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined, .denied, .restricted:
            return false
        @unknown default:
            return false
        }
        #else
        if #available(iOS 17.0, *) {
            return AVAudioApplication.shared.recordPermission == .granted
        } else {
            return AVAudioSession.sharedInstance().recordPermission == .granted
        }
        #endif
    }
    
    private func requestMicrophonePermission() async {
        #if os(macOS)
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    print("Microphone permission granted: \(granted)")
                    continuation.resume()
                }
            }
        case .restricted, .denied:
            print("Microphone access denied or restricted")
        case .authorized:
            print("Microphone access already authorized")
        @unknown default:
            break
        }
        #else
        if #available(iOS 17.0, *) {
            let permission = AVAudioApplication.shared.recordPermission
            switch permission {
            case .undetermined:
                await withCheckedContinuation { continuation in
                    AVAudioApplication.requestRecordPermissionWithCompletionHandler { _ in
                        continuation.resume()
                    }
                }
            case .denied:
                print("Microphone access denied")
            case .granted:
                print("Microphone access granted")
            default:
                break
            }
        } else {
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
        #endif
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