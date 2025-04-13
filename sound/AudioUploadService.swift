import Foundation
import AVFoundation
import CoreLocation

class AudioUploadService {
    // Configure with your API endpoint
    private let apiURLString = "http://10.245.89.170:3000"
    
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
    private func performUpload(audioData: Data, completion: @escaping (Result<Data, Error>) -> Void) -> Void {
        guard let url = URL(string: apiURLString + "/directions") else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        //        request.setValue("audio/m4a", forHTTPHeaderField: "Content-Type")
        //        request.setValue("\(audioData.count)", forHTTPHeaderField: "Content-Length")
        //        request.httpBody = audioData
        
        let base64String = audioData.base64EncodedString()
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        guard let location = locationService.getCurrentLocation() else {
            return
        }
        
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        
        let data = ["audio": base64String, "latitude": String(lat), "longitude": String(lon)]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: data, options: []) else {
            fatalError("Failed to serialize JSON");
        }
        
        request.httpBody = jsonData
        
        httpClient.sendRequest(request) { result in
            switch result {
            case .success(let data):
                print("Successfully")
                if let data_str = String(data: data, encoding: .utf8) {
                    print(data_str)
                }
                DispatchQueue.main.async {
                    completion(.success(data))
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
            print(result)
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

