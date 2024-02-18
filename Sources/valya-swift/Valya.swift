public struct Valya {
    public enum Version {
        case v1_1
    }
    
    public var preferredVersion: Version
    
    public init(_ preferredVersion: Version = .v1_1) {
        self.preferredVersion = preferredVersion
    }
}
