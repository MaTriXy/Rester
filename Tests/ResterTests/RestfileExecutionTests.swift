import XCTest

import LegibleError
import Path
import PromiseKit
import Rainbow
import Yams
@testable import ResterCore


final class RestfileExecutionTests: XCTestCase {

    func test_request_order() throws {
        let s = """
            requests:
              first:
                url: http://foo.com
              second:
                url: http://foo.com
              3rd:
                url: http://foo.com
            """
        let rester = try YAMLDecoder().decode(Restfile.self, from: s)
        let names = rester.requests.map { $0.name }
        XCTAssertEqual(names, ["first", "second", "3rd"])
    }

    func test_substitute_env() throws {
        Current.environment = ["TEST_ID": "foo"]
        let s = """
            requests:
              post:
                url: https://httpbin.org/anything
                method: POST
                body:
                  form:
                    value1: v1 ${TEST_ID}
                    value2: v2 ${TEST_ID}
                validation:
                  status: 200
                  json:
                    method: POST
                    form:
                      value1: v1 foo
                      value2: v2 ${TEST_ID}
            """
        let rester = try Rester(yml: s)
        let expectation = self.expectation(description: #function)
        _ = rester.test(before: {_ in}, after: { (name: $0, response: $1, result: $2) })
            .done { results in
                XCTAssertEqual(results.count, 1)
                XCTAssertEqual(results[0].name, "post")
                XCTAssertEqual(results[0].result, .valid)
                expectation.fulfill()
            }
            .catch {
                XCTFail($0.legibleLocalizedDescription)
                expectation.fulfill()
        }
        waitForExpectations(timeout: 5)
    }

    func test_response_array_validation() throws {
        let s = """
            requests:
              post-array:
                url: https://httpbin.org/anything
                method: POST
                body:
                  json:
                    values:
                      - a
                      - 42
                      - c
                validation:
                  status: 200
                  json:
                    json:  # what we post is returned as {"json": {"values": ...}}
                      values:
                        0: a
                        1: 42
                        -1: c
                        -2: 42
                        1: .regex(\\d+)
            """
        let r = try Rester(yml: s)
        let expectation = self.expectation(description: #function)
        _ = r.test(before: {_ in }, after: { (name: $0, response: $1, result: $2) })
            .done { results in
                XCTAssertEqual(results.count, 1)
                XCTAssertEqual(results[0].name, "post-array")
                XCTAssertEqual(results[0].result, .valid)
                expectation.fulfill()
            }.catch {
                XCTFail($0.legibleLocalizedDescription)
                expectation.fulfill()
        }
        waitForExpectations(timeout: 5)
    }

    func test_response_variable_legacy() throws {
        // Tests references a value from a previous request's response
        // (legacy syntax .1 to reference array element at index 1)
        let s = """
            requests:
              post-array:
                url: https://httpbin.org/anything
                method: POST
                body:
                  json:
                    values:
                      - a
                      - 42
                      - c
              reference:
                url: https://httpbin.org/anything/${post-array.json.values.1}  # sending 42
                validation:
                  status: 200
                  json:  # url is mirrored back in json response
                    url: https://httpbin.org/anything/42
            """
        let r = try Rester(yml: s)
        let expectation = self.expectation(description: #function)
        _ = r.test(before: {_ in }, after: { (name: $0, response: $1, result: $2) })
            .done { results in
                XCTAssertEqual(results.count, 2)
                XCTAssertEqual(results[0].name, "post-array")
                XCTAssertEqual(results[0].result, .valid)
                XCTAssertEqual(results[1].name, "reference")
                XCTAssertEqual(results[1].result, .valid)
                expectation.fulfill()
            }.catch {
                XCTFail($0.legibleLocalizedDescription)
                expectation.fulfill()
        }
        waitForExpectations(timeout: 5)
    }

    func test_response_variable() throws {
        // Tests references a value from a previous request's response
        // (using syntax [1] to reference array element at index 1)
        let s = """
            requests:
              post-array:
                url: https://httpbin.org/anything
                method: POST
                body:
                  json:
                    values:
                      - a
                      - 42
                      - c
              reference:
                url: https://httpbin.org/anything/${post-array.json.values[1]}  # sending 42
                validation:
                  status: 200
                  json:  # url is mirrored back in json response
                    url: https://httpbin.org/anything/42
            """
        let r = try Rester(yml: s)
        let expectation = self.expectation(description: #function)
        _ = r.test(before: {_ in }, after: { (name: $0, response: $1, result: $2) })
            .done { results in
                XCTAssertEqual(results.count, 2)
                XCTAssertEqual(results[0].name, "post-array")
                XCTAssertEqual(results[0].result, .valid)
                XCTAssertEqual(results[1].name, "reference")
                XCTAssertEqual(results[1].result, .valid)
                expectation.fulfill()
            }.catch {
                XCTFail($0.legibleLocalizedDescription)
                expectation.fulfill()
        }
        waitForExpectations(timeout: 5)
    }

}
