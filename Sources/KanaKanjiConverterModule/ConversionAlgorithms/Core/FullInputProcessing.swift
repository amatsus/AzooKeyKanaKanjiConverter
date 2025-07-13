//
//  all.swift
//  Keyboard
//
//  Created by ensan on 2020/09/14.
//  Copyright © 2020 ensan. All rights reserved.
//

import Algorithms
import Foundation
import SwiftUtils

extension Kana2Kanji {
    /// カナを漢字に変換する関数, 前提はなくかな列が与えられた場合。
    /// - Parameters:
    ///   - inputData: 入力データ。
    ///   - N_best: N_best。
    /// - Returns:
    ///   変換候補。
    /// ### 実装状況
    /// (0)多用する変数の宣言。
    ///
    /// (1)まず、追加された一文字に繋がるノードを列挙する。
    ///
    /// (2)次に、計算済みノードから、(1)で求めたノードにつながるようにregisterして、N_bestを求めていく。
    ///
    /// (3)(1)のregisterされた結果をresultノードに追加していく。この際EOSとの連接計算を行っておく。
    ///
    /// (4)ノードをアップデートした上で返却する。
    func kana2lattice_all(_ inputData: ComposingText, N_best: Int, needTypoCorrection: Bool) -> (result: LatticeNode, lattice: Lattice) {
        debug("新規に計算を行います。inputされた文字列は\(inputData.input.count)文字分の\(inputData.convertTarget)")
        let inputCount: Int = inputData.input.count
        let surfaceCount = inputData.convertTarget.count
        let result: LatticeNode = LatticeNode.EOSNode
        let i2sMap = inputData.inputIndexToSurfaceIndexMap()
        let latticeIndices = Lattice.indices(inputCount: inputCount, surfaceCount: surfaceCount, inputIndexToSurfaceIndexMap: i2sMap)
        let rawNodes = latticeIndices.map { (iIndex, sIndex) in
            let surfaceRange: (startIndex: Int, endIndexRange: Range<Int>?)? = if let sIndex {
                (sIndex, nil)
            } else {
                nil
            }
            return dicdataStore.getLOUDSDataInRange(
                inputData: inputData,
                from: iIndex,
                surfaceRange: surfaceRange,
                needTypoCorrection: needTypoCorrection
            )
        }
        let lattice: Lattice = Lattice(
            inputCount: inputCount,
            surfaceCount: surfaceCount,
            rawNodes: rawNodes
        )
        // 「i文字目から始まるnodes」に対して
        for (isHead, nodeArray) in lattice.indexedNodes(indices: latticeIndices) {
            // それぞれのnodeに対して
            for node in nodeArray {
                if node.prevs.isEmpty {
                    continue
                }
                if self.dicdataStore.shouldBeRemoved(data: node.data) {
                    continue
                }
                // 生起確率を取得する。
                let wValue: PValue = node.data.value()
                if isHead {
                    // valuesを更新する
                    node.values = node.prevs.map {$0.totalValue + wValue + self.dicdataStore.getCCValue($0.data.rcid, node.data.lcid)}
                } else {
                    // valuesを更新する
                    node.values = node.prevs.map {$0.totalValue + wValue}
                }
                // 後続ノードのindex（正規化する）
                let nextIndex: (inputIndex: Int?, surfaceIndex: Int?) = switch node.range.endIndex {
                case .input(let index): (index, i2sMap[index])
                case .surface(let index): (i2sMap.filter { $0.value == index}.first?.key, index)
                }
                print(nextIndex, node.data.word, node.data.ruby)
                // 文字数がcountと等しい場合登録する
                if nextIndex.inputIndex == inputCount && nextIndex.surfaceIndex == surfaceCount {
                    self.updateResultNode(with: node, resultNode: result)
                } else {
                    self.updateNextNodes(with: node, nextNodes: lattice[index: nextIndex], nBest: N_best)
                }
            }
        }
        return (result: result, lattice: lattice)
    }

    func updateResultNode(with node: LatticeNode, resultNode: LatticeNode) {
        for index in node.prevs.indices {
            let newnode: RegisteredNode = node.getRegisteredNode(index, value: node.values[index])
            resultNode.prevs.append(newnode)
        }
    }
    /// N-Best計算を高速に実行しつつ、遷移先ノードを更新する
    func updateNextNodes(with node: LatticeNode, nextNodes: some Sequence<LatticeNode>, nBest: Int) {
        for nextnode in nextNodes {
            if self.dicdataStore.shouldBeRemoved(data: nextnode.data) {
                continue
            }
            // クラスの連続確率を計算する。
            let ccValue: PValue = self.dicdataStore.getCCValue(node.data.rcid, nextnode.data.lcid)
            // nodeの持っている全てのprevnodeに対して
            for (index, value) in node.values.enumerated() {
                let newValue: PValue = ccValue + value
                // 追加すべきindexを取得する
                let lastindex: Int = (nextnode.prevs.lastIndex(where: {$0.totalValue >= newValue}) ?? -1) + 1
                if lastindex == nBest {
                    continue
                }
                let newnode: RegisteredNode = node.getRegisteredNode(index, value: newValue)
                // カウントがオーバーしている場合は除去する
                if nextnode.prevs.count >= nBest {
                    nextnode.prevs.removeLast()
                }
                // removeしてからinsertした方が速い (insertはO(N)なので)
                nextnode.prevs.insert(newnode, at: lastindex)
            }
        }
    }
}
