import Foundation

public extension String {
    /// Returns the localized string from the main bundle / Localizable.xcstrings.
    /// Usage: `"İptal".localized`
    var localized: String {
        NSLocalizedString(self, comment: "")
    }

    /// Returns the localized string from a specific bundle or table.
    func localized(in bundle: Bundle = .main, tableName: String? = nil) -> String {
        NSLocalizedString(self, tableName: tableName, bundle: bundle, comment: "")
    }

    /// Returns the localized string formatted with positional arguments.
    /// Usage: `"Hata: %@".localized(errorMessage)`
    func localized(_ arguments: CVarArg...) -> String {
        let format = NSLocalizedString(self, comment: "")
        return String(format: format, locale: Locale.current, arguments: arguments)
    }

    /// Returns the localized string formatted with positional arguments and specified bundle/table.
    func localized(in bundle: Bundle = .main, tableName: String? = nil, _ arguments: CVarArg...) -> String {
        let format = NSLocalizedString(self, tableName: tableName, bundle: bundle, comment: "")
        return String(format: format, locale: Locale.current, arguments: arguments)
    }
}

public extension Substring {
    /// Returns the localized string from the substring.
    var localized: String {
        String(self).localized
    }
}
