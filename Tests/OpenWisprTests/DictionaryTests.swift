import XCTest
@testable import OpenWisprLib

final class DictionaryTests: XCTestCase {

    // MARK: - JSON decoding

    func testDecodeWithBothVocabularyAndReplacements() throws {
        let json = """
        {
            "vocabulary": ["Souriant", "Claude"],
            "replacements": [{"from": "苦闘点", "to": "句読点"}]
        }
        """.data(using: .utf8)!
        let dict = try CustomDictionary.decode(from: json)
        XCTAssertEqual(dict.vocabulary, ["Souriant", "Claude"])
        XCTAssertEqual(dict.replacements.count, 1)
        XCTAssertEqual(dict.replacements[0].from, "苦闘点")
        XCTAssertEqual(dict.replacements[0].to, "句読点")
    }

    func testDecodeWithOnlyVocabulary() throws {
        let json = """
        {"vocabulary": ["Anthropic", "whisper"]}
        """.data(using: .utf8)!
        let dict = try CustomDictionary.decode(from: json)
        XCTAssertEqual(dict.vocabulary, ["Anthropic", "whisper"])
        XCTAssertEqual(dict.replacements, [])
    }

    func testDecodeWithOnlyReplacements() throws {
        let json = """
        {"replacements": [{"from": "helo", "to": "hello"}]}
        """.data(using: .utf8)!
        let dict = try CustomDictionary.decode(from: json)
        XCTAssertEqual(dict.vocabulary, [])
        XCTAssertEqual(dict.replacements.count, 1)
    }

    func testDecodeFromEmptyObject() throws {
        let json = "{}".data(using: .utf8)!
        let dict = try CustomDictionary.decode(from: json)
        XCTAssertEqual(dict.vocabulary, [])
        XCTAssertEqual(dict.replacements, [])
    }

    // MARK: - applyReplacements

    func testApplyReplacementsSingle() {
        let dict = CustomDictionary(
            replacements: [.init(from: "苦闘点", to: "句読点")]
        )
        XCTAssertEqual(dict.applyReplacements("苦闘点が必要"), "句読点が必要")
    }

    func testApplyReplacementsMultipleInOrder() {
        let dict = CustomDictionary(
            replacements: [
                .init(from: "AA", to: "BB"),
                .init(from: "BB", to: "CC"),
            ]
        )
        // "AA" -> "BB" -> "CC" (applied sequentially)
        XCTAssertEqual(dict.applyReplacements("AA"), "CC")
    }

    func testApplyReplacementsNoMatch() {
        let dict = CustomDictionary(
            replacements: [.init(from: "xyz", to: "abc")]
        )
        XCTAssertEqual(dict.applyReplacements("hello world"), "hello world")
    }

    func testApplyReplacementsEmptyList() {
        let dict = CustomDictionary()
        XCTAssertEqual(dict.applyReplacements("hello world"), "hello world")
    }

    // MARK: - promptFragment

    func testPromptFragmentReturnsJoinedString() {
        let dict = CustomDictionary(vocabulary: ["Souriant", "Claude", "Anthropic"])
        XCTAssertEqual(dict.promptFragment(), "Souriant, Claude, Anthropic")
    }

    func testPromptFragmentEmptyReturnsNil() {
        let dict = CustomDictionary()
        XCTAssertNil(dict.promptFragment())
    }

    // MARK: - empty

    func testEmptyHasNoVocabularyAndNoReplacements() {
        let dict = CustomDictionary.empty
        XCTAssertEqual(dict.vocabulary, [])
        XCTAssertEqual(dict.replacements, [])
    }
}
