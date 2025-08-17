import Foundation
import SwiftUtils

package final class DicdataStoreState {
    init(dictionaryURL: URL) {
        self.learningMemoryManager = LearningManager(dictionaryURL: dictionaryURL)
    }

    var keyboardLanguage: KeyboardLanguage = .ja_JP
    private(set) var dynamicUserDictionary: [DicdataElement] = []
    var learningMemoryManager: LearningManager

    var userDictionaryURL: URL?
    var memoryURL: URL? {
        self.learningMemoryManager.config.memoryURL
    }

    private(set) var userDictionaryHasLoaded: Bool = false
    private(set) var userDictionaryLOUDS: LOUDS?

    private(set) var memoryHasLoaded: Bool = false
    private(set) var memoryLOUDS: LOUDS?

    func updateUserDictionaryURL(_ newURL: URL) {
        if self.userDictionaryURL != newURL {
            self.userDictionaryURL = newURL
            self.userDictionaryLOUDS = nil
            self.userDictionaryHasLoaded = false
        }
    }

    func updateKeyboardLanguage(_ newLanguage: KeyboardLanguage) {
        self.keyboardLanguage = newLanguage
    }

    func updateLearningConfig(_ newConfig: LearningConfig) {
        if self.learningMemoryManager.config != newConfig {
            let updated = self.learningMemoryManager.updateConfig(newConfig)
            if updated {
                self.resetMemoryLOUDSCache()
            }
        }
    }

    func updateMemoryLOUDS(_ newLOUDS: LOUDS?) {
        self.memoryLOUDS = newLOUDS
        self.memoryHasLoaded = true
    }

    func updateUserDictionaryLOUDS(_ newLOUDS: LOUDS?) {
        self.userDictionaryLOUDS = newLOUDS
        self.userDictionaryHasLoaded = true
    }

    @available(*, deprecated, message: "This API is deprecated. Directly update the state instead.")
    func updateIfRequired(options: ConvertRequestOptions) {
        if options.keyboardLanguage != self.keyboardLanguage {
            self.keyboardLanguage = options.keyboardLanguage
        }
        self.updateUserDictionaryURL(options.sharedContainerURL)
        let learningConfig = LearningConfig(learningType: options.learningType, maxMemoryCount: options.maxMemoryCount, memoryURL: options.memoryDirectoryURL)
        self.updateLearningConfig(learningConfig)
    }

    func importDynamicUserDictionary(_ dicdata: [DicdataElement]) {
        self.dynamicUserDictionary = dicdata
        self.dynamicUserDictionary.mutatingForEach {
            $0.metadata = .isFromUserDictionary
        }
    }

    private func resetMemoryLOUDSCache() {
        self.memoryLOUDS = nil
        self.memoryHasLoaded = false
    }

    func saveMemory() {
        self.learningMemoryManager.save()
        self.resetMemoryLOUDSCache()
    }

    func resetMemory() {
        self.learningMemoryManager.resetMemory()
        self.resetMemoryLOUDSCache()
    }

    func forgetMemory(_ candidate: Candidate) {
        self.learningMemoryManager.forgetMemory(data: candidate.data)
        self.resetMemoryLOUDSCache()
    }

    // 学習を反映する
    // TODO: previousの扱いを改善したい
    func updateLearningData(_ candidate: Candidate, with previous: DicdataElement?) {
        if let previous {
            self.learningMemoryManager.update(data: [previous] + candidate.data)
        } else {
            self.learningMemoryManager.update(data: candidate.data)
        }
    }
    // 予測変換に基づいて学習を反映する
    // TODO: previousの扱いを改善したい
    func updateLearningData(_ candidate: Candidate, with predictionCandidate: PostCompositionPredictionCandidate) {
        switch predictionCandidate.type {
        case .additional(data: let data):
            self.learningMemoryManager.update(data: candidate.data, updatePart: data)
        case .replacement(targetData: let targetData, replacementData: let replacementData):
            self.learningMemoryManager.update(data: candidate.data.dropLast(targetData.count), updatePart: replacementData)
        }
    }
}
