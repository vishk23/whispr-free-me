import Foundation

/// Decides whether a pasted transcript needs a leading space so mid-text dictation
/// doesn't jam against the existing content ("wordword"). The caller supplies the
/// character immediately before the insertion point (via Accessibility); nil means
/// document start or unreadable context, where today's no-space behavior is kept.
public enum SmartSpacing {
    static let openers: Set<Character> = [
        "(", "[", "{", "<", "\"", "'", "\u{201C}", "\u{2018}", "/", "\\", "@", "#", "$", "-", "\u{2013}", "\u{2014}"
    ]

    public static func needsLeadingSpace(precedingCharacter: Character?, transcript: String) -> Bool {
        guard let preceding = precedingCharacter else { return false }
        guard let first = transcript.first, first.isLetter || first.isNumber else { return false }
        if preceding.isWhitespace || preceding.isNewline { return false }
        if openers.contains(preceding) { return false }
        return true
    }
}
