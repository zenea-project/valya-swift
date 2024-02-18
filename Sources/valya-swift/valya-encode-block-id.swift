import Foundation

import zenea

extension Valya {
    public func encodeID(_ id: Block.ID) -> Data? {
        switch self.preferredVersion {
        case .v1_1: return Self.valya_1_1_encodeID(id)
        }
    }
    
    public static func valya_1_1_encodeID(_ id: Block.ID) -> Data? {
        var typeData = Data()
        typeData += id.algorithm.valya_1_1_family.data
        typeData += id.algorithm.valya_1_1_subtype.data
        
        let hash = Data(id.hash.prefix(id.algorithm.bytes))
        guard hash.count == id.algorithm.bytes else { return nil }
        
        return typeData + hash
    }
}

extension Block.ID.Algorithm {
    public var valya_1_1_family: UInt32 {
        switch self {
        case .sha2_256: 1
        }
    }
    
    public var valya_1_1_subtype: UInt32 {
        switch self {
        case .sha2_256: 256
        }
    }
}

extension UInt32 {
    fileprivate var data: Data {
        withUnsafePointer(to: self) { pointer in
            Data(bytes: UnsafeRawPointer(pointer), count: 4)
        }
    }
}
