import Foundation

struct VoiceCommand: Codable {
    let id: String
    let type: CommandType
    let prompt: String?
    let timestamp: Date
    
    enum CommandType: String, Codable {
        case editPrompt
        case sendPrompt
        case accept
        case reject
        case arrowUp
        case arrowDown
        case escape
        case clear
    }
}

class LocalServerManager: ObservableObject {
    @Published var isRunning = false
    private let baseURL = "http://localhost:8080"
    private let session = URLSession.shared
    
    func sendCommand(_ command: VoiceCommand) {
        guard let url = URL(string: "\(baseURL)/commands") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            request.httpBody = try encoder.encode(command)
            
            session.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error sending command: \(error)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("Command sent, status: \(httpResponse.statusCode)")
                }
            }.resume()
        } catch {
            print("Error encoding command: \(error)")
        }
    }
    
    func sendTestTranscription(_ text: String) {
        let command = VoiceCommand(
            id: UUID().uuidString,
            type: .editPrompt,
            prompt: text,
            timestamp: Date()
        )
        
        sendCommand(command)
    }
}