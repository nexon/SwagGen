import Foundation

public struct Property {
    public let name: String
    public let required: Bool
    public let schema: Schema
}

extension Property {
    public var isUnresolved: Bool {
        schema.isUnresolved
    }
}
