import Foundation
import JSONUtilities
import PathKit
import Swagger
import Yams

public struct Enum {
    public let name: String
    public let cases: [Any]
    public let type: EnumType
    public let description: String?
    public let metadata: Metadata
    public let names: [String]?

    public enum EnumType {
        case schema(Schema)
        case item(Item)
    }
}

public struct ResponseFormatter {
    public let response: Response
    public let successful: Bool
    public let name: String?
    public let statusCode: Int?
}

extension SwaggerSpec {

    public var operationsByTag: [String: [Swagger.Operation]] {
        var dictionary: [String: [Swagger.Operation]] = [:]

        // add operations with no tag at ""
        let operationsWithoutTag = operations
            .filter { $0.tags.isEmpty }
            .sorted { $0.generatedIdentifier < $1.generatedIdentifier }
        if !operationsWithoutTag.isEmpty {
            dictionary[""] = operationsWithoutTag
        }

        for tag in tags {
            dictionary[tag] = operations
                .filter { $0.tags.contains(tag) }
                .sorted { $0.generatedIdentifier < $1.generatedIdentifier }
        }
        return dictionary
    }

    public var enums: [Enum] {
        return parameters.compactMap { $0.value.getEnum(name: $0.name, description: $0.value.description) }
    }
}

extension Metadata {

    public func getEnum(name: String, type: Enum.EnumType, description: String?) -> Enum? {
        if let enumValues = enumValues {
            return Enum(name: name, cases: enumValues.compactMap { $0 }, type: type, description: description ?? self.description, metadata: self, names: enumNames)
        }
        return nil
    }
}

extension Schema {

    public var parent: SwaggerObject<Schema>? {
        if case let .allOf(object) = type {
            for schema in object.subschemas {
                if case let .reference(reference) = schema.type {
                    return reference.swaggerObject
                }
            }
        }
        return nil
    }

    public var properties: [Property] {
        return requiredProperties + optionalProperties
    }

    public var requiredProperties: [Property] {
        switch type {
        case let .object(objectSchema): return objectSchema.requiredProperties
        case let .allOf(allOffSchema):
            for schema in allOffSchema.subschemas {
                if case let .object(objectSchema) = schema.type {
                    return objectSchema.requiredProperties
                }
            }
            return []
        default: return []
        }
    }

    public var optionalProperties: [Property] {
        switch type {
        case let .object(objectSchema): return objectSchema.optionalProperties
        case let .allOf(allOffSchema):
            for schema in allOffSchema.subschemas {
                if case let .object(objectSchema) = schema.type {
                    return objectSchema.optionalProperties
                }
            }
        default: break
        }
        return []
    }

    public var inheritedProperties: [Property] {
        return inheritedRequiredProperties + inheritedOptionalProperties
    }

    public var inheritedRequiredProperties: [Property] {
        return (parent?.value.inheritedRequiredProperties ?? []) + requiredProperties
    }

    public var inheritedOptionalProperties: [Property] {
        return (parent?.value.inheritedOptionalProperties ?? []) + optionalProperties
    }

    public func getEnum(name: String, description: String?) -> Enum? {
        switch type {
        case let .object(objectSchema):
            if case let .schema(schema) = objectSchema.additionalProperties {
                return schema.getEnum(name: name, description: description)
            }
        case let .simple(simpleType):
            if simpleType.canBeEnum {
                return metadata.getEnum(name: name, type: .schema(self), description: description)
            }
        case let .array(array):
            if case let .single(schema) = array.items {
                return schema.getEnum(name: name, description: description)
            }
        default: break
        }
        return nil
    }

    public var enums: [Enum] {
        var enums = properties.compactMap { $0.schema.getEnum(name: $0.name, description: $0.schema.metadata.description) }
        if case let .object(objectSchema) = type, case let .schema(schema) = objectSchema.additionalProperties {
            enums += schema.enums
        }
        return enums
    }

    public var inheritedEnums: [Enum] {
        return (parent?.value.inheritedEnums ?? []) + enums
    }

    public var generateInlineSchema: Bool {
        if case let .object(schema) = type,
            case let .bool(additionalProperties) = schema.additionalProperties, !additionalProperties,
            !schema.properties.isEmpty {
            return true
        } else {
            return false
        }
    }
}

extension Swagger.Operation {

    public func getParameters(type: ParameterLocation) -> [Parameter] {
        return parameters.map { $0.value }.filter { $0.location == type }
    }

    public var enums: [Enum] {
        return requestEnums + responseEnums
    }

    public var requestEnums: [Enum] {
        return parameters.compactMap { $0.value.enumValue }
    }

    public var responseEnums: [Enum] {
        return responses.compactMap { $0.enumValue }
    }
}

extension ObjectSchema {

    public var enums: [Enum] {
        var enums: [Enum] = []
        for property in properties {
            if let enumValue = property.schema.getEnum(name: property.name, description: property.schema.metadata.description) {
                enums.append(enumValue)
            }
        }
        if case let .schema(schema) = additionalProperties {
            if let enumValue = schema.getEnum(name: schema.metadata.title ?? "UNNKNOWN_ENUM", description: schema.metadata.description) {
                enums.append(enumValue)
            }
        }
        return enums
    }
}

extension OperationResponse {

    public var successful: Bool {
        return statusCode?.description.hasPrefix("2") ?? false
    }

    public var name: String {
        if let statusCode = statusCode {
            return "Status\(statusCode.description)"
        } else {
            return "DefaultResponse"
        }
    }

    public var isEnum: Bool {
        return enumValue != nil
    }

    public var enumValue: Enum? {
        return response.value.schema?.getEnum(name: name, description: response.value.description)
    }
}

extension Property {

    public var isEnum: Bool {
        return enumValue != nil
    }

    public var enumValue: Enum? {
        return schema.getEnum(name: name, description: schema.metadata.description)
    }
}

extension Parameter {

    public func getEnum(name: String, description: String?) -> Enum? {
        switch type {
        case let .body(schema): return schema.getEnum(name: name, description: description)
        case let .other(item): return item.getEnum(name: name, description: description)
        }
    }

    public var isEnum: Bool {
        return enumValue != nil
    }

    public var enumValue: Enum? {
        return getEnum(name: name, description: description)
    }
}

extension SimpleType {

    public var canBeEnum: Bool {
        switch self {
        case .string, .integer, .number:
            return true
        case .boolean, .file: return false
        }
    }
}

extension Item {

    public func getEnum(name: String, description: String?) -> Enum? {

        switch type {
        case let .array(array):
            if case let .simpleType(simpleType) = array.items.type {
                if simpleType.canBeEnum, let enumValue = array.items.metadata.getEnum(name: name, type: .item(self), description: description) {
                    return enumValue
                }
            }
        case let .simpleType(simpleType):
            if simpleType.canBeEnum {
                return metadata.getEnum(name: name, type: .item(self), description: description)
            }
        }
        return nil
    }
}
