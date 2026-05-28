// TutorialManager.swift
// Place in: Frontend/Tutorial/TutorialManager.swift

import SwiftUI
import Combine

enum TutorialStep: Int, CaseIterable {
    case aiTags = 0
    case dropdowns = 1
    case closetGrid = 2
    case generateOutfit = 3
    case feed = 4
}

@MainActor
final class TutorialManager: ObservableObject {
    @Published var currentStep: TutorialStep = .aiTags
    @Published var isActive: Bool = false
    @Published var anchorFrames: [TutorialStep: CGRect] = [:]

    private let userDefaultsKey = "fitty_tutorial_completed_for"
    let userID: String

    init(userID: String) {
        self.userID = userID
    }

    var shouldShow: Bool {
        UserDefaults.standard.string(forKey: userDefaultsKey) != userID
    }

    func start() {
        guard shouldShow else { return }
        currentStep = .aiTags
        isActive = true
    }

    func advance() {
        let nextRaw = currentStep.rawValue + 1
        if let next = TutorialStep(rawValue: nextRaw) {
            currentStep = next
        } else {
            complete()
        }
    }

    func complete() {
        isActive = false
        UserDefaults.standard.set(userID, forKey: userDefaultsKey)
    }

    func registerFrame(_ frame: CGRect, for step: TutorialStep) {
        anchorFrames[step] = frame
    }
}