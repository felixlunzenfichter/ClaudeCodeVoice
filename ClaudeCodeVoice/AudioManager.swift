import AVFoundation
import SwiftUI
import Observation

@Observable
class AudioManager: NSObject {
    var audioLevel: Float = 0.0
    var isRecording = false
    
    private var audioEngine: AVAudioEngine!
    private var inputNode: AVAudioInputNode!
    private let logFile = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("ClaudeCodeVoice_debug.log")
    
    override init() {
        super.init()
        writeLog("AudioManager init")
        setupAudio()
    }
    
    private func writeLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)\n"
        
        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: logFile)
            }
        }
    }
    
    private func setupAudio() {
        writeLog("Setting up audio...")
        audioEngine = AVAudioEngine()
        inputNode = audioEngine.inputNode
        
        // Log audio device info
        let inputFormat = inputNode.inputFormat(forBus: 0)
        writeLog("Input device: \(inputNode)")
        writeLog("Input format channels: \(inputFormat.channelCount)")
        writeLog("Input format sample rate: \(inputFormat.sampleRate)")
        
        #if os(macOS)
        // Check if we can access AVCaptureDevice
        let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInMicrophone, .externalUnknown], mediaType: .audio, position: .unspecified).devices
        writeLog("Available audio devices: \(devices.count)")
        for device in devices {
            writeLog("Device: \(device.localizedName) - \(device.uniqueID)")
        }
        #endif
        
        writeLog("Audio setup complete")
    }
    
    func startRecording() {
        writeLog("Starting recording...")
        
        // Check current permission status
        #if os(macOS)
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        writeLog("Current permission status: \(status.rawValue) (0=notDetermined, 1=restricted, 2=denied, 3=authorized)")
        #endif
        
        // Try to start the audio engine directly to trigger permission dialog
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        writeLog("Recording format: \(recordingFormat)")
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
        
        do {
            try audioEngine.start()
            writeLog("Audio engine started successfully")
            DispatchQueue.main.async {
                self.isRecording = true
            }
        } catch {
            writeLog("Failed to start audio engine: \(error)")
            writeLog("Error code: \((error as NSError).code)")
            writeLog("Error domain: \((error as NSError).domain)")
            writeLog("Error localized: \(error.localizedDescription)")
            
            // Request permission and try again
            writeLog("Requesting microphone permission...")
            Task {
                await requestMicrophonePermission()
                writeLog("Permission request completed, retrying...")
                // Try again after permission
                self.retryRecording()
            }
        }
    }
    
    private func retryRecording() {
        writeLog("Retrying recording after permission...")
        
        // Remove existing tap if any
        inputNode.removeTap(onBus: 0)
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
        
        do {
            try audioEngine.start()
            writeLog("Audio engine started successfully on retry")
            DispatchQueue.main.async {
                self.isRecording = true
            }
        } catch {
            writeLog("Failed to start audio engine on retry: \(error)")
        }
    }
    
    private var bufferCount = 0
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        
        bufferCount += 1
        
        // Sample first 10 values every 100 buffers
        if bufferCount % 100 == 0 {
            var samples: [Float] = []
            for i in 0..<min(10, frameLength) {
                samples.append(channelData[0][i])
            }
            writeLog("Buffer #\(bufferCount): \(samples)")
        }
        
        var sum: Float = 0.0
        var maxSample: Float = 0.0
        for channel in 0..<channelCount {
            for frame in 0..<frameLength {
                let sample = channelData[channel][frame]
                sum += sample * sample
                maxSample = max(maxSample, abs(sample))
            }
        }
        
        let rms = sqrt(sum / Float(channelCount * frameLength))
        let avgPower = 20 * log10(max(rms, 0.00001)) // Avoid log(0)
        
        let minDb: Float = -50.0  // More sensitive
        let maxDb: Float = -5.0   // More sensitive
        let normalizedLevel = (avgPower - minDb) / (maxDb - minDb)
        
        DispatchQueue.main.async {
            self.audioLevel = max(0.0, min(1.0, normalizedLevel))
        }
        
        // Log any detected audio
        if maxSample > 0.001 {
            writeLog("Audio detected! Max sample: \(maxSample), RMS: \(rms), Power: \(avgPower) dB, Normalized: \(normalizedLevel)")
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
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        writeLog("Current microphone permission status: \(status.rawValue)")
        switch status {
        case .notDetermined:
            writeLog("Permission not determined, requesting...")
            await withCheckedContinuation { continuation in
                writeLog("Inside continuation...")
                AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                    self?.writeLog("Permission callback received: \(granted)")
                    continuation.resume()
                }
                writeLog("Request submitted")
            }
            writeLog("Permission request finished")
        case .restricted, .denied:
            writeLog("Microphone access denied or restricted")
        case .authorized:
            writeLog("Microphone access already authorized")
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