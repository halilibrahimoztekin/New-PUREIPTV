import Foundation

enum ISO639LanguageCode {
    private static let validCodes = Set(Locale.isoLanguageCodes.map { $0.lowercased() })
    private static let aliases: [String: String] = [
        "english": "en", "eng": "en", "anglais": "en", "ingilizce": "en",
        "turkish": "tr", "tur": "tr", "türkçe": "tr", "turkce": "tr",
        "arabic": "ar", "ara": "ar", "العربية": "ar",
        "german": "de", "deu": "de", "ger": "de", "deutsch": "de",
        "french": "fr", "fra": "fr", "fre": "fr", "français": "fr", "francais": "fr",
        "spanish": "es", "spa": "es", "español": "es", "espanol": "es",
        "italian": "it", "ita": "it", "italiano": "it",
        "portuguese": "pt", "por": "pt", "português": "pt", "portugues": "pt",
        "russian": "ru", "rus": "ru", "русский": "ru",
        "japanese": "ja", "jpn": "ja", "日本語": "ja",
        "korean": "ko", "kor": "ko", "한국어": "ko",
        "chinese": "zh", "zho": "zh", "chi": "zh", "中文": "zh",
        "hindi": "hi", "hin": "hi", "हिन्दी": "hi", "hindi हिन्दी": "hi",
        "dutch": "nl", "nld": "nl", "dut": "nl", "nederlands": "nl",
        "swedish": "sv", "swe": "sv", "svenska": "sv",
        "polish": "pl", "pol": "pl", "polski": "pl",
        "ukrainian": "uk", "ukr": "uk", "українська": "uk",
        "greek": "el", "ell": "el", "gre": "el", "ελληνικά": "el",
        "hebrew": "he", "heb": "he", "עברית": "he",
        "thai": "th", "tha": "th", "ไทย": "th",
        "vietnamese": "vi", "vie": "vi", "tiếng việt": "vi",
        "indonesian": "id", "ind": "id", "bahasa indonesia": "id",
        "malay": "ms", "msa": "ms", "may": "ms", "bahasa melayu": "ms",
        "persian": "fa", "fas": "fa", "per": "fa", "فارسی": "fa",
        "urdu": "ur", "urd": "ur", "اردو": "ur",
        "bengali": "bn", "ben": "bn", "বাংলা": "bn",
        "romanian": "ro", "ron": "ro", "rum": "ro", "română": "ro", "romana": "ro",
        "czech": "cs", "ces": "cs", "cze": "cs", "čeština": "cs",
        "danish": "da", "dan": "da", "dansk": "da",
        "finnish": "fi", "fin": "fi", "suomi": "fi",
        "norwegian": "no", "nor": "no", "norsk": "no",
        "hungarian": "hu", "hun": "hu", "magyar": "hu",
        "bulgarian": "bg", "bul": "bg", "български": "bg",
        "croatian": "hr", "hrv": "hr", "hrvatski": "hr",
        "serbian": "sr", "srp": "sr", "српски": "sr",
        "slovak": "sk", "slk": "sk", "slo": "sk", "slovenčina": "sk",
        "slovenian": "sl", "slv": "sl", "slovenščina": "sl",
    ]

    static func normalize(_ value: String?) -> String? {
        guard let value else { return nil }
        let source = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let code = source.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? source
        if let alias = aliases[source] ?? aliases[code] {
            return alias
        }
        guard code.utf8.count == 2,
              code.utf8.allSatisfy({ (97 ... 122).contains($0) }),
              validCodes.contains(code)
        else { return nil }
        return code
    }
}
