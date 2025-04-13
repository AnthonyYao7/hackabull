//
//  HTTPRequest.swift
//  sound
//
//  Created by Cole Smith on 4/13/25.
//

import Foundation

protocol HTTPClient {
    func sendRequest(_ request: URLRequest, completion: @escaping (Result<Data, Error>) -> Void)
}

enum HTTPClientError: Error {
    case invalidResponse
    case serverError(statusCode: Int)
    case noData
}

final class DefaultHTTPClient: HTTPClient {
    func sendRequest(_ request: URLRequest, completion: @escaping (Result<Data, Error>) -> Void) {
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(HTTPClientError.invalidResponse))
                }
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                DispatchQueue.main.async {
                    completion(.failure(HTTPClientError.serverError(statusCode: httpResponse.statusCode)))
                }
                return
            }
            
            DispatchQueue.main.async {
                if let data = data {
                    completion(.success(data))
                } else {
                    completion(.failure(HTTPClientError.noData))
                }
            }
        }
        
        task.resume()
    }
}


