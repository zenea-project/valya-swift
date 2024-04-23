import Foundation
import Zenea
import FastCDC

public struct ValyaBlockWrapper<Source>: BlockStorageWrapper where Source: BlockStorage {
    public var name: String { "valya-\(self.version.rawValue)" }
    
    public var source: Source
    public var version: Valya.Version
    
    public init(source: Source, version: Valya.Version = .v1_1) {
        self.source = source
        self.version = version
    }
    
    public init(@BlockStorageBuilder source: () -> Source, version: Valya.Version = .v1_1) {
        self.source = source()
        self.version = version
    }
    
    public func listBlocks() async -> Result<Set<Block.ID>, Block.ListError> {
        return await source.listBlocks()
    }
    
    public func fetchBlock(id: Block.ID) async -> Result<Block, Block.FetchError> {
        return .failure(.unable)
    }
    
    public func checkBlock(id: Block.ID) async -> Result<Bool, Block.CheckError> {
        return await source.checkBlock(id: id)
    }
    
    public func putBlock(content: Data) async -> Result<Block, Block.PutError> {
        switch self.version {
        case .v1_1: return await valya_1_1_putBlock(content: content)
        }
    }
    
    public func valya_1_1_putBlock(content: Data) async -> Result<Block, Block.PutError> {
        var blocks: [Block] = []
        for (subdata, _) in content.chunk(min: Block.maxBytes/8, avg: Block.maxBytes/4, max: Block.maxBytes) {
            let block = Block(content: subdata)
            
            switch await source.putBlock(content: subdata) {
            case .success(block), .failure(.exists(block)): blocks.append(block)
            case .success(_): return .failure(.unable)
            case .failure(let error): return .failure(error)
            }
        }
        
        switch await Valya.valya_1_1_compress(blocks.map(\.id)) {
        case .error: return .failure(.unable)
        case .empty: return await source.putBlock(content: Data())
        case .single: return .success(blocks[0])
        case .success(let main, additional: let additional):
            for block in additional {
                switch await source.putBlock(content: block.content) {
                case .success(block), .failure(.exists(block)): break
                case .success(_): return .failure(.unable)
                case .failure(let error): return .failure(error)
                }
            }
            
            return .success(main)
        }
    }
}
