//
//  ValueTests.swift
//  ResterTests
//
//  Created by Sven A. Schmidt on 27/01/2019.
//

import XCTest
@testable import ResterCore

import Yams


class ValueTests: XCTestCase {

    func test_decodeBasicTypes() throws {
        let s = """
              int: 42
              string: some string value
              stringColon: 'foo: bar'
              double: 3.14
              dict:
                a: 1
                b: two
              array:
                - 1
                - two
                - foo: bar
            """
        struct Test: Decodable {
            let int: Value
            let string: Value
            let stringColon: Value
            let double: Value
            let dict: Value
            let array: Value
        }
        let t = try YAMLDecoder().decode(Test.self, from: s)
        XCTAssertEqual(t.int, .int(42))
        XCTAssertEqual(t.string, .string("some string value"))
        XCTAssertEqual(t.stringColon, .string("foo: bar"))
        XCTAssertEqual(t.double, .double(3.14))
        XCTAssertEqual(t.dict, .dictionary(["a": .int(1), "b": .string("two")]))
        XCTAssertEqual(t.array, .array([
            .int(1),
            .string("two"),
            .dictionary(["foo": .string("bar")])
            ]))
    }

    func test_encodeBasicTypes() throws {
        struct Test: Encodable {
            let int: Value
            let string: Value
            let stringColon: Value
            let double: Value
            let dict: Value
            let array: Value
        }
        let t = Test(
            int: .int(42),
            string: .string("some string value"),
            stringColon: .string("foo: bar"),
            double: .double(3.14),
            dict: .dictionary(["a": .int(1)]),
            array: .array([
                .int(1),
                .string("two"),
                .dictionary(["foo": .string("bar")])
                ])
        )
        let s = try YAMLEncoder().encode(t)
        XCTAssertEqual(s, """
              int: 42
              string: some string value
              stringColon: 'foo: bar'
              double: 3.14e+0
              dict:
                a: 1
              array:
              - 1
              - two
              - foo: bar

              """)
    }
}
