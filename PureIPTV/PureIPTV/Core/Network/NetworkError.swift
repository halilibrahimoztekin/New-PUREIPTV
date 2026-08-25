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
        case .invalidURL: return "Geçersiz URL adresi."
        case .invalidResponse: return "Sunucudan geçersiz yanıt alındı."
        case .unauthorized: return "Kullanıcı adı veya şifre hatalı."
        case let .serverError(code): return "Sunucu hatası (Kod: \(code))."
        case let .decodingFailed(desc): return "Veri işlenemedi: \(desc)"
        case let .underlying(desc): return "Bir hata oluştu: \(desc)"
        }
    }
}
