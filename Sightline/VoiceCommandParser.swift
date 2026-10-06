import Foundation

struct VoiceCommandParser {
    func command(from transcript: String) -> String? {
        // Ignore capitalization.
        let lowercaseText = transcript.lowercased()

        // Separate words at spaces and punctuation.
        let words = lowercaseText.split { character in
            !character.isLetter && !character.isNumber
        }

        // Only accept speech beginning with the exact word "Sightline".
        guard words.first == "sightline" else {
            return nil
        }

        // "Sightline" alone doesn't contain a command.
        guard words.count > 1 else {
            return nil
        }

        // Remove the activation phrase and return the remaining words.
        return words.dropFirst().joined(separator: " ")
    }
}
