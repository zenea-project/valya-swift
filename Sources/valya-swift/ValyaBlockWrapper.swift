import zenea
import CryptoKit
import Foundation

public struct ValyaBlockWrapper: BlockStorage {
    public var source: BlockStorage
    
    public init(source: BlockStorage) {
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
        
        for start in stride(from: 0, to: content.count, by: 1<<16) {
            let end = min(content.count, start + 1<<16)
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
    
    public func decode() -> ValyaDecodeResult {
        print("check if empty")
        guard self.content.count > 0 else { return .empty }
        
        print("decoding prefix")
        let prefix = self.content.prefix(while: { $0 != 0 })
        guard let prefixString = String(data: prefix, encoding: .utf8) else { return .regularBlock }
        guard prefixString == "valya-1" else { return .regularBlock }
        
        print("reading hash")
        guard self.content.count > prefix.count+1+SHA256.byteCount else { return .regularBlock }
        let hashData = self.content[prefix.count+1..<prefix.count+1+SHA256.byteCount]
        
        print("reading blocks")
        var blocksData = self.content[prefix.count+1+hashData.count..<self.content.count]
        
        print("checking hash")
        var hasher = SHA256()
        hasher.update(data: blocksData)
        guard hasher.finalize().elementsEqual(hashData) else { return .regularBlock }
        
        print("decoding blocks")
        var blocks: [Block.ID] = []
        while blocksData.count > 0 {
            print("  reading algorithm")
            let algorithmData = blocksData.prefix { $0 != 0 }
            blocksData.removeFirst(algorithmData.count)
            
            print("  removing separator")
            guard blocksData.count > 0 else { return .corrupted }
            blocksData.removeFirst() // separator
            
            print("  decoding algorithm")
            guard let algorithmString = String(data: algorithmData, encoding: .utf8) else { return .corrupted }
            guard let algorithm = Block.ID.Algorithm(parsing: algorithmString) else { return .corrupted }
            
            print("  decoding id")
            guard blocksData.count >= algorithm.bytes else { return .corrupted }
            let id = blocksData.prefix(algorithm.bytes).map { $0 }
            
            print("  appending block")
            blocks.append(Block.ID(algorithm: algorithm, hash: id))
            
            print("  trimming data")
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

public struct ValyaBlock {
    public enum Version {
        case v1
    }
    
    public var version: Version
    public var content: [Block.ID]
}
