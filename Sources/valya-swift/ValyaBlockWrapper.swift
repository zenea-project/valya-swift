import zenea
import CryptoKit
import Foundation

public struct ValyaBlockWrapper<Source: BlockStorage>: BlockStorage {
    public var source: Source
    
    public init(source: Source) {
        self.source = source
    }
    
    public var description: String { source.description }
    
    public func listBlocks() async -> Result<Set<Block.ID>, BlockListError> {
        return await source.listBlocks()
    }
    
    public func fetchBlock(id: Block.ID) async -> Result<Block, BlockFetchError> {
        return .failure(.unable)
    }
    
    public func checkBlock(id: Block.ID) async -> Result<Bool, BlockCheckError> {
        return await source.checkBlock(id: id)
    }
    
    public func putBlock(content: Data) async -> Result<Block.ID, BlockPutError> {
        var blocks: [Block.ID] = []
        
        for start in stride(from: 0, to: content.count, by: 2<<16) {
            let end = min(content.count, start + 2<<16)
            let subdata = content[start..<end]
            let block = Block(content: subdata)
            
            switch await source.putBlock(content: subdata) {
            case .success(block.id): blocks.append(block.id)
            case .success(_): return .failure(.unable)
            case .failure(.exists): blocks.append(block.id)
            case .failure(let error): return .failure(error)
            }
        }
        
        guard let (additional, main) = blocks.compress() else { return .failure(.unable) }
        
        for block in additional {
            switch await source.putBlock(content: block.content) {
            case .success(block.id): break
            case .success(_): return .failure(.unable)
            case .failure(.exists): break
            case .failure(let error): return .failure(error)
            }
        }
        
        return .success(main)
    }
}

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

extension Data {
    public func padded(repeating: Element, to length: Int) -> Data {
        if self.count >= length { return self }
        return self + Data(repeating: repeating, count: length-self.count)
    }
}

extension Block.ID.Algorithm {
    public var bytes: Int {
        switch self {
        case .sha2_256: return 32
        }
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
        
        var blocksData = Data(capacity: 2<<16)
        for block in blocks {
            guard let encoded = block.encode() else { return nil }
            blocksData += encoded
            
            guard blocksData.count < 2<<16 else { return nil }
        }
        guard blocksData.count > 0 else { return nil }
        
        var hasher = SHA256()
        hasher.update(data: blocksData)
        let hashData = hasher.finalize()
        
        let result = prefixData + [0] + hashData + blocksData
        guard result.count <= 2<<16 else { return nil }
        
        self.init(content: result)
    }
}
