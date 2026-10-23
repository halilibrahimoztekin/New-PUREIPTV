import Foundation

public enum NetworkError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(statusCode: Int)
    case decodingFailed(description: String)
    case underlying(description: String)

    public var localizedDescription: String {
        switch self {
        case .invalidURL: AppStrings.Errors.invalidURL
        case .invalidResponse: AppStrings.Errors.invalidResponse
        case .unauthorized: AppStrings.Errors.unauthorized
        case let .serverError(code): AppStrings.Errors.serverError(code: code)
        case let .decodingFailed(desc): AppStrings.Errors.decodingFailed(desc: desc)
        case let .underlying(desc): AppStrings.Errors.underlying(desc: desc)
        }
    }
}
