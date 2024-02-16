import Foundation
import CryptoKit

import zenea

extension Array where Element == Block.ID {
    public func compress() -> (Set<Block>, Block.ID)? {
        if self.count <= 0 { return nil }
        if self.count == 1 { return ([], self[0]) }
        
        var blocks: [Block] = []
        
        // 1597 is max
        for start in stride(from: 0, to: self.count, by: 1597) {
            let end = Swift.min(self.count, start + 1597)
            let block = Block(encoding: self[start..<end])
            guard let block = block else { return nil }
            
            blocks.append(block)
        }
        
        guard let (additional, main) = blocks.map(\.id).compress() else { return nil }
        
        let newBlocks = Set(blocks).union(additional)
        return (newBlocks, main)
    }
}

extension Block.ID {
    public func encode() -> Data? {
        guard let algorithm = self.algorithm.rawValue.data(using: .utf8) else { return nil }
        
        let hash = Data(self.hash.prefix(self.algorithm.bytes))
        guard hash.count == self.algorithm.bytes else { return nil }
        
        return algorithm + [0] + hash
    }
}

extension Block {
    public init?<Array>(encoding blocks: Array) where Array: Sequence, Array.Element == Block.ID {
        guard let prefixData = "valya-1".data(using: .utf8) else { return nil }
        
        var blocksData = Data(capacity: 1<<16)
        for block in blocks {
            guard let encoded = block.encode() else { return nil }
            blocksData += encoded
            
            guard blocksData.count < 1<<16 else { return nil }
        }
        guard blocksData.count > 0 else { return nil }
        
        var hasher = SHA256()
        hasher.update(data: blocksData)
        let hashData = hasher.finalize()
        
        let result = prefixData + [0] + hashData + blocksData
        guard result.count <= 1<<16 else { return nil }
        
        self.init(content: result)
    }
}
