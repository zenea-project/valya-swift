import Foundation

import FastCDC
import zenea

public struct ValyaBlockWrapper<Source: BlockStorage>: BlockStorageWrapper {
    public static var name: String { "valya" }
    
    public var source: Source
    
    public init(source: Source) {
        self.source = source
    }
    
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
        
        for subdata in content.fastCDC(min: 1<<14, avg: 1<<15, max: 1<<16) {
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

extension Block.ID.Algorithm {
    public var bytes: Int {
        switch self {
        case .sha2_256: return 32
        }
    }
}
