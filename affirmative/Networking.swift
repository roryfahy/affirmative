import Foundation
import AVFoundation
import Combine

class TextToSpeechViewModel: NSObject, ObservableObject {
    @Published var audioPlayer: AVAudioPlayer?
    var affirmationsQueue: [String] = []
    var currentIndex: Int = 0
    
    func playNextAffirmation() {
        if currentIndex < affirmationsQueue.count {
            let nextText = affirmationsQueue[currentIndex]
            submitText(text: nextText)
            currentIndex += 1
        }
    }
    
    func submitText(text: String) {
        guard !text.isEmpty else { return }
        
        let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/lbvFI6iCxgrMNmHeR1jV?optimize_streaming_latency=0&output_format=mp3_44100_128")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("audio/mpeg", forHTTPHeaderField: "accept")
        request.addValue("<key>", forHTTPHeaderField: "xi-api-key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_multilingual_v2",
            "voice_settings": [
                "stability": 0,
                "similarity_boost": 0,
                "style": 0,
                "use_speaker_boost": true
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] (data, response, error) in
            guard let data = data else { return }
            
            // Debug prints
            print("Received data of length: \(data.count)")
            if let httpResponse = response as? HTTPURLResponse {
                print("Content-Type: \(httpResponse.allHeaderFields["Content-Type"] ?? "")")
            }
            
            do {
                let player = try AVAudioPlayer(data: data)
                player.delegate = self
                DispatchQueue.main.async {
                    self?.audioPlayer = player
                    self?.audioPlayer?.play()
                }
            } catch {
                print("Audio playback failed: \(error)")
            }
        }
        
        task.resume()
    }
    
    func fetchAndSubmitAffirmations(input: String) {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer <key>", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "model": "gpt-4",
            "messages": [
                [
                    "role": "system",
                    "content": "the only thing that you should return to the user is a list of 5 possible bullet points for affirmations that may help the user.  These will be received via a program api call so please format them as a logical body\n\nencode the list as a json array with the schema\n{\"affirmations\": [affirmations]}"
                ],
                [
                    "role": "user",
                    "content": "I need help coming up with affirmations that will help me counteract my negative that I've been having.  This belief is that \(input)"
                ]
            ],
            "temperature": 1,
            "max_tokens": 256,
            "top_p": 1,
            "frequency_penalty": 0,
            "presence_penalty": 0
        ]

        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] (data, response, error) in
            guard let data = data else { return }
            // Parse and extract affirmations
            
            if let parsedData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = parsedData["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let contentString = message["content"] as? String,
               let contentData = contentString.data(using: .utf8),
               let contentJSON = try? JSONSerialization.jsonObject(with: contentData) as? [String: [String]],
               let affirmations = contentJSON["affirmations"] {
                print("Affirmations: \(affirmations)")
                self?.affirmationsQueue = affirmations
                self?.currentIndex = 0
                self?.playNextAffirmation()
                }
            }
        task.resume()
    }
}

extension TextToSpeechViewModel: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playNextAffirmation()
    }
}
