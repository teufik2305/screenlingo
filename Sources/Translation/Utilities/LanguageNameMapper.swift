import Foundation

/// Utility for mapping language codes to display names
enum LanguageNameMapper {
    private static let languageNames: [String: String] = [
        "ar": "Arabic", "zh": "Chinese", "zh-Hans": "Simplified Chinese", "zh-Hant": "Traditional Chinese",
        "nl": "Dutch", "en": "English", "fr": "French", "de": "German", "hi": "Hindi",
        "id": "Indonesian", "it": "Italian", "ja": "Japanese", "ko": "Korean", "pl": "Polish",
        "pt": "Portuguese", "pt-BR": "Brazilian Portuguese", "ru": "Russian",
        "sr": "Serbian", "sr-Latn": "Serbian (Latin)", "es": "Spanish", "th": "Thai",
        "tr": "Turkish", "uk": "Ukrainian", "vi": "Vietnamese",
        "bs": "Bosnian", "hr": "Croatian", "cs": "Czech", "da": "Danish", "fi": "Finnish",
        "el": "Greek", "he": "Hebrew", "hu": "Hungarian", "no": "Norwegian", "ro": "Romanian",
        "sk": "Slovak", "sl": "Slovenian", "sv": "Swedish", "bg": "Bulgarian", "et": "Estonian",
        "lv": "Latvian", "lt": "Lithuanian", "mt": "Maltese", "ga": "Irish"
    ]
    
    /// Get display name for language code
    static func displayName(for code: String) -> String {
        languageNames[code] ?? code.uppercased()
    }
}
