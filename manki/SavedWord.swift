//
//  SavedWord.swift
//  manki
//
//  Created by Codex.
//

import Foundation

struct SavedWord: Codable {
    let english: String
    let japanese: String
    let illustrationScenario: String?
    let illustrationImageFileName: String?
}
