//
//  TaskigTaskTests.swift
//  TaskigDemoTests
//
//  Created by Thomas Sempf on 2017-12-07.
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

class TaskigTaskTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // This test only shows that there are no compilation warnings concerning none discardable results
    func testThatTaskAwaitHasDiscardableResult() {
        let resultValue = "FooBar"
        
        let task = Task<String> { (completion) in
            completion(resultValue)
        }
        
        task.await()
        
        XCTAssert(true)
    }
    
    func testThatTaskAwaitReturnsValueOnSuccess() {
        let resultValue = "FooBar"
        let task = Task<String> { () -> String in
            return resultValue
        }
        
        XCTAssertNoThrow(task.await() == resultValue)
    }
        
    func testThatTaskAsyncCallsCompletionHandlerWithSuccessResult() {
        let expectation = XCTestExpectation()
        
        let resultValue = "FooBar"
        let task = Task<String> { () -> String in
            return resultValue
        }
        
        task.async { (result) in
            XCTAssert(result == resultValue)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testThatTaskCanRunOnMainQueue() {
        let mainThreadExpectation = XCTestExpectation(description: "Running on main thread")
        
        DispatchQueue.global().sync {
            let task = Task<String>(executionQueue: .main) { () -> String in
                XCTAssert(Thread.isMainThread)
                mainThreadExpectation.fulfill()
                return "Done"
            }
            
            task.async(completion: {_ in })
        }
        
        wait(for: [mainThreadExpectation], timeout: 1.0)
    }
    
    func testThatTaskCanRunOnNoneMainQueue() {
        let noneMainThreadExpectation = XCTestExpectation(description: "Running on background thread")
        
        let task = Task<String>(executionQueue: .background) { () -> String in
            XCTAssert(Thread.isMainThread == false)
            noneMainThreadExpectation.fulfill()
            return "Done"
        }
        
        task.async(completion: {_ in })
        
        wait(for: [noneMainThreadExpectation], timeout: 1.0)
    }
    
    func testThatTaskWorksWithLongLastingWork() {
        func encode(message: String) -> String {
            Thread.sleep(forTimeInterval: 0.5)
            return message
        }
        
        func encrypt(message: String) -> Task<String> {
            return Task<String> {
                return encode(message: message)
            }
        }
        
        let message = "Hello"
        XCTAssert(encrypt(message: message).await() == message)
    }
    
    func testThatTaskCanWrapAsynchronousCall() {
        let get = { (url: URL) -> Task<(Data?, URLResponse?, Error?)> in
            return Task<(Data?, URLResponse?, Error?)> { (completion) in
                URLSession(configuration: .ephemeral)
                    .dataTask(with: url, completionHandler: completion)
                    .resume()
            }
        }
        
        let url = URL(string: "https://httpbin.org/delay/1")!
        let (data, response, error) = get(url).await()
        
        XCTAssertNil(error, "Error not nil")
        XCTAssertNotNil(data, "Failed data")
        XCTAssertNotNil(response, "Failed response")
        XCTAssert(response?.url?.absoluteString == "https://httpbin.org/delay/1", "Wrong URL")
    }
    
    func testThatTaskWorksWithOptionalValues() {
        let load = {(path: String) -> Task<Data?> in
            return Task<Data?> {
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
        
        XCTAssertNotNil(load("profile.png").await())
        XCTAssertNotNil(load("index.html").await())
        XCTAssertNil(load("random.txt").await())
    }
    
    func testThatTasksCanBeNested() {
        let emptyString = Task<String> {
            Thread.sleep(forTimeInterval: 0.05)
            return ""
        }
        
        let appendString = {(a: String, b: String) -> Task<String> in
            return Task<String> {
                Thread.sleep(forTimeInterval: 0.05)
                return a + b
            }
        }
        
        let chainedTask = Task<String> { completion in
            emptyString.async(completion: { (s: String) in
                XCTAssert(s == "")
                appendString(s, "https://").async {(s: String) in
                    XCTAssert(s == "https://")
                    appendString(s, "swift").async {(s: String) in
                        XCTAssert(s == "https://swift")
                        appendString(s, ".org").async {(s: String) in
                            XCTAssert(s == "https://swift.org")
                            completion(s)
                        }
                    }
                }
            })
        }
        
        let sequentialTask = Task<String> {
            var s = emptyString.await()
            XCTAssert(s == "")
            s = appendString(s, "https://").await()
            XCTAssert(s == "https://")
            s = appendString(s, "swift").await()
            XCTAssert(s == "https://swift")
            s = appendString(s, ".org").await()
            XCTAssert(s == "https://swift.org")
            return s
        }
        
        XCTAssert(sequentialTask.await() == chainedTask.await())
    }
    
    func testThatTaskExcecuteAsynchronously() {
        let finishExpectation = expectation(description: "Finish")
        
        var a = 0
        
        let task = Task<Void> {
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
    
    func testThatTaskCanWaitAsynchronously() {
        let finishExpectation = expectation(description: "Finish expectation")
        
        var a = 0
        
        Task.async {
            Thread.sleep(forTimeInterval: 0.05)
            XCTAssert(a == 1)
            finishExpectation.fulfill()
        }
        
        Task.await {
            XCTAssert(a == 0)
        }
        
        a = 1
        
        waitForExpectations(timeout: 0.5, handler: nil)
    }
    
    func testThatTaskAwaitRunsSerially() {
        let numbers: [Int] = [0,1,2,3,4,5]
        
        let toStringTask = { (number: Int) -> Task<String> in
            return Task<String> {
                Thread.sleep(forTimeInterval: Double.random(min: 0.01, max: 0.1))
                return "\(number)"
            }
        }
        
        let numersToString = Task<String> {
            var result: String = ""
            
            numbers.forEach({ number in
                result += toStringTask(number).await()
            })
            
            return result
        }
        
        XCTAssert(numersToString.await() == numbers.reduce("", { return $0 + "\($1)"}))
    }
    
    func testThatTaskAsyncRunsInParallel() {
        let numbers: [Int] = [0,1,2,3,4,5]
        let expect = expectation(description: "All tasks finished")
        let lockQueue = DispatchQueue(label: "lock")
        let concurrentQueue = DispatchQueue(label: "concurrent", attributes: .concurrent)
        var result: String = ""
        
        let toStringTask = { (number: Int) -> Task<String> in
            return Task<String>(executionQueue: concurrentQueue) {
                Thread.sleep(forTimeInterval: Double.random(min: 0.01, max: 0.05))
                return "\(number)"
            }
        }
        
        numbers.forEach ({
            toStringTask($0).async { convertedNumber in
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
    
    func testThatTaskVoidAsyncWorks() {
        let finishExpectation = expectation(description: "Finish")
        var a = 0
        
        let voidTask = Task<Void> {
            a = 1
            finishExpectation.fulfill()
        }
        
        voidTask.async()
        
        waitForExpectations(timeout: 0.5) { (_) in
            XCTAssert(a == 1)
        }
    }
    
    func testThatTaskCanBeConvertedToThrowableTask() {
        let finishExpectation = expectation(description: "Finish")
        var a = 0
        
        let voidTask = Task<Void> {
            a = 1
            finishExpectation.fulfill()
        }
        
        voidTask.throwableTask.async()
        
        waitForExpectations(timeout: 0.5) { (_) in
            XCTAssert(a == 1)
        }
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

