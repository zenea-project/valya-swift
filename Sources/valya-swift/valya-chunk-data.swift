import Foundation

import FastCDC
import zenea

extension Valya {
    public func chunkData(_ data: Data) -> [Block] {
        switch self.preferredVersion {
        case .v1_1: return Self.valya_1_1_chunkData(data)
        }
    }
    
    public static func valya_1_1_chunkData(_ data: Data) -> [Block] {
        return data.fastCDCSequence(minBytes: 1<<12, avgBytes: 1<<14, maxBytes: 1<<16).map { Block(content: data[$0]) }
    }
}
