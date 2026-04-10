import Foundation

public struct CustomDictionary: Codable {
    public var vocabulary: [String]
    public var replacements: [Replacement]

    public struct Replacement: Codable, Equatable {
        public var from: String
        public var to: String

        public init(from: String, to: String) {
            self.from = from
            self.to = to
        }
    }

    public init(vocabulary: [String] = [], replacements: [Replacement] = []) {
        self.vocabulary = vocabulary
        self.replacements = replacements
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        vocabulary = try container.decodeIfPresent([String].self, forKey: .vocabulary) ?? []
        replacements = try container.decodeIfPresent([Replacement].self, forKey: .replacements) ?? []
    }

    public static let empty = CustomDictionary()

    public static var dictionaryFile: URL {
        Config.configDir.appendingPathComponent("dictionary.json")
    }

    public static func load() -> CustomDictionary {
        guard let data = try? Data(contentsOf: dictionaryFile) else {
            return .empty
        }

        do {
            return try JSONDecoder().decode(CustomDictionary.self, from: data)
        } catch {
            fputs("Warning: unable to parse \(dictionaryFile.path): \(error.localizedDescription)\n", stderr)
            return .empty
        }
    }

    public static func decode(from data: Data) throws -> CustomDictionary {
        return try JSONDecoder().decode(CustomDictionary.self, from: data)
    }

    public func save() throws {
        try FileManager.default.createDirectory(at: Config.configDir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(self)
        try data.write(to: CustomDictionary.dictionaryFile)
    }

    public func applyReplacements(_ text: String) -> String {
        var result = text
        for replacement in replacements {
            result = result.replacingOccurrences(of: replacement.from, with: replacement.to)
        }
        return result
    }

    public func promptFragment() -> String? {
        if vocabulary.isEmpty { return nil }
        return vocabulary.joined(separator: ", ")
    }
}
