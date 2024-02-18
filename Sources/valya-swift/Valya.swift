public struct Valya {
    public enum Version: String {
        case v1_1 = "v1.1"
    }
    
    public var preferredVersion: Version
    
    public init(_ preferredVersion: Version = .v1_1) {
        self.preferredVersion = preferredVersion
    }
}
