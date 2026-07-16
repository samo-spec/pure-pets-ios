import Foundation

enum NovaSpeechTextSanitizer {
    static func sanitize(_ text: String) -> String {
        var output = text
        output = output.replacingOccurrences(
            of: #"```[\s\S]*?```"#,
            with: " ",
            options: .regularExpression
        )
        output = output.replacingOccurrences(
            of: #"\[([^\]]+)\]\([^)]+\)"#,
            with: "$1",
            options: .regularExpression
        )
        output = output.replacingOccurrences(
            of: #"https?://\S+"#,
            with: " ",
            options: .regularExpression
        )
        output = output.replacingOccurrences(
            of: #"[*_`>#~]+"#,
            with: " ",
            options: .regularExpression
        )
        output = output.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func chunks(from text: String, maximumCharacters: Int) -> [String] {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return [] }
        guard clean.count > maximumCharacters else { return [clean] }

        let separators = CharacterSet(charactersIn: ".!?؟؛;\n")
        var sentences: [String] = []
        var current = ""

        for scalar in clean.unicodeScalars {
            current.unicodeScalars.append(scalar)
            if separators.contains(scalar) {
                let value = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { sentences.append(value) }
                current = ""
            }
        }

        let remainder = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !remainder.isEmpty { sentences.append(remainder) }

        var result: [String] = []
        var chunk = ""

        func flush() {
            let value = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { result.append(value) }
            chunk = ""
        }

        for sentence in sentences {
            if sentence.count > maximumCharacters {
                flush()
                var wordChunk = ""
                for word in sentence.split(separator: " ") {
                    let candidate = wordChunk.isEmpty ? String(word) : "\(wordChunk) \(word)"
                    if candidate.count > maximumCharacters {
                        if !wordChunk.isEmpty { result.append(wordChunk) }
                        wordChunk = String(word)
                    } else {
                        wordChunk = candidate
                    }
                }
                if !wordChunk.isEmpty { result.append(wordChunk) }
                continue
            }

            let candidate = chunk.isEmpty ? sentence : "\(chunk) \(sentence)"
            if candidate.count > maximumCharacters {
                flush()
                chunk = sentence
            } else {
                chunk = candidate
            }
        }

        flush()
        return result
    }
}
