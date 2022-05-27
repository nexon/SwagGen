import JSONUtilities

public struct Path {

    public let path: String
    public let operations: [Operation]
    public let parameters: [PossibleReference<Parameter>]
}

extension Path {
    public var isUnresolved: Bool {
        operations.contains(where: \.isUnresolved) ||
        parameters.contains(where: \.isUnresolved)
    }
}

extension Path: NamedMappable {

    public init(name: String, jsonDictionary: JSONDictionary) throws {
        path = name
        parameters = (jsonDictionary.json(atKeyPath: "parameters")) ?? []

        var mappedOperations: [Operation] = []
        for (key, value) in jsonDictionary {
            if let method = Operation.Method(rawValue: key) {
                if let json = value as? [String: Any] {
                    let operation = try Operation(path: path, method: method, pathParameters: parameters, jsonDictionary: json)
                    mappedOperations.append(operation)
                }
            }
        }
        operations = mappedOperations
    }
}
