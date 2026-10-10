import Foundation

struct VoiceCommandParser {
    func command(from transcript: String) -> String? {
        let words = transcript.lowercased().split {
            !$0.isLetter && !$0.isNumber
        }

        // Earlier speech can precede the command in a running transcript.
        guard let wakeIndex = words.lastIndex(of: "sightline") else {
            return nil
        }

        let commandWords = words.dropFirst(wakeIndex + 1)
        guard !commandWords.isEmpty else { return nil }
        return commandWords.joined(separator: " ")
    }

    func isSceneDescription(_ command: String) -> Bool {
        [
            "describe",
            "describe the scene",
            "describe what is ahead",
            "describe what s ahead",
            "describe whats ahead",
            "what is ahead",
            "what s ahead",
            "whats ahead",
        ].contains(command)
    }

    func isStop(_ command: String) -> Bool {
        [
            "stop",
            "stop walking",
            "stop walking mode",
        ].contains(command)
    }

    func target(from command: String) -> String? {
        let prefixes = [
            "find me a ",
            "find me the ",
            "find me ",
            "find a ",
            "find the ",
            "find ",
        ]

        guard let prefix = prefixes.first(
            where: { command.hasPrefix($0) }
        ) else {
            return nil
        }

        let target = String(command.dropFirst(prefix.count))

        let objects = [
            "chair",
            "person",
            "bottle",
            "backpack",
            "car",
        ]

        return objects.contains(target) ? target : nil
    }

    func isSupportedCommand(_ command: String) -> Bool {
        isStop(command)
            || isSceneDescription(command)
            || target(from: command) != nil
    }
}
