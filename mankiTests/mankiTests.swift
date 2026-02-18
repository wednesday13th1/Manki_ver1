//
//  mankiTests.swift
//  mankiTests
//
//  Created by 井上　希稟 on 2025/12/26.
//

import Testing
@testable import manki

struct mankiTests {

    @Test func importParser_skipsIndexAndIPA_buildsPairs() async throws {
        let text = """
        0963
        patriot
        [péitriat]
        愛国者
        0964
        legislature
        [lédʒəsleitʃər]
        議会、立法府
        """

        let rows = ImportParser.parse(text: text, mode: .auto)
        let resolved = rows.filter { $0.isResolved }

        #expect(resolved.count >= 2)
        #expect(resolved.contains { $0.term.lowercased() == "patriot" && $0.meaning.contains("愛国者") })
        #expect(resolved.contains { $0.term.lowercased() == "legislature" && $0.meaning.contains("議会") })
    }

    @Test func importParser_doesNotPairEnglishOnlyLines() async throws {
        let text = """
        patriot
        legislature
        inflammation
        """
        let rows = ImportParser.parse(text: text, mode: .alternating)
        #expect(rows.allSatisfy { !$0.isResolved })
    }

}
