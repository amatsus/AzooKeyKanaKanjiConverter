//
//  extension Data.swift
//  Keyboard
//
//  Created by ensan on 2020/09/30.
//  Copyright © 2020 ensan. All rights reserved.
//

package import Foundation
import SwiftUtils

extension LOUDS {
    // MARK: - Unaligned-safe little-endian readers
    @inline(__always)
    private static func byte(_ data: borrowing Data, _ offset: Int) -> UInt8 {
        data[data.index(data.startIndex, offsetBy: offset)]
    }

    @inline(__always)
    private static func readUInt16LE(_ data: borrowing Data, _ offset: Int) -> UInt16 {
        let b0 = UInt16(byte(data, offset))
        let b1 = UInt16(byte(data, offset + 1))
        return b0 | (b1 << 8)
    }

    @inline(__always)
    private static func readUInt32LE(_ data: borrowing Data, _ offset: Int) -> UInt32 {
        let b0 = UInt32(byte(data, offset))
        let b1 = UInt32(byte(data, offset + 1))
        let b2 = UInt32(byte(data, offset + 2))
        let b3 = UInt32(byte(data, offset + 3))
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }

    @inline(__always)
    private static func readFloat32LE(_ data: borrowing Data, _ offset: Int) -> Float32 {
        Float32(bitPattern: readUInt32LE(data, offset))
    }
    private static func loadLOUDSBinary(from url: URL) -> [UInt64]? {
        do {
            let binaryData = try Data(contentsOf: url, options: [.uncached]) // 2度読み込むことはないのでキャッシュ不要
            let ui64array = binaryData.toArray(of: UInt64.self)
            return ui64array
        } catch {
            debug(error)
            return nil
        }
    }

    /// LOUDSをファイルから読み込む関数
    /// - Parameter identifier: ファイル名
    /// - Returns: 存在すればLOUDSデータを返し、存在しなければ`nil`を返す。
    package static func load(_ identifier: String, dictionaryURL: URL) -> LOUDS? {
        let (charsURL, loudsURL) = (
            dictionaryURL.appendingPathComponent("louds/\(identifier).loudschars2", isDirectory: false),
            dictionaryURL.appendingPathComponent("louds/\(identifier).louds", isDirectory: false)
        )
        return load(charsURL: charsURL, loudsURL: loudsURL)
    }

    package static func loadMemory(memoryURL: URL) -> LOUDS? {
        let (charsURL, loudsURL) = (
            memoryURL.appendingPathComponent("memory.loudschars2", isDirectory: false),
            memoryURL.appendingPathComponent("memory.louds", isDirectory: false)
        )
        return load(charsURL: charsURL, loudsURL: loudsURL)
    }

    package static func loadUserDictionary(userDictionaryURL: URL) -> LOUDS? {
        let (charsURL, loudsURL) = (
            userDictionaryURL.appendingPathComponent("user.loudschars2", isDirectory: false),
            userDictionaryURL.appendingPathComponent("user.louds", isDirectory: false)
        )
        return load(charsURL: charsURL, loudsURL: loudsURL)
    }

    private static func load(charsURL: URL, loudsURL: URL) -> LOUDS? {
        let nodeIndex2ID: [UInt8]
        do {
            nodeIndex2ID = try Array(Data(contentsOf: charsURL, options: [.uncached]))   // 2度読み込むことはないのでキャッシュ不要
        } catch {
            debug("Error: \(loudsURL)に対するLOUDSファイルが存在しません。このエラーは無視できる可能性があります。 Description: \(error)")
            return nil
        }

        if let bytes = LOUDS.loadLOUDSBinary(from: loudsURL) {
            let louds = LOUDS(bytes: bytes.map {$0.littleEndian}, nodeIndex2ID: nodeIndex2ID)
            return louds
        }
        return nil
    }

    @inlinable
    static func parseBinary(binary: Data) -> [DicdataElement] {
        // Fast parse without intermediate toArray allocations
        let count = Int(readUInt16LE(binary, 0))
        var offset = 2
        var dicdata: [DicdataElement] = []
        dicdata.reserveCapacity(count)
        if count > 0 {
            // Each entry: 2B*3 (UInt16) + 4B (Float32) = 10B
            for _ in 0 ..< count {
                let lcid = Int(readUInt16LE(binary, offset + 0))
                let rcid = Int(readUInt16LE(binary, offset + 2))
                let mid = Int(readUInt16LE(binary, offset + 4))
                let value = PValue(readFloat32LE(binary, offset + 6))
                dicdata.append(DicdataElement(word: "", ruby: "", lcid: lcid, rcid: rcid, mid: mid, value: value))
                offset += 10
            }
        }

        let strStart = binary.index(binary.startIndex, offsetBy: offset)
        let substrings = binary[strStart...].split(separator: UInt8(ascii: "\t"), omittingEmptySubsequences: false)
        guard let ruby = String(data: substrings.first ?? Data(), encoding: .utf8) else {
            debug("getDataForLoudstxt3: failed to parse", dicdata)
            return []
        }
        var i = dicdata.startIndex
        // Skip the first (ruby) field
        for substring in substrings.dropFirst() {
            if i == dicdata.endIndex { break }
            guard let word = String(data: substring, encoding: .utf8) else {
                debug("getDataForLoudstxt3: failed to parse", ruby)
                i = dicdata.index(after: i)
                continue
            }
            withMutableValue(&dicdata[i]) {
                $0.ruby = ruby
                $0.word = word.isEmpty ? ruby : word
            }
            i = dicdata.index(after: i)
        }
        return dicdata
    }

    static func getUserDictionaryDataForLoudstxt3(_ identifier: String, indices: [Int], cache: Data? = nil, userDictionaryURL: URL) -> [DicdataElement] {
        if let cache {
            return Self.paresLoudstxt3Binary(binary: cache, indices: indices)
        }
        do {
            let url = userDictionaryURL.appendingPathComponent("\(identifier).loudstxt3", isDirectory: false)
            return Self.paresLoudstxt3Binary(binary: try Data(contentsOf: url), indices: indices)
        } catch {
            debug(#function, error)
            return []
        }
    }

    static func getMemoryDataForLoudstxt3(_ identifier: String, indices: [Int], cache: Data? = nil, memoryURL: URL) -> [DicdataElement] {
        if let cache {
            return Self.paresLoudstxt3Binary(binary: cache, indices: indices)
        }
        do {
            let url = memoryURL.appendingPathComponent("\(identifier).loudstxt3", isDirectory: false)
            return Self.paresLoudstxt3Binary(binary: try Data(contentsOf: url), indices: indices)
        } catch {
            debug(#function, error)
            return []
        }
    }

    static func getDataForLoudstxt3(_ identifier: String, indices: [Int], cache: Data? = nil, dictionaryURL: URL) -> [DicdataElement] {
        if let cache {
            return Self.paresLoudstxt3Binary(binary: cache, indices: indices)
        }
        do {
            let url = dictionaryURL.appendingPathComponent("louds/\(identifier).loudstxt3", isDirectory: false)
            return Self.paresLoudstxt3Binary(binary: try Data(contentsOf: url), indices: indices)
        } catch {
            debug(#function, error)
            return []
        }
    }

    private static func paresLoudstxt3Binary(binary: Data, indices: [Int]) -> [DicdataElement] {
        let lc: Int = Int(readUInt16LE(binary, 0))
        // Header table of UInt32 offsets starts at byte 2
        var out: [DicdataElement] = []
        out.reserveCapacity(indices.count * 2) // rough guess
        for idx in indices {
            let start = Int(readUInt32LE(binary, 2 + idx * 4))
            let end: Int = if idx == (lc - 1) {
                binary.endIndex
            } else {
                Int(readUInt32LE(binary, 2 + (idx + 1) * 4))
            }
            out.append(contentsOf: parseBinary(binary: binary[start ..< end]))
        }
        return out
    }
}
