import Foundation
import AVFoundation

class AudioUploadService {
    // Configure with your API endpoint
    private let apiURL = URL(string: "http://10.245.91.204:3000")!
    
    /// Uploads audio data directly from a buffer without saving to file
    /// - Parameters:
    ///   - buffer: The audio PCM buffer to upload
    ///   - format: The audio format information
    ///   - completion: Callback with result of the upload
    func uploadAudioBuffer(_ buffer: AVAudioPCMBuffer, format: AVAudioFormat, completion: @escaping (Result<Data, Error>) -> Void) {
        // Convert audio buffer to data
        guard let audioData = convertBufferToCompressedFormat(buffer, format: format) else {
            completion(.failure(AudioUploadError.conversionFailed))
            return
        }
        
        performUpload(audioData: audioData, completion: completion)
    }
    
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
    
    /// Directly records and uploads audio without saving to file
    /// - Parameters:
    ///   - duration: How long to record in seconds
    ///   - completion: Callback with result of the upload
    func recordAndUpload(duration: TimeInterval = 5.0, completion: @escaping (Result<Data, Error>) -> Void) {
        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        // Create a buffer to hold the audio data
        var audioBuffer = Data()
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, time in
            // Convert AVAudioPCMBuffer to Data and append to our buffer
            if let channelData = buffer.floatChannelData?[0] {
                let frameLength = Int(buffer.frameLength)
                let data = Data(bytes: channelData, count: frameLength * MemoryLayout<Float>.size)
                audioBuffer.append(data)
            }
        }
        
        do {
            try audioEngine.start()
            
            // Record for specified duration
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                // Convert and compress the audio data
                guard let compressedData = self.compressAudioData(audioBuffer, format: format) else {
                    completion(.failure(AudioUploadError.conversionFailed))
                    return
                }
                
                self.performUpload(audioData: compressedData, completion: completion)
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    // MARK: - Private methods
    
    private func performUpload(audioData: Data, completion: @escaping (Result<Data, Error>) -> Void) {
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("audio/m4a", forHTTPHeaderField: "Content-Type")
        request.setValue("\(audioData.count)", forHTTPHeaderField: "Content-Length")
        request.httpBody = audioData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(AudioUploadError.invalidResponse))
                }
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                DispatchQueue.main.async {
                    completion(.failure(AudioUploadError.serverError(statusCode: httpResponse.statusCode)))
                }
                return
            }
            
            DispatchQueue.main.async {
                if let data = data {
                    completion(.success(data))
                } else {
                    completion(.failure(AudioUploadError.noData))
                }
            }
        }
        
        task.resume()
    }
    
    private func convertBufferToCompressedFormat(_ buffer: AVAudioPCMBuffer, format: AVAudioFormat) -> Data? {
        // This is a simplified version - in a real implementation, you would use
        // AVAudioConverter to convert the buffer to compressed format like AAC
        // This is a complex process that typically involves multiple steps
        
        // For demonstration purposes, we'll create a mock conversion
        // In a real app, you'd implement proper audio conversion here
        guard let channelData = buffer.floatChannelData else { return nil }
        let frames = Int(buffer.frameLength)
        let channels = Int(format.channelCount)
        
        var pcmData = Data()
        for channel in 0..<channels {
            let channelPtr = channelData[channel]
            pcmData.append(Data(bytes: channelPtr, count: frames * MemoryLayout<Float>.size))
        }
        
        // In reality, you would compress this data to AAC or another format
        return pcmData
    }
    
    private func compressAudioData(_ data: Data, format: AVAudioFormat) -> Data? {
        // In a real implementation, you would compress the raw PCM data to AAC or another format
        // This is a complex process that would use AVAudioConverter or other audio processing APIs
        
        // For demonstration purposes, we'll just return the original data
        // In a real app, implement proper audio compression here
        return data
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
