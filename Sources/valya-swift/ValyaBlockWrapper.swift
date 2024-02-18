import Foundation
import NIOCore

import FastCDC
import zenea

public struct ValyaBlockWrapper: BlockStorageWrapper {
    public var name: String { "valya-\(self.version.rawValue)" }
    
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
    
    public func putBlock<Bytes>(content: Bytes) async -> Result<Block, BlockPutError> where Bytes: AsyncSequence, Bytes.Element == Data {
        switch self.version {
        case .v1_1: return await valya_1_1_putBlock(content: content)
        }
    }
    
    public func valya_1_1_putBlock<Bytes>(content: Bytes) async -> Result<Block, BlockPutError> where Bytes: AsyncSequence, Bytes.Element == Data {
        var blocks: [Block] = []
        do {
            for try await subdata in Valya.valya_1_1_chunkData(content) {
                let block = Block(content: subdata)
                
                switch await source.putBlock(data: subdata) {
                case .success(block), .failure(.exists): blocks.append(block)
                case .success(_): return .failure(.unable)
                case .failure(let error): return .failure(error)
                }
            }
        } catch {
            return .failure(.unable)
        }
        
        switch await Valya.valya_1_1_compress(blocks.map(\.id)) {
        case .error: return .failure(.unable)
        case .empty: return await source.putBlock(data: Data())
        case .single: return .success(blocks[0])
        case .success(let main, additional: let additional):
            for block in additional {
                switch await source.putBlock(content: [block.content]) {
                case .success(block), .failure(.exists): break
                case .success(_): return .failure(.unable)
                case .failure(let error): return .failure(error)
                }
            }
            
            return .success(main)
        }
    }
}
