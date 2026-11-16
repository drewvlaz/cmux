@testable import CmuxNextImportCards
import CmuxNextImportSuggestions
import CmuxNextSettings
import Foundation
import Testing

/// 2026-11-16, Settings opens late: each host-lists read encoded Settings › Import's cards with
/// JSONEncoder and decoded them again with JSONSerialization, 16 ms a main-thread record on a
/// Settings open on cmux-lawrence-2 (debug.hangs on 2cad95e: ImportCardList.encode). Read again
/// with the same cards, the list is not encoded again.
@MainActor @Suite(.serialized, .timeLimit(.minutes(1))) struct ImportSettingsListReadTests {
    @Test func anUnchangedListIsNotEncodedAgain() async throws {
        let defaults = try #require(UserDefaults(testSuiteName: "import-list-read-\(UUID().uuidString)"))
        let ledger = FileManager.default.temporaryDirectory.appending(path: "import-jobs-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: ledger) }
        let center = ImportSuggestionsCenter(defaults: defaults, ledgerURL: ledger)
        center.scanThisMac = { _ in
            (0..<40).map { ImportFinding(id: "browser.chrome.\($0)", kind: .browser, browser: .chrome, name: "Chrome \($0)", count: $0 + 1) }
        }
        center.host = ImportCardsHost(runImport: { _, _, _ in throw CancellationError() }, importedProfiles: { [] },
                                      openSettings: { _ in }, importClassic: { _ in nil }, importConductor: { _ in nil }, classicWorkspaces: { nil })
        await withCheckedContinuation { done in center.scan { done.resume() } }
        let cards = try #require(center.settingsJSON["cards"]?.arrayValue)
        #expect(!cards.isEmpty)

        let clock = ContinuousClock()
        let reads = (0..<5).map { _ in clock.measure { _ = center.settingsJSON } }
        let first = try #require(reads.first), rest = try #require(reads.dropFirst().min())
        #expect(center.settingsJSON == center.settingsJSON)
        _ = first
        #expect(rest * 5 < Self.encodeTime(center), "an unchanged list was encoded again: \(rest) a read")
    }

    /// One encode of the center's list as the page gets it (JSONEncoder, then JSONSerialization).
    private static func encodeTime(_ center: ImportSuggestionsCenter) -> Duration {
        let list = center.list()
        return ContinuousClock().measure {
            if let data = try? JSONEncoder().encode(list) { _ = try? JSONSerialization.jsonObject(with: data) }
        }
    }
}
