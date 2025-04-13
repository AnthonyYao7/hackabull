import AVFoundation

import CoreLocation

import Foundation

import SwiftUI

class AudioUploadService: ObservableObject {
    // Configure with your API endpoint
    private let apiURLString = "http://10.245.89.170:3000"

    /// Uploads recorded audio data directly without saving to file
    /// - Parameters:
    ///   - recorder: The audio recorder with the recorded data
    ///   - completion: Callback with result of the upload
    func uploadFromRecorder(
        _ recorder: AVAudioRecorder, completion: @escaping (Result<Data, Error>) -> Void
    ) {
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
    private func performUpload(audioData: Data, completion: @escaping (Result<Data, Error>) -> Void)
    {
        guard let url = URL(string: apiURLString + "/directions") else {
            speakMessage("Invalid URL")
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
            fatalError("Failed to serialize JSON")
        }

        request.httpBody = jsonData

        httpClient.sendRequest(request) { result in
            switch result {
            case .success(let data):
                print("Successfully sent HTML request")
                if let data_str = String(data: data, encoding: .utf8) {
                    print(data_str)
                    if let data_str_data = data_str.data(using: .utf8) {
                        do {
                            let decoded = try JSONDecoder().decode(
                                Directions.self, from: data_str_data)
                            applicationState.path = decoded
                        } catch let error as DecodingError {
                            switch error {
                            case .typeMismatch(let type, let context):
                                speakMessage("type mismatch")
                                print("Type Mismatch for type \(type): \(context.debugDescription)")
                            // print("Coding Path: \(context.codingPath)")

                            case .valueNotFound(let type, let context):
                                speakMessage(
                                    "Value not found for type")
                                print("Value not found for type \(type): \(context.debugDescription)")
                            // print("Coding Path: \(context.codingPath)")

                            case .keyNotFound(let key, let context):
//                                speakMessage("cannot find key")
                                print("Key '\(key)' not found: \(context.debugDescription)")
                            // print("Coding Path: \(context.codingPath)")

                            case .dataCorrupted(let context):
                                speakMessage("Data corrupted")
                                print("Data corrupted: \(context.debugDescription)")
                            // print("Coding Path: \(context.codingPath)")

                            @unknown default:
                                speakMessage("Unknown decoding error: \(error)")
                            }
                        } catch {
                            speakMessage("Other error: \(error)")
                        }
                    }
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
