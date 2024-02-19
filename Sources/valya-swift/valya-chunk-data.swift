import Foundation
import NIOFileSystem

import FastCDC
import zenea

extension Valya {
    public static func valya_1_1_chunkData<Bytes>(_ data: Bytes, min: Int = Block.maxBytes/8, avg: Int = Block.maxBytes/4, max: Int = Block.maxBytes) -> FastCDCView<Bytes.FastCDCSource>.Slices where Bytes: AsyncSequence, Bytes.Element == Data {
        return data.fastCDCSource.fastCDC(min: min, avg: avg, max: max).slices
    }
}

public struct AsyncDataSequenceCDCSource<Sequence>: FastCDCSource, IteratorProtocol where Sequence: AsyncIteratorProtocol, Sequence.Element == Data {
    public typealias Index = Int
    public typealias OffsetSequence = Data
    public typealias SubSequence = Data
    public typealias Element = UInt8
    
    public var sequence: Sequence
    public var accumulatedData = Data()
    public private(set) var index = 0
    
    public init(sequence: Sequence) {
        self.sequence = sequence
    }
    
    public var count: Int = 0
    
    public var startIndex: Int { accumulatedData.startIndex }
    public var endIndex: Int { accumulatedData.endIndex }
    
    public func index(after index: Int) -> Int {
        accumulatedData.index(after: index)
    }
    
    public subscript(indices: PartialRangeFrom<Int>) -> Data {
        accumulatedData[indices]
    }
    
    public subscript(indices: Range<Int>) -> Data {
        accumulatedData[indices]
    }
    
    public func makeIterator() -> Self {
        self
    }
    
    public mutating func next() -> UInt8? {
        guard index < count else { return nil }
        defer { index += 1 }
        return accumulatedData[index]
    }
    
    public mutating func load(from index: Int, bytes: Int) async {
        let endIndex = index + bytes
        
        while count < endIndex, let next = try? await sequence.next() {
            accumulatedData += next
            count = accumulatedData.count
        }
    }
}

extension AsyncSequence where Element == Data {
    public typealias FastCDCSource = AsyncDataSequenceCDCSource<AsyncIterator>
    
    public var fastCDCSource: Self.FastCDCSource {
        AsyncDataSequenceCDCSource(sequence: self.makeAsyncIterator())
    }
}
