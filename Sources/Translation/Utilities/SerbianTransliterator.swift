import Foundation

/// Utility for transliterating Serbian Cyrillic to Latin script
enum SerbianTransliterator {
    // Serbian Cyrillic to Latin transliteration map
    private static let cyrillicToLatin: [Character: String] = [
        "А": "A", "Б": "B", "В": "V", "Г": "G", "Д": "D", "Ђ": "Đ", "Е": "E", "Ж": "Ž",
        "З": "Z", "И": "I", "Ј": "J", "К": "K", "Л": "L", "Љ": "Lj", "М": "M", "Н": "N",
        "Њ": "Nj", "О": "O", "П": "P", "Р": "R", "С": "S", "Т": "T", "Ћ": "Ć", "У": "U",
        "Ф": "F", "Х": "H", "Ц": "C", "Ч": "Č", "Џ": "Dž", "Ш": "Š",
        "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "ђ": "đ", "е": "e", "ж": "ž",
        "з": "z", "и": "i", "ј": "j", "к": "k", "л": "l", "љ": "lj", "м": "m", "н": "n",
        "њ": "nj", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "ћ": "ć", "у": "u",
        "ф": "f", "х": "h", "ц": "c", "ч": "č", "џ": "dž", "ш": "š"
    ]
    
    /// Convert Serbian Cyrillic text to Latin script
    static func toLatin(_ text: String) -> String {
        var result = ""
        for char in text {
            if let latin = cyrillicToLatin[char] {
                result += latin
            } else {
                result.append(char)
            }
        }
        return result
    }
    
    /// Check if text contains Serbian Cyrillic characters
    static func containsCyrillic(_ text: String) -> Bool {
        text.contains { cyrillicToLatin[$0] != nil }
    }
}
