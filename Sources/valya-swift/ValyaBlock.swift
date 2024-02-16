import zenea

public struct ValyaBlock {
    public enum Version {
        case v1
    }
    
    public var version: Version
    public var content: [Block.ID]
}
