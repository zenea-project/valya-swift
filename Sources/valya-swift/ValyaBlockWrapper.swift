import Foundation

import FastCDC
import zenea

public struct ValyaBlockWrapper: BlockStorageWrapper {
    public static var name: String { "valya" }
    
    public var source: BlockStorage
    public var version: Valya.Version
    
    public init(source: BlockStorage, version: Valya.Version = .v1_1) {
        self.source = source
        self.version = version
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
        let valya = Valya(self.version)
        
        var blocks: [Block.ID] = []
        for block in valya.chunkData(content) {
            switch await source.putBlock(content: block.content) {
            case .success(block.id), .failure(.exists): blocks.append(block.id)
            case .success(_): return .failure(.unable)
            case .failure(let error): return .failure(error)
            }
        }
        
        switch valya.compress(blocks) {
        case .error: return .failure(.unable)
        case .empty: return await source.putBlock(content: Data())
        case .success(let main, additional: let additional):
            for block in additional {
                switch await source.putBlock(content: block.content) {
                case .success(block.id), .failure(.exists): break
                case .success(_): return .failure(.unable)
                case .failure(let error): return .failure(error)
                }
            }
            
            return .success(main)
        }
    }
}
