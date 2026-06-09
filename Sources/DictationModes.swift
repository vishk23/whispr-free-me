import Foundation

enum DictationMode: String {
    case standard, formal, code, casual

    /// Human-readable label shown in the recording overlay badge.
    /// nil for `.standard` so the badge is hidden in the default mode.
    var displayName: String? {
        switch self {
        case .standard: return nil
        case .formal:   return "Formal"
        case .code:     return "Code"
        case .casual:   return "Casual"
        }
    }

    /// SF Symbol name used alongside `displayName` in the overlay badge.
    var iconName: String {
        switch self {
        case .standard: return "text.alignleft"
        case .formal:   return "envelope"
        case .code:     return "chevron.left.forwardslash.chevron.right"
        case .casual:   return "bubble.left"
        }
    }

    var promptSnippet: String {
        switch self {
        case .standard:
            return ""
        case .formal:
            return "\n\nThis text is going into an email or a formal document. Use complete sentences, correct capitalization and punctuation, and a professional tone. Do not invent a greeting or sign-off that was not spoken."
        case .code:
            return "\n\nThis text is going into a code editor or terminal. Preserve code, commands, file paths, symbols, and technical terms exactly as spoken. Do not add prose-style capitalization or trailing punctuation to code. Keep it terse."
        case .casual:
            return "\n\nThis is a casual chat/IM message. Keep it short and informal; lowercase is fine, minimal punctuation, no greeting or sign-off, and preserve the casual tone."
        }
    }
}

enum DictationModes {
    // Default ON when the key has never been set
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "contentAwareModesEnabled") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "contentAwareModesEnabled")
    }

    static func mode(forBundleId id: String?) -> DictationMode {
        guard let id else { return .standard }
        let lower = id.lowercased()

        if lower.contains("mail") || lower.contains("outlook") || lower.contains("spark")
            || lower.contains("airmail") {
            return .formal
        }

        if lower.contains("xcode") || lower.contains("terminal") || lower.contains("iterm")
            || lower.contains("vscode") || lower.contains("cursor") || lower.contains("ghostty")
            || lower.contains("warp") || lower.contains("sublime") || lower.contains("jetbrains")
            || lower.contains("nova") {
            return .code
        }

        if lower.contains("messages") || lower.contains("mobilesms") || lower.contains("ichat")
            || lower.contains("slack") || lower.contains("discord") || lower.contains("whatsapp")
            || lower.contains("telegram") || lower.contains("signal") {
            return .casual
        }

        return .standard
    }
}
