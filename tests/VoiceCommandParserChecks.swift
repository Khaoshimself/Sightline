import Foundation

@main
struct ParserChecks {
    static func main() {
        let parser = VoiceCommandParser()
        var count = 0
        let accepted: [(String, String)] = [
            ("Sightline, describe the scene", "describe the scene"),
            ("SIGHTLINE what's ahead?", "what s ahead"),
            ("Say and describe the scene Sightline describe the scene", "describe the scene"),
            ("Sightline find me a chair Sightline stop", "stop"),
            ("Sightline stop walking mode", "stop walking mode"),
        ]
        for (text, expected) in accepted {
            precondition(parser.command(from: text) == expected)
            precondition(parser.isSupportedCommand(expected))
            count += 2
        }
        for target in ["chair", "person", "bottle", "backpack", "car"] {
            let command = parser.command(from: "Sightline, find me a \(target)")!
            precondition(parser.target(from: command) == target)
            count += 1
        }
        for text in ["describe the scene", "Sideline find me a chair", "Sightline", "Sightline stop Sightline"] {
            precondition(parser.command(from: text) == nil)
            count += 1
        }
        for command in ["find me a chair and then a bottle", "stopwatch", "describe the scenery", "find me a wall", "find me a"] {
            precondition(!parser.isSupportedCommand(command))
            count += 1
        }
        // The same words are valid again in a fresh recognition session.
        for _ in 0..<3 {
            precondition(parser.command(from: "Sightline find me a chair") == "find me a chair")
            count += 1
        }
        print("Passed \(count) voice-command checks.")
    }
}
