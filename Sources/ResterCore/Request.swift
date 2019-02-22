//
//  Request.swift
//  ResterCore
//
//  Created by Sven A. Schmidt on 19/01/2019.
//

import Foundation
import PromiseKit
import PMKFoundation
import AnyCodable
import Regex


public struct Request: Decodable {
    public typealias Name = String
    typealias Headers = [Key: Value]
    typealias QueryParameters = [Key: Value]

    struct Details: Decodable {
        let url: String
        let method: Method?
        let headers: Headers?
        let query: QueryParameters?
        let body: Body?
        let validation: Validation?
        let delay: Value?
        let log: Value?
    }

    let name: Name
    let details: Details
}


// convenience accessors
extension Request {
    var method: Method { return details.method ?? .get }
    var headers: Headers { return details.headers ?? [:] }
    var query: QueryParameters { return details.query ?? [:] }
    var body: Body? { return details.body }
    var validation: Validation? { return details.validation }
    var delay: TimeInterval {
        guard let value = details.delay else { return 0 }
        switch value {
        case let .int(value):
            return TimeInterval(value)
        case let .double(value):
            return value
        case let .string(value):
            if let v = Int(value) { return TimeInterval(v) }
            else if let v = Double(value) { return v }
            else { return 0 }
        default:
            return 0
        }
    }
    var log: Value? { return details.log }

    var url: URL? {
        var components = URLComponents(string: details.url)
        components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value.string) }
        return components?.url
    }
}


extension Request: Substitutable {
    func substitute(variables: [Key: Value]) throws -> Request {
        let _url = try ResterCore.substitute(string: details.url, with: variables)
        let _headers = try headers.substitute(variables: variables)
        let _query = try query.substitute(variables: variables)
        let _body = try body?.substitute(variables: variables)
        let _validation = try validation?.substitute(variables: variables)
        let _delay = try details.delay?.substitute(variables: variables)
        let _details = Details(
            url: _url,
            method: method,
            headers: _headers,
            query: _query,
            body: _body,
            validation: _validation,
            delay: _delay,
            log: log
        )
        return Request(name: name, details: _details)
    }
}


extension Request {
    public func execute(debug: Bool = false) throws -> Promise<Response> {
        guard let url = url else { throw ResterError.invalidURL(self.details.url) }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue
        if [.post, .put].contains(method) {
            if
                let body = body?.json,
                let postData = try? JSONEncoder().encode(body) {
                urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
                urlRequest.httpBody = postData
            } else if
                let body = body?.form?.formUrlEncoded,
                let postData = body.data(using: .utf8) {
                urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                urlRequest.httpBody = postData
                if debug {
                    print("Request:")
                    dump(urlRequest)
                    print("Body:")
                    dump(body)
                }
            }
        }
        headers.forEach {
            urlRequest.addValue($0.value.string, forHTTPHeaderField: $0.key)
        }

        return after(seconds: delay)
            .then {
                URLSession.shared.dataTask(.promise, with: urlRequest)
            }.map { Response(data: $0.data, response: $0.response as! HTTPURLResponse)

            }.map { response in
                if let value = self.log { print(value: value, of: response) }
                return response
        }
    }

    public func test() throws -> Promise<ValidationResult> {
        return try execute().map { self.validate($0) }
    }

    public func validate(_ response: Response) -> ValidationResult {
        if
            let status = validation?.status,
            case let .invalid(msg, _) = status.validate(Value.int(response.status)) {
            return .invalid("status invalid: \(msg)", value: response.json)
        }

        if
            let headers = validation?.headers,
            case let .invalid(msg, _) = headers.validate(Value.dictionary(response.headers)) {
            return .invalid("status invalid: \(msg)", value: response.json)
        }

        if let jsonMatcher = validation?.json {
            if let json = response.json {
                if case let .invalid(msg, _) = jsonMatcher.validate(json) {
                    return .invalid("json invalid: \(msg)", value: response.json)
                }
            } else {
                return .invalid("failed to decode JSON object from response", value: response.json)
            }
        }
        
        return .valid
    }
}


extension Array where Element == Request {
    subscript(requestName: String) -> Request? {
        return first(where: { $0.name == requestName } )
    }
}


func print(value: Value, of response: Response) {
    switch value {
    case .bool(true):
        ["status", "headers", "json"].forEach { print(value: $0, of: response) }
    case .string("status"):
        Current.console.display(label: "Status", value: response.status)
    case .string("headers"):
        Current.console.display(label: "Headers", value: response.headers)
    case let .string(string) where string.starts(with: "json."):
        let keyPath = string.deletingPrefix("json.")
        if let json = response.json, let value = json[keyPath] {
            Current.console.display(label: keyPath, value: value)
        }
    case .string("json"):
        if let json = response.json {
            Current.console.display(label: "JSON", value: json)
        }
    case let .array(array) where !array.isEmpty:
        for item in array {
            print(value: item, of: response)
        }
    default:
        break
    }
}


