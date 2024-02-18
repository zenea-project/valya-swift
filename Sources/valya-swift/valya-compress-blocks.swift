import Foundation
import CryptoKit

import FastCDC
import zenea

extension Valya {
    public enum CompressResult {
        case error
        case empty
        case single
        case success(_ main: Block, additional: Set<Block>)
    }
    
    public func compress(_ blocks: [Block.ID]) async -> CompressResult {
        switch self.preferredVersion {
        case .v1_1: return await Self.valya_1_1_compress(blocks)
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
    
    public static func valya_1_1_compress(_ ids: [Block.ID]) async -> CompressResult {
        if ids.count <= 0 { return .empty }
        if ids.count == 1 { return .single }
        
        var encodedIDs: [Data] = []
        for id in ids {
            guard let encoded = valya_1_1_encodeID(id) else { return .error }
            encodedIDs.append(encoded)
        }
        
        let capacity = 1<<16 - valya_1_1_prefix.count - 32 // block size - prefix - SHA256 hash
        let average = capacity/2
        let minimum = average/2
        
        do {
            var compressedBlocks: [Block] = []
            for try await subset in encodedIDs.fastCDC(min: minimum, avg: average, max: capacity).slices {
                var data = Data()
                var hasher = SHA256()
                
                for id in subset {
                    data += id
                    hasher.update(data: id)
                }
                
                let prefix = valya_1_1_prefix
                let hash = hasher.finalize()
                
                let block = Block(content: prefix + hash + data)
                compressedBlocks.append(block)
            }
            
            switch await valya_1_1_compress(compressedBlocks.map(\.id)) {
            case .empty, .error: return .error
            case .single: return .success(compressedBlocks[0], additional: [compressedBlocks[0]])
            case .success(let main, additional: let additional): return .success(main, additional: additional.union(compressedBlocks))
            }
        } catch {
            return .error
        }
    }
}
