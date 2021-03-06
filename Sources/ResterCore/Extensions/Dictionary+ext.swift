//
//  Dictionary+ext.swift
//  ResterCore
//
//  Created by Sven A. Schmidt on 14/02/2019.
//

import Foundation


enum MergeStrategy {
    case firstWins
    case lastWins
}


extension Dictionary {
    func merging(_ other: [Key : Value], strategy: MergeStrategy) -> [Key : Value] {
        switch strategy {
        case .firstWins:
            return self.merging(other, uniquingKeysWith: {old, _ in old})
        case .lastWins:
            return self.merging(other, uniquingKeysWith: {_, new in new})
        }
    }
}


extension Dictionary: Substitutable where Key == ResterCore.Key, Value == ResterCore.Value {
    func substitute(variables: [Key : Value]) throws -> Dictionary<Key, Value> {
        // TODO: consider transforming keys (but be aware that uniqueKeysWithValues
        // below will then trap at runtime if substituted keys are not unique)
        let substituted = try self.map { ($0.key, try $0.value.substitute(variables: variables)) }
        return Dictionary(uniqueKeysWithValues: substituted)
    }
}


extension Dictionary where Key == ResterCore.Key, Value == ResterCore.Value {
    var formUrlEncoded: String {
        return compactMap { Parameter(key: $0.key.urlEncoded, value: $0.value) }
            .compactMap { $0.urlEncoded }
            .joined(separator: "&")
    }
}


extension Dictionary: MultipartEncoding where Key == ResterCore.Key, Value == ResterCore.Value {
    func multipartEncoded() throws -> Data {
        let lineBreak = "\n".data(using: .utf8)!
        let boundary = MultipartBoundary.data(using: .utf8)!
        let endMarker = "--".data(using: .utf8)!

        let payloads = try compactMap { Parameter(key: $0.key, value: $0.value) }
            .sorted { $0.key < $1.key }
            .map { try $0.multipartEncoded() }
        // NB: joined produces data that is missing random characters!
        // therefore we have to do our own joining below
        //  .joined(separator: lineBreak)

        guard payloads.count > 0 else {
            throw ResterError.internalError("multipart encoding requires at least one parameter")
        }

        let tail = payloads[1...].reduce(Data()) { $0 + lineBreak + $1 }
        return payloads[0] + tail + lineBreak + boundary + endMarker
    }
}


extension Dictionary where Key == ResterCore.Key, Value == ResterCore.Value {
    /// Process mutations to array values of the same key if the values are
    /// defined as `.append(value)` or `.remove(value)`.
    ///
    /// - Parameter variables: Dictionary to search for mutation values
    /// - Returns: Dictionary with mutated values
    public func processMutations(variables: [Key: Value]) -> [Key: Value] {
        return Dictionary(uniqueKeysWithValues:
            map { (item) -> (Key, Value) in
                if let value = variables[item.key], case var .array(arr) = item.value {
                    if let appendValue = value.appendValue {
                        return (item.key, .array(arr + [.string(appendValue)]))
                    }
                    if let removeValue = value.removeValue {
                        if let idx = arr.firstIndex(of: .string(removeValue)) {
                            arr.remove(at: idx)
                            return (item.key, .array(arr))
                        }
                    }
                }
                return (item.key, item.value)
            }
        )

    }

    /// Process mutations to array values of the same key if the values are
    /// defined as `.append(value)` or `.remove(value)`.
    ///
    /// - Parameter values: Value object to search for mutation values. Ignored
    ///   if `nil` or not a `Value.dictionary`.
    /// - Returns: Dictionary with mutated values
    public func processMutations(values: Value?) -> [Key: Value] {
        guard case let .dictionary(dict)? = values else { return self }
        return processMutations(variables: dict)
    }

}
