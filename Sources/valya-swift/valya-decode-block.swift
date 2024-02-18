import CryptoKit
import Foundation

import zenea

extension Valya {
    public enum DecodeResult {
        case error
        case empty
        case regularBlock
        case corrupted
        case success(_ contents: [Block.ID])
    }
    
    public func decode<Data: DataProtocol>(_ data: Data, tryOtherVersions: Bool = true) -> DecodeResult where Data.Index == Int {
        typealias DecodeFunction = (Data) -> DecodeResult
        
        let main: DecodeFunction
        let other: [DecodeFunction]
        
        switch self.preferredVersion {
        case .v1_1: 
            main = Self.valya_1_1_decode
            other = []
        }
        
        for function in [main] + (tryOtherVersions ? other : []) {
            switch function(data) {
            case .error: return .error
            case .empty: return .empty
            case .regularBlock: continue
            case .corrupted: return .corrupted
            case .success(let contents): return .success(contents)
            }
        }
        
        return .regularBlock
    }
    
    public static func valya_1_1_decode<Data: DataProtocol>(_ data: Data) -> DecodeResult where Data.Index == Int {
        guard data.count > 0 else { return .empty }
        guard data.starts(with: valya_1_1_prefix) else { return .regularBlock }
        
        let hashRange = valya_1_1_prefix.count ..< valya_1_1_prefix.count + SHA256.byteCount
        guard data.count >= hashRange.upperBound else { return .regularBlock }
        let hashData = data[hashRange]
        
        let blocksRange = hashRange.upperBound ..< data.count
        var blocksData = data[blocksRange]
        
        guard SHA256.hash(data: blocksData).elementsEqual(hashData) else { return .regularBlock }
        
        var blocks: [Block.ID] = []
        while blocksData.count > 0 {
            let typeData = blocksData.prefix(8)
            blocksData.removeFirst(typeData.count)
            
            guard let (family, subtype) = typeData.valya_1_1_algorithmType else { return .corrupted }
            guard let algorithm = Block.ID.Algorithm(family: family, subtype: subtype) else { return .corrupted }
            
            guard blocksData.count >= algorithm.bytes else { return .corrupted }
            let id = blocksData.prefix(algorithm.bytes).map { $0 }
            
            blocks.append(Block.ID(algorithm: algorithm, hash: id))
            
            blocksData.removeFirst(algorithm.bytes)
        }
        
        return .success(blocks)
    }
}

extension Block.ID.Algorithm {
    public init?(family: UInt32, subtype: UInt32) {
        switch (family, subtype) {
        case (1, 256): self = .sha2_256
        default: return nil
        }
    }
}

extension DataProtocol {
    fileprivate var valya_1_1_algorithmType: (UInt32, UInt32)? {
        self.withContiguousStorageIfAvailable { pointer in
            pointer.withMemoryRebound(to: UInt32.self) { pointer in
                guard pointer.count >= 2 else { return nil }
                return (pointer[0], pointer[1])
            }
        } ?? nil
    }
}
