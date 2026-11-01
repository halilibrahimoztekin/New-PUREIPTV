import Foundation

public nonisolated enum CategoryNameRuleMatcher {
    public nonisolated enum ValidationIssue: Equatable, Sendable {
        case emptyPattern
        case patternTooLong
        case invalidRegularExpression
        case unsupportedRegularExpression
    }

    private enum CompiledRule {
        case literal(String)
        case regularExpression(NSRegularExpression)

        func matches(_ name: String) -> Bool {
            guard name.utf16.count <= Self.maximumCategoryNameLength else { return false }
            switch self {
            case let .literal(pattern):
                return name.localizedCaseInsensitiveContains(pattern)
            case let .regularExpression(expression):
                let range = NSRange(name.startIndex..., in: name)
                return expression.firstMatch(in: name, range: range) != nil
            }
        }

        private static let maximumCategoryNameLength = 512
    }

    public static func validationIssue(for rule: CategoryNameRule) -> ValidationIssue? {
        let pattern = rule.pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pattern.isEmpty else { return .emptyPattern }
        guard pattern.count <= 128 else { return .patternTooLong }
        guard rule.mode == .regularExpression else { return nil }

        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return .invalidRegularExpression
        }
        guard isSupportedRegularExpression(pattern) else { return .unsupportedRegularExpression }
        _ = expression
        return nil
    }

    public static func hiddenCategoryIDs(
        in categories: [MediaModels.Category],
        rules: [CategoryNameRule]
    ) -> Set<String> {
        let activeRules = rules.compactMap { rule -> CompiledRule? in
            guard rule.isEnabled else { return nil }
            return compiledRule(for: rule)
        }
        guard !activeRules.isEmpty else { return [] }

        return Set(categories.compactMap { category in
            activeRules.contains(where: { $0.matches(category.sourceName) }) ? category.id : nil
        })
    }

    public static func matchingCategories(
        for rule: CategoryNameRule,
        in categories: [MediaModels.Category]
    ) -> [MediaModels.Category] {
        guard let compiledRule = compiledRule(for: rule) else { return [] }
        return categories.filter { compiledRule.matches($0.sourceName) }
    }

    private static func compiledRule(for rule: CategoryNameRule) -> CompiledRule? {
        guard validationIssue(for: rule) == nil else { return nil }
        let pattern = rule.pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        switch rule.mode {
        case .literal:
            return .literal(pattern)
        case .regularExpression:
            guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                return nil
            }
            return .regularExpression(expression)
        }
    }

    /// Keeps matching predictable by supporting a deliberately small regular-expression subset.
    /// Parentheses, alternation, backreferences, and more than one repetition operator are rejected.
    private static func isSupportedRegularExpression(_ pattern: String) -> Bool {
        var isEscaped = false
        var isInsideCharacterClass = false
        var repetitionCount = 0

        for scalar in pattern.unicodeScalars {
            if isEscaped {
                guard !(48 ... 57).contains(scalar.value),
                      scalar != "k",
                      scalar != "K",
                      scalar != "p",
                      scalar != "P",
                      scalar != "Q",
                      scalar != "E" else { return false }
                isEscaped = false
                continue
            }

            if scalar == "\\" {
                isEscaped = true
                continue
            }

            if isInsideCharacterClass {
                if scalar == "]" {
                    isInsideCharacterClass = false
                }
                continue
            }

            if scalar == "[" {
                isInsideCharacterClass = true
                continue
            }

            guard scalar != "(", scalar != ")", scalar != "|" else { return false }
            if scalar == "*" || scalar == "+" || scalar == "?" || scalar == "{" {
                repetitionCount += 1
                guard repetitionCount <= 1 else { return false }
            }
        }

        return !isEscaped && !isInsideCharacterClass
    }
}
