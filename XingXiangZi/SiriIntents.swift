import Foundation

/// Normalize a string to Simplified Chinese for matching across SC/TC variants.
func toSimplified(_ text: String) -> String {
    let mutable = NSMutableString(string: text)
    CFStringTransform(mutable, nil, "Traditional-Simplified" as CFString, false)
    return mutable as String
}

/// Check if `text` contains `query`, matching across Simplified/Traditional Chinese.
func fuzzyContains(_ text: String, _ query: String) -> Bool {
    let sText = toSimplified(text)
    let sQuery = toSimplified(query)
    return sText.contains(sQuery)
}

