import CryptoKit

import zenea

extension Block {
    public func decode() -> ValyaDecodeResult {
        guard self.content.count > 0 else { return .empty }
        
        let prefix = self.content.prefix(while: { $0 != 0 })
        guard let prefixString = String(data: prefix, encoding: .utf8) else { return .regularBlock }
        guard prefixString == "valya-1" else { return .regularBlock }
        
        guard self.content.count > prefix.count+1+SHA256.byteCount else { return .regularBlock }
        let hashData = self.content[prefix.count+1..<prefix.count+1+SHA256.byteCount]
        
        var blocksData = self.content[prefix.count+1+hashData.count..<self.content.count]
        
        var hasher = SHA256()
        hasher.update(data: blocksData)
        guard hasher.finalize().elementsEqual(hashData) else { return .regularBlock }
        
        var blocks: [Block.ID] = []
        while blocksData.count > 0 {
            let algorithmData = blocksData.prefix { $0 != 0 }
            blocksData.removeFirst(algorithmData.count)
            
            guard blocksData.count > 0 else { return .corrupted }
            blocksData.removeFirst() // separator
            
            guard let algorithmString = String(data: algorithmData, encoding: .utf8) else { return .corrupted }
            guard let algorithm = Block.ID.Algorithm(parsing: algorithmString) else { return .corrupted }
            
            guard blocksData.count >= algorithm.bytes else { return .corrupted }
            let id = blocksData.prefix(algorithm.bytes).map { $0 }
            
            blocks.append(Block.ID(algorithm: algorithm, hash: id))
            
            blocksData.removeFirst(algorithm.bytes)
        }
        
        return .valyaBlock(ValyaBlock(version: .v1, content: blocks))
    }
}

public enum ValyaDecodeResult {
    case error
    case empty
    case corrupted
    case regularBlock
    case valyaBlock(_ block: ValyaBlock)
}
