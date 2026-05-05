import XCTest
@testable import BlogCore

final class ReadingTimeTests: XCTestCase {
    func testEightHundredWordsRoundsUpToFourMinutes() {
        let words = Array(repeating: "word", count: 800).joined(separator: " ")
        let html = "<p>\(words)</p>"
        XCTAssertEqual(ReadingTime.compute(html: html), 4)
    }

    func testEmptyBodyIsZeroMinutes() {
        XCTAssertEqual(ReadingTime.compute(html: ""), 0)
        XCTAssertEqual(ReadingTime.compute(html: "<p></p>"), 0)
    }

    func testRoundsUpFractionalMinutesViaCeil() {
        // 250 words at 200 WPM = 1.25 minutes → ceils to 2.
        let words = Array(repeating: "word", count: 250).joined(separator: " ")
        XCTAssertEqual(ReadingTime.compute(html: "<p>\(words)</p>"), 2)
    }

    func testStripsHTMLTagsBeforeCounting() {
        let html = "<h1>Title</h1><p>This is <strong>five</strong> words here.</p>"
        // Word count: Title This is five words here = 6 words → ceil(6/200) = 1 minute.
        XCTAssertEqual(ReadingTime.compute(html: html), 1)
    }

    func testStripsCommonEntitiesBeforeCounting() {
        let html = "<p>foo &amp; bar &lt; baz</p>"
        // After entity stripping: foo bar baz = 3 words → 1 minute.
        XCTAssertEqual(ReadingTime.compute(html: html), 1)
    }

    func testIgnoresScriptAndStyleContent() {
        let body = Array(repeating: "real", count: 100).joined(separator: " ")
        let noise = Array(repeating: "noise", count: 1000).joined(separator: " ")
        let html = "<style>.x{color:red}\(noise)</style><p>\(body)</p><script>\(noise)</script>"
        XCTAssertEqual(ReadingTime.compute(html: html), 1, "script/style content should not inflate the count")
    }

    func testCountsCJKCharactersForJapaneseAndChinese() {
        // 1800 hiragana characters at ~450 cpm = 4 minutes.
        let body = String(repeating: "あ", count: 1800)
        XCTAssertEqual(ReadingTime.compute(html: "<p>\(body)</p>"), 4)
    }

    func testShortJapaneseBodyIsAtLeastOneMinute() {
        // Below the threshold but non-empty — still rounds up to at least 1.
        XCTAssertEqual(ReadingTime.compute(html: "<p>こんにちは世界</p>"), 1)
    }

    func testMixedScriptBlendsLatinAndCJKRates() {
        // 100 latin words (0.5 min) + 900 CJK chars (2 min) = 2.5 → ceil 3.
        let latin = Array(repeating: "word", count: 100).joined(separator: " ")
        let japanese = String(repeating: "日", count: 900)
        XCTAssertEqual(ReadingTime.compute(html: "<p>\(latin) \(japanese)</p>"), 3)
    }

    func testCountsHiraganaKatakanaAndIdeographs() {
        // 450 hiragana + 450 katakana + 450 kanji = 1350 chars at 450 cpm = 3 min.
        let mixed = String(repeating: "あ", count: 450) + String(repeating: "ア", count: 450) + String(repeating: "字", count: 450)
        XCTAssertEqual(ReadingTime.compute(html: "<p>\(mixed)</p>"), 3)
    }
}
