//
//  TaskigThrowableTaskTests.swift
//  TaskigDemoTests
//
//  Created by Thomas Sempf on 2017-12-08.
//  Copyright © 2017 Stendahls AB. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import XCTest
@testable import Taskig

fileprivate enum TestError: Error {
    case general
}

class TaskigThrowableTaskTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // This test only shows that there are no compilation warnings concerning none discardable results
    func testThatThrowableTaskAwaitHasDiscardableResult() {
        let resultValue = "FooBar"
        let task = ThrowableTask<String> { (completion) in
            completion(.success(resultValue))
        }
        
        do {
            try task.await()
        } catch {
            // nothing
        }
        
        XCTAssert(true)
    }
    
    func testThatThrowableTaskAwaitReturnsValueOnSuccess() {
        let resultValue = "FooBar"
        let task = ThrowableTask<String> { () -> String in
            return resultValue
        }
        
        XCTAssertNoThrow(try task.await() == resultValue)
    }
    
    func testThatThrowableTaskAwaitThrowsOnFailure() {
        let task = ThrowableTask<String> { () -> String in
            throw TestError.general
        }
        
        XCTAssertThrowsError(try task.await())
    }
    
    func testThatThrowableTaskAwaitResultReturnsCorrectResult() {
        let taskFailure = ThrowableTask<String> { () -> String in
            throw TestError.general
        }
        
        let taskSuccess = ThrowableTask<String> { () -> String in
            return "foobar"
        }
        
        guard case let .success(text) = taskSuccess.awaitResult() else {
            return XCTFail("Expected success result")
        }
        
        XCTAssert(text == "foobar")
        
        guard case let .failure(error) = taskFailure.awaitResult(), case TestError.general = error else {
            return XCTFail("Expected failure result")
        }
    }
    
    func testThatThrowableTaskAsyncCallsCompletionHandlerWithSuccessResult() {
        let expectation = XCTestExpectation()
        
        let resultValue = "FooBar"
        let task = ThrowableTask<String> { () -> String in
            return resultValue
        }
        
        task.async { (result) in
            if case .success(let value) = result {
                XCTAssert(value == resultValue)
            } else {
                XCTAssertTrue(false)
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testThatThrowableTaskAsyncCallsCompletionHandlerWithFailureResult() {
        let expectation = XCTestExpectation()
        
        let task = ThrowableTask<String> { () -> String in
            throw TestError.general
        }
        
        task.async { (result) in
            if case .failure(let error) = result {
                XCTAssert((error as? TestError) == .general)
            } else {
                XCTAssertTrue(false)
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testThatThrowableTaskCanRunOnMainQueue() {
        let mainThreadExpectation = XCTestExpectation(description: "Running on main thread")
        
        DispatchQueue.global().sync {
            let task = ThrowableTask<String>(executionQueue: .main) { () -> String in
                XCTAssert(Thread.isMainThread)
                mainThreadExpectation.fulfill()
                return "Done"
            }
            
            task.async(completion: {_ in })
        }
        
        wait(for: [mainThreadExpectation], timeout: 1.0)
    }
    
    func testThatThrowableTaskCanRunOnNoneMainQueue() {
        let noneMainThreadExpectation = XCTestExpectation(description: "Running on main thread")
        
        let task = ThrowableTask<String>(executionQueue: .background) { () -> String in
            XCTAssert(Thread.isMainThread == false)
            noneMainThreadExpectation.fulfill()
            return "Done"
        }
        
        task.async(completion: {_ in })
        
        wait(for: [noneMainThreadExpectation], timeout: 1.0)
    }
    
    func testThatThrowableTaskWorksWithLongLastingWork() {
        func encode(message: String) -> String {
            Thread.sleep(forTimeInterval: 0.5)
            return message
        }
        
        func encrypt(message: String) -> ThrowableTask<String> {
            return ThrowableTask<String> {
                return encode(message: message)
            }
        }
        
        let message = "Hello"
        XCTAssert(try encrypt(message: message).await() == message)
    }
    
    func testThatThrowableTaskCanWrapAsynchronousCall() {
        let get = { (url: URL) -> ThrowableTask<(Data?, URLResponse?)> in
            return ThrowableTask<(Data?, URLResponse?)> { (completion) in
                URLSession(configuration: .ephemeral)
                    .dataTask(with: url, completionHandler: { (data, response, error) in
                        guard error == nil else {
                            completion(.failure(error!))
                            return
                        }
                        
                        completion(.success((data, response)))
                    })
                    .resume()
            }
        }
        
        do {
            let url = URL(string: "https://httpbin.org/delay/1")!
            let (data, response) = try get(url).await()
            
            XCTAssertNotNil(data, "Failed data")
            XCTAssertNotNil(response, "Failed response")
            XCTAssert(response?.url?.absoluteString == "https://httpbin.org/delay/1", "Wrong URL")
        } catch {
            XCTAssertTrue(false, "Network called failed")
        }
    }
    
    func testThatThrowableTaskWorksWithOptionalValues() {
        let load = {(path: String) -> ThrowableTask<Data?> in
            return ThrowableTask<Data?> {
                Thread.sleep(forTimeInterval:0.05)
                
                switch path {
                case "profile.png":
                    return Data()
                case "index.html":
                    return Data()
                default:
                    return nil
                }
            }
        }
        
        XCTAssertNotNil(try load("profile.png").await())
        XCTAssertNotNil(try load("index.html").await())
        XCTAssertNil(try load("random.txt").await())
    }
    
    func testThatThrowableTasksCanBeNested() {
        let emptyString = ThrowableTask<String> {
            Thread.sleep(forTimeInterval: 0.05)
            return ""
        }
        
        let appendString = {(a: String, b: String) -> ThrowableTask<String> in
            return ThrowableTask<String> {
                Thread.sleep(forTimeInterval: 0.05)
                return a + b
            }
        }
        
        let chainedTask = ThrowableTask<String> { completion in
            emptyString.async(completion: { (result) in
                let s = try! result.unpack()
                XCTAssert(s == "")
                appendString(s, "https://").async { (result) in
                    let s = try! result.unpack()
                    XCTAssert(s == "https://")
                    appendString(s, "swift").async { (result) in
                        let s = try! result.unpack()
                        XCTAssert(s == "https://swift")
                        appendString(s, ".org").async { (result) in
                            let s = try! result.unpack()
                            XCTAssert(s == "https://swift.org")
                            completion(.success(s))
                        }
                    }
                }
            })
        }
        
        let sequentialTask = ThrowableTask<String> {
            var s = try emptyString.await()
            XCTAssert(s == "")
            s = try appendString(s, "https://").await()
            XCTAssert(s == "https://")
            s = try appendString(s, "swift").await()
            XCTAssert(s == "https://swift")
            s = try appendString(s, ".org").await()
            XCTAssert(s == "https://swift.org")
            return s
        }
        
        XCTAssert(try sequentialTask.await() == chainedTask.await())
    }
    
    func testThatThrowableTaskExcecuteAsynchronously() {
        let finishExpectation = expectation(description: "Finish")
        
        var a = 0
        
        let task = ThrowableTask<Void> {
            Thread.sleep(forTimeInterval: 0.2)
            
            XCTAssert(a == 0)
            
            a = 1
            
            XCTAssert(a == 1)
        }
        
        task.async { (_) in
            XCTAssert(a == 1)
            
            finishExpectation.fulfill()
        }
        
        Thread.sleep(forTimeInterval: 0.05)
        XCTAssert(a == 0)
        
        waitForExpectations(timeout: 0.5) { (_) in
            XCTAssert(a == 1)
        }
    }
    
    func testThatThrowableTaskCanWaitAsynchronously() {
        let finishExpectation = expectation(description: "Finish expectation")
        
        var a = 0
        
        Task<Void>.async {
            Thread.sleep(forTimeInterval: 0.05)
            XCTAssert(a == 1)
            finishExpectation.fulfill()
        }
        
        try? ThrowableTask<Void>.await {
            XCTAssert(a == 0)
        }
        
        a = 1
        
        waitForExpectations(timeout: 0.5, handler: nil)
    }
    
    func testThatThrowableTaskAwaitRunsSerially() {
        let numbers: [Int] = [0,1,2,3,4,5]
        
        let toStringTask = { (number: Int) -> ThrowableTask<String> in
            return ThrowableTask<String> {
                Thread.sleep(forTimeInterval: Double.random(min: 0.01, max: 0.1))
                return "\(number)"
            }
        }
        
        let numersToString = ThrowableTask<String> {
            var result: String = ""
            
            numbers.forEach({ number in
                result += try! toStringTask(number).await()
            })
            
            return result
        }
        
        XCTAssert(try numersToString.await() == numbers.reduce("", { return $0 + "\($1)"}))
    }
    
    func testThatThrowableTaskAsyncRunsInParallel() {
        let numbers: [Int] = [0,1,2,3,4,5]
        let expect = expectation(description: "All tasks finished")
        let lockQueue = DispatchQueue(label: "lock")
        let concurrentQueue = DispatchQueue(label: "concurrent", attributes: .concurrent)
        var result: String = ""
        
        let toStringTask = { (number: Int) -> ThrowableTask<String> in
            return ThrowableTask<String>(executionQueue: concurrentQueue) {
                Thread.sleep(forTimeInterval: Double.random(min: 0.01, max: 0.05))
                return "\(number)"
            }
        }
        
        numbers.forEach ({
            toStringTask($0).async { taskResult in
                let convertedNumber = try! taskResult.unpack()
                lockQueue.sync {
                    result = result + convertedNumber
                    
                    if result.count >= numbers.count {
                        expect.fulfill()
                    }
                }
            }
        })
        
        waitForExpectations(timeout: 5)
        
        XCTAssertTrue(result != numbers.map{String($0)}.joined())
        
        numbers.forEach({ number in
            XCTAssert(result.contains("\(number)"))
        })
    }
    
    func testThatCustomThrowableTaskTypeWorks() {
        let expectation = XCTestExpectation()

        let customTask = CustomThrowableTask(executionQueue: .global())
        
        guard case let .success(text) = customTask.awaitResult(), text == "foobar" else {
            return XCTFail("False result value, expected success and foobar as text")
        }
        
        do {
            let text = try customTask.await()
            XCTAssert(text == "foobar")
        } catch {
            return XCTFail("Expected no throw")
        }
        
        customTask.async { (result) in
            guard case let .success(text) = result, text == "foobar" else {
                return XCTFail("False result value, expected success and foobar as text")
            }
            
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 0.1)
    }
    
    func testThatStaticAwaitFunctionWorks() {
        do {
            let text = try ThrowableTask<String>.await(executionQueue: .global()) { () -> String in
                return "foobar"
            }
            XCTAssert(text == "foobar")
        } catch {
            return XCTFail("Expected no throw")
        }
        
        XCTAssertThrowsError(try ThrowableTask<String>.await(executionQueue: .global(), action: { () -> String in
            throw "Error"
        }))
    }
}

fileprivate struct CustomThrowableTask: ThrowableTaskType {
    typealias ResultType = String
    
    var executionQueue: DispatchQueue
    
    func action(completion: @escaping (TaskResult<String>) -> Void) {
        completion(.success("foobar"))
    }
}

// Helpers
fileprivate extension Double {
    static var random: Double {
        get {
            return Double(arc4random()) / 0xFFFFFFFF
        }
    }
    
    
    static func random(min: Double, max: Double) -> Double {
        return Double.random * (max - min) + min
    }
}
