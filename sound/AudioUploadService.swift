import Foundation
import AVFoundation

class AudioUploadService {
    // Configure with your API endpoint
    private let apiURLString = "http://10.245.89.170:3000"
    private let apiURL = URL(string: "http://10.245.89.170:3000")!
    
    /// Uploads recorded audio data directly without saving to file
    /// - Parameters:
    ///   - recorder: The audio recorder with the recorded data
    ///   - completion: Callback with result of the upload
    func uploadFromRecorder(_ recorder: AVAudioRecorder, completion: @escaping (Result<Data, Error>) -> Void) {
        let url = recorder.url
        
        do {
            let audioData = try Data(contentsOf: url)
            performUpload(audioData: audioData, completion: completion)
            
            // Optional: Delete temp file after upload
            try FileManager.default.removeItem(at: url)
        } catch {
            completion(.failure(error))
        }
    }
    
    // MARK: - Private methods
    private func performUpload(audioData: Data, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let url = URL(string: apiURLString + "/setDestination") else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
//        request.setValue("audio/m4a", forHTTPHeaderField: "Content-Type")
//        request.setValue("\(audioData.count)", forHTTPHeaderField: "Content-Length")
//        request.httpBody = audioData
        
        let base64String = audioData.base64EncodedString()
        guard let base64Data = base64String.data(using: .utf8) else {
            completion(.failure(AudioUploadError.conversionFailed))
            return
        }
                
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.setValue("\(base64Data.count)", forHTTPHeaderField: "Content-Length")
        request.httpBody = base64Data
        
        let httpClient: HTTPClient = DefaultHTTPClient()
        
        httpClient.sendRequest(request) { result in
            switch result {
            case .success(let data):
                DispatchQueue.main.async {
                    completion(.success(data))
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Errors
    
    enum AudioUploadError: Error {
        case conversionFailed
        case noRecordingFound
        case invalidResponse
        case serverError(statusCode: Int)
        case noData
    }
}

