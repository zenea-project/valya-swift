import Foundation
import Crypto
import Zenea

extension Valya {
    public enum DecodeResult {
        case error
        case empty
        case regularBlock
        case corrupted
        case success(_ contents: [Block.ID])
    }
    
    public func decode(_ data: Data, tryOtherVersions: Bool = true) -> DecodeResult {
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
    
    public static func valya_1_1_decode(_ data: Data) -> DecodeResult {
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
            guard blocksData.count >= 8 else { return .corrupted }
            
            let typeData = blocksData[..<(blocksData.startIndex+8)]
            blocksData.removeFirst(typeData.count)
            
            guard let (family, subtype) = typeData.valya_1_1_algorithmType else { return .corrupted }
            guard let algorithm = Block.ID.Algorithm(family: family, subtype: subtype) else { return .corrupted }
            
            guard blocksData.count >= algorithm.byteCount else { return .corrupted }
            let id = blocksData.prefix(algorithm.byteCount).map { $0 }
            
            blocks.append(Block.ID(algorithm: algorithm, hash: id))
            
            blocksData.removeFirst(algorithm.byteCount)
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

extension Data {
    fileprivate var valya_1_1_algorithmType: (UInt32, UInt32)? {
        self.withUnsafeBytes { pointer in
            let buffer = pointer.bindMemory(to: UInt32.self)
            
            guard buffer.count >= 2 else { return nil }
            return (buffer[0], buffer[1])
        }
    }
}
