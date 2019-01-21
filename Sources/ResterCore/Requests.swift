//
//  Requests.swift
//  ResterCore
//
//  Created by Sven A. Schmidt on 21/01/2019.
//

import Foundation


typealias RequestName = String


struct RequestDetails: Decodable {
    let url: String
    let method: Method
    let validation: Validation
}


public struct Requests {
    let items: [[RequestName: RequestDetails]]
}


extension Requests {
    subscript(requestName: String) -> Request? {
        guard let item = items.first(where: { $0.contains {$0.key == requestName} }) else { return nil }
        precondition(item.count == 1, "must have single item at this point")
        let r = item.map { Request(name: $0.key, details: $0.value) }
        return r.first
    }
}


extension Requests: Sequence {
    public struct Iterator: IteratorProtocol {
        public typealias Element = Request
        var currentIndex = 0
        let requests: Requests
        let names: [RequestName]

        init(_ requests: Requests) {
            self.requests = requests
            names = requests.items.compactMap { $0.keys.first }
        }

        mutating public func next() -> Request? {
            guard currentIndex < names.count else { return nil }
            let name = names[currentIndex]
            let request = requests[name]
            currentIndex += 1
            return request
        }
    }

    public func makeIterator() -> Requests.Iterator {
        return Iterator(self)
    }
}


extension Requests: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: OrderedCodingKeys.self)
        self.items = try container.decodeOrdered(RequestDetails.self)
    }

}


struct OrderedCodingKeys: CodingKey {
    var intValue: Int?
    var stringValue: String

    init?(intValue: Int) {
        return nil
    }

    init?(stringValue: String){
        self.stringValue = stringValue
    }
}


extension KeyedDecodingContainer where Key == OrderedCodingKeys {
    func decodeOrdered<T: Decodable>(_ type: T.Type) throws -> [[String: T]] {
        var data = [[String: T]]()

        for key in allKeys {
            let value = try decode(T.self, forKey: key)
            data.append([key.stringValue: value])
        }

        return data
    }
}


