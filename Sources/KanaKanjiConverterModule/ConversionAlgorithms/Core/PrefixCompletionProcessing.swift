//
//  afterPartlyCompleted.swift
//  Keyboard
//
//  Created by ensan on 2020/09/14.
//  Copyright © 2020 ensan. All rights reserved.
//

import Foundation
import SwiftUtils

extension Kana2Kanji {
    /// カナを漢字に変換する関数, 部分的に確定した後の場合。
    /// ### 実装方法
    /// (1)まず、計算済みnodeの確定分以降を取り出し、registeredにcompletedDataの値を反映したBOSにする。
    ///
    /// (2)次に、再度計算して良い候補を得る。
    func kana2lattice_afterComplete(_ inputData: ComposingText, completedData: Candidate, N_best: Int, previousResult: (inputData: ComposingText, lattice: Lattice), needTypoCorrection: Bool) -> (result: LatticeNode, lattice: Lattice) {
        debug("確定直後の変換、前は：", previousResult.inputData, "後は：", inputData)
        let inputCount = inputData.input.count
        let surfaceCount = inputData.convertTarget.count
        // TODO: 実際にはもっとチェックが必要。具体的には、input/convertTarget両方のsuffixが一致する必要がある
        let convertedInputCount = previousResult.inputData.input.count - inputCount
        let convertedSurfaceCount = previousResult.inputData.convertTarget.count - surfaceCount
        // (1)
        let start = RegisteredNode.fromLastCandidate(completedData)
        let lattice = previousResult.lattice.suffix(inputCount: inputCount, surfaceCount: surfaceCount)
        for (i, nodeArray) in lattice.indexedNodes() {
            let prevs: [RegisteredNode] = if i.isZero {
                [start]
            } else {
                []
            }
            for node in nodeArray {
                node.prevs = prevs
                // inputRangeを確定した部分のカウント分ずらす
                node.range = node.range.offseted(inputOffset: -convertedInputCount, surfaceOffset: -convertedSurfaceCount)
            }
        }
        // (2)
        let result = LatticeNode.EOSNode

        for (i, nodeArray) in lattice.indexedNodes() {
            for node in nodeArray {
                if node.prevs.isEmpty {
                    continue
                }
                if self.dicdataStore.shouldBeRemoved(data: node.data) {
                    continue
                }
                // 生起確率を取得する。
                let wValue = node.data.value()
                if i.isZero {
                    // valuesを更新する
                    node.values = node.prevs.map {$0.totalValue + wValue + self.dicdataStore.getCCValue($0.data.rcid, node.data.lcid)}
                } else {
                    // valuesを更新する
                    node.values = node.prevs.map {$0.totalValue + wValue}
                }
                // 変換した文字数
                let nextIndex = node.range.endIndex
                if nextIndex == .input(inputCount) || nextIndex == .surface(surfaceCount) {
                    self.updateResultNode(with: node, resultNode: result)
                } else {
                    self.updateNextNodes(with: node, nextNodes: lattice[index: nextIndex], nBest: N_best)
                }
            }

        }
        return (result: result, lattice: lattice)
    }
}
