import Foundation

struct ImportParser {
    // 入力テキストから ImportRow を生成するメイン入口
    static func parse(text: String, mode: ImportSession.ParseMode = .auto) -> [ImportRow] {
        let lines = normalize(text)
        if lines.isEmpty {
            return []
        }

        switch mode {
        case .delimiter:
            return parseByDelimiter(lines: lines)
        case .alternating:
            return parseByAlternating(lines: lines)
        case .singleLine:
            return parseSingleLine(lines: lines)
        case .auto:
            let delimiterRows = parseByDelimiter(lines: lines)
            let alternatingRows = parseByAlternating(lines: lines)
            if looksLikeAlternating(lines: lines) {
                return alternatingRows
            }
            return resolvedCount(in: alternatingRows) > resolvedCount(in: delimiterRows) ? alternatingRows : delimiterRows
        }
    }

    private static func normalize(_ text: String) -> [String] {
        // 行の正規化と見出し除外
        let replaced = text
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\t", with: "\t")
        let rawLines = replaced
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let filtered = rawLines
            .filter { !$0.isEmpty }
            .filter { !isHeaderLike($0) }
        return filtered
    }

    private static func parseByDelimiter(lines: [String]) -> [ImportRow] {
        // 記号区切りで term/meaning を推定
        var rows: [ImportRow] = []
        for line in lines {
            if let pair = splitByDelimiter(line) {
                rows.append(ImportRow(term: pair.term,
                                      meaning: pair.meaning,
                                      confidence: 0.9,
                                      sourceLine: line,
                                      status: .candidate))
            } else {
                rows.append(ImportRow(term: "",
                                      meaning: "",
                                      confidence: 0.2,
                                      sourceLine: line,
                                      status: .unclassified))
            }
        }
        return rows
    }

    private static func parseByAlternating(lines: [String]) -> [ImportRow] {
        // 交互行（英→日）としてペア化
        var rows: [ImportRow] = []
        var i = 0
        while i < lines.count {
            let line = lines[i]
            if i + 1 < lines.count {
                let next = lines[i + 1]
                if isEnglishLike(line) && isJapaneseLike(next) {
                    rows.append(ImportRow(term: line,
                                          meaning: next,
                                          confidence: 0.6,
                                          sourceLine: "\(line) / \(next)",
                                          status: .candidate))
                    i += 2
                    continue
                }
            }
            rows.append(ImportRow(term: "",
                                  meaning: "",
                                  confidence: 0.2,
                                  sourceLine: line,
                                  status: .unclassified))
            i += 1
        }
        return rows
    }

    private static func parseSingleLine(lines: [String]) -> [ImportRow] {
        // 1行1単語（意味は空）として扱う
        return lines.map { line in
            ImportRow(term: line,
                      meaning: "",
                      confidence: 0.3,
                      sourceLine: line,
                      status: .unclassified)
        }
    }

    private static func splitByDelimiter(_ line: String) -> (term: String, meaning: String)? {
        // よくある区切り記号を順に試す
        let delimiters = ["\t", " - ", " : ", ":", "：", "—", "–"]
        for delimiter in delimiters {
            if let range = line.range(of: delimiter) {
                let left = line[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                let right = line[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                if !left.isEmpty && !right.isEmpty {
                    return (String(left), String(right))
                }
            }
        }
        return nil
    }

    private static func looksLikeAlternating(lines: [String]) -> Bool {
        // 英日が交互になっているかの簡易判定
        guard lines.count >= 4 else { return false }
        var matches = 0
        var checks = 0
        var i = 0
        while i + 1 < lines.count && checks < 6 {
            let a = lines[i]
            let b = lines[i + 1]
            if isEnglishLike(a) && isJapaneseLike(b) {
                matches += 1
            }
            checks += 1
            i += 2
        }
        return matches >= 2
    }

    private static func resolvedCount(in rows: [ImportRow]) -> Int {
        rows.reduce(into: 0) { count, row in
            if row.isResolved {
                count += 1
            }
        }
    }

    private static func isEnglishLike(_ text: String) -> Bool {
        // ASCII比率が高ければ英語っぽいと判定
        let letters = text.filter { $0.isLetter }
        guard !letters.isEmpty else { return false }
        let asciiLetters = letters.filter { $0.unicodeScalars.allSatisfy { $0.isASCII } }
        return Double(asciiLetters.count) / Double(letters.count) >= 0.6
    }

    private static func isJapaneseLike(_ text: String) -> Bool {
        // ひらがな/カタカナ/漢字を含むか
        return text.range(of: "[\\u{3040}-\\u{30FF}\\u{4E00}-\\u{9FAF}]", options: .regularExpression) != nil
    }

    private static func isHeaderLike(_ text: String) -> Bool {
        // UNIT/LESSON/ページ番号などの見出しを除外
        let upper = text.uppercased()
        let headerWords = ["UNIT", "LESSON", "CHAPTER", "PAGE", "P.", "No."]
        if headerWords.contains(where: { upper.hasPrefix($0) }) {
            return true
        }
        if text.range(of: "^\\d+$", options: .regularExpression) != nil {
            return true
        }
        if text.range(of: "^\\d+\\s*/\\s*\\d+$", options: .regularExpression) != nil {
            return true
        }
        return false
    }

    static func normalizeOCRLine(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 語番(0963 など)を除去
        let noIndex = trimmed.replacingOccurrences(of: "^\\d{2,5}\\s*", with: "", options: .regularExpression)
        let value = noIndex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        // 発音記号のみの行は除外
        if value.range(of: "^\\[[^\\]]+\\]$", options: .regularExpression) != nil {
            return nil
        }

        // 品詞・注記のみの行は除外
        let lower = value.lowercased()
        if ["cf.", "cf", "n.", "v.", "adj.", "adv."].contains(lower) {
            return nil
        }

        return value
    }
}
