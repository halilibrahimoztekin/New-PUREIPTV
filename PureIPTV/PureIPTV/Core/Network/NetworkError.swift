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
        case .invalidURL: "Geçersiz URL adresi."
        case .invalidResponse: "Sunucudan geçersiz yanıt alındı."
        case .unauthorized: "Kullanıcı adı veya şifre hatalı."
        case let .serverError(code): "Sunucu hatası (Kod: \(code))."
        case let .decodingFailed(desc): "Veri işlenemedi: \(desc)"
        case let .underlying(desc): "Bir hata oluştu: \(desc)"
        }
    }
}
