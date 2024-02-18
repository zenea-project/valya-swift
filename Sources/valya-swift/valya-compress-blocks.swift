import Foundation
import CryptoKit

import FastCDC
import zenea

extension Valya {
    public enum CompressResult {
        case empty
        case error
        case success(_ main: Block.ID, additional: Set<Block>)
    }
    
    public func compress(_ blocks: [Block.ID]) -> CompressResult {
        switch self.preferredVersion {
        case .v1_1: return Self.valya_1_1_compress(blocks)
        }
    }
    
    public static var valya_1_1_prefix: [UInt8] {
        [
            // name "valya"
            0x76, // v
            0x61, // a
            0x6c, // l
            0x79, // y
            0x61, // a
            
            // major version number 0x0001
            0x00,
            0x01,
            
            // minor version number
            0x01
        ]
    }
    
    public static func valya_1_1_compress(_ blocks: [Block.ID]) -> CompressResult {
        if blocks.count <= 0 { return .empty }
        if blocks.count == 1 { return .success(blocks[0], additional: []) }
        
        var data: [Data] = []
        for block in blocks {
            guard let encoded = valya_1_1_encodeID(block) else { return .error }
            data.append(encoded)
        }
        
        let capacity = 1<<16 - valya_1_1_prefix.count - 32 // block size - prefix - SHA256 hash
        let average = capacity/2
        let minimum = average/2
        
        var blocks: [Block] = []
        
        for subrange in data.fastCDCSequence(minBytes: minimum, avgBytes: average, maxBytes: capacity) {
            let subset = data[subrange]
            let size = subset.reduce(0) { $0 + $1.count }
            let subdata = subset.reduce(into: Data(capacity: size)) { $0.append($1) }
            
            let prefix = valya_1_1_prefix
            let hash = SHA256.hash(data: subdata)
            
            let block = Block(content: prefix + hash + subdata)
            blocks.append(block)
        }
        
        switch valya_1_1_compress(blocks.map(\.id)) {
        case .empty, .error: return .error
        case .success(let main, additional: let additional): return .success(main, additional: additional.union(blocks))
        }
    }
}
