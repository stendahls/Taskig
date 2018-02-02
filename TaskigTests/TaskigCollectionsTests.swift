//
//  TaskigCollectionsTests.swift
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

// MARK: - Helpers

fileprivate extension Collection {
    /// Return a copy of `self` with its elements shuffled
    func shuffle() -> [Iterator.Element] {
        var list = Array(self)
        list.shuffle()
        return list
    }
}

fileprivate extension MutableCollection where Index == Int {
    /// Shuffle the elements of `self` in-place.
    mutating func shuffle() {
        // empty and single-element collections don't shuffle
        if count < 2 { return }
        
        for i in startIndex ..< endIndex - 1 {
            let j = Int(arc4random_uniform(UInt32(endIndex - i))) + i
            if i != j {
                //                swap(&self[i], &self[j])
                self.swapAt(i, j)
            }
        }
    }
}

fileprivate let numbers: [Int] = (0...9).map{ $0 }

fileprivate func toString(_ number: Int) -> Task<String> {
    return Task { "\(number)" }
}

fileprivate func timeout(forTimeInterval timeout: TimeInterval) -> Task<Void> {
    return Task { Thread.sleep(forTimeInterval: timeout) }
}

fileprivate func toStringAfter(_ number: Int, timeoutInterval: TimeInterval) -> Task<String> {
    return Task {
        timeout(forTimeInterval: timeoutInterval).await()
        return toString(number).await()
    }
}

fileprivate enum TestError : Error {
    case FoundZero
}

fileprivate let toStringExceptZero = {(number: Int) -> ThrowableTask<String> in
    ThrowableTask {
        if number == 0 {
            throw TestError.FoundZero
        }
        return "\(number)"
    }
}

extension String: Error {}

class TaskigCollectionsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testThatAwaitWorksInsideMap() {
        let results = numbers.map {number in toString(number).await()}
        XCTAssert(results == numbers.map {number in "\(number)"})
    }
    
    func testThatAwaitAllWorksWithEmptyArrayOfTasks() {
        let finishExpectation = expectation(description: "Finish expectation")
        
        DispatchQueue.global().async {
            let noTasks: [Task<Void>] = []
            
            let results = noTasks.awaitAll()
            
            XCTAssert(results.count == 0)
            
            finishExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testThatAwaitAllWorksWithArrayOfTasks() {
        for _ in 0..<1000 {
            let results = numbers.map(toString).awaitAll()
            
            numbers.forEach({ number in
                XCTAssert(results.contains("\(number)"))
            })
        }
    }
    
    func testThatAwaitAllWorksWithArrayOfNestedTasks() {
        for _ in 0..<10 {
            let results = (0..<500).map({n in toStringAfter(n, timeoutInterval: 0.0001)}).awaitAll()
            XCTAssert(results.count == 500)
        }
        
        let results = (0..<5000).map({n in toStringAfter(n, timeoutInterval: 0.0001)}).awaitAll()
        XCTAssert(results.count == 5000)
    }
    
    func testThatTasksInDictionaryOfClosuresRunInParallel() {
        var tasks = [Int: Task<String>]()
        
        for (index, element) in numbers.map(toString).enumerated() {
            let key = numbers[index]
            tasks[key] = element
        }
        let results = tasks.awaitAll()
        
        var expected = [Int: String]()
        for number in numbers {
            expected[number] = "\(number)"
        }
        
        XCTAssert(results.count == expected.count)
        
        for (key, _) in expected {
            XCTAssert(expected[key] == results[key])
        }
    }
    
    func testThatAwaitFirstWorks() {
        let result = numbers
            .shuffle()
            .map {number in toStringAfter(number, timeoutInterval: TimeInterval(Double(number) / 100 + 0.1))}
            .awaitFirst()
        
        XCTAssert(result == "0")
    }
    
    func testThatAwaitFirstWorksWithOptionals() {
        let task1 = Task<String?> {
            timeout(forTimeInterval: 2).await()
            return "aa"
        }
        
        let task2 = Task<String?> {
            timeout(forTimeInterval: 1).await()
            return nil
        }
        
        XCTAssert([task1, task2].awaitFirst() == nil)
    }
    
    func testThatAwaitFirstWorksWithEmptyArrayOfThrowableTasks() {
        let finishExpectation = expectation(description: "Finish expectation")
        
        DispatchQueue.global().async {
            do {
                let noTasks: [ThrowableTask<Void>] = []
                
                try noTasks.awaitFirst()
            } catch {
                finishExpectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testThatAwaitFirstWorksWithOnDictionary() {
        func testThatAwaitFirstWorks() {
            let result = numbers
                .shuffle()
                .reduce(into: [Int: Task<String>](), { (dictionary, number) in
                    dictionary[number] = toStringAfter(number, timeoutInterval: TimeInterval(Double(number) / 100 + 0.1))
                })
                .awaitFirst()
            
            XCTAssert(result == "1")
        }
    }
    
    func testThatAwaitFirstWorksWithThrowableTasksOnDictionary() {
        func testThatAwaitFirstWorks() {
            do {
                let result = try numbers
                    .shuffle()
                    .reduce(into: [Int: ThrowableTask<String>](), { (dictionary, number) in
                        dictionary[number] = toStringAfter(number, timeoutInterval: TimeInterval(Double(number) / 100 + 0.1)).throwableTask
                    })
                    .awaitFirst()
                
                XCTAssert(result == "1")
            } catch {
                XCTAssert(true)
            }
        }
    }
    
    func testThatAwaitAllWorksWithThrowableTasks() {
        XCTAssertThrowsError(try numbers.map(toStringExceptZero).awaitAll())
    }
    
    func testThatAwaitAllWorksWithEmptyArrayOfThrowabeTasks() {
        let finishExpectation = expectation(description: "Finish expectation")
        
        DispatchQueue.global().async {
            do {
                let noTasks: [ThrowableTask<Void>] = []
                
                let results = try noTasks.awaitAll()
                
                XCTAssert(results.count == 0)
                
                finishExpectation.fulfill()
            } catch {
                XCTFail("Error thrown")
            }
        }
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testThatAwaitFirstWorksWithThrowableTasks() {
        let task1 = ThrowableTask<String> {
            timeout(forTimeInterval: 0.1).await()
            let result = try toStringExceptZero(0).await()
            return result
        }
        
        let task2 = ThrowableTask<String> { () -> String in
            timeout(forTimeInterval: 1).await()
            return "aa"
        }
        
        XCTAssertThrowsError(try [task1, task2].awaitFirst())
    }
    
    func testThatConcurrencyParameterWorks() {
        var finishedTaskOne = false
        
        let task1 = ThrowableTask<String> {
            timeout(forTimeInterval: 0.1).await()
            finishedTaskOne = true
            return "foo"
        }
        
        let task2 = ThrowableTask<String> { () -> String in
            guard finishedTaskOne == true else {
                throw "Task one was not finished before execution"
            }
            
            return "bar"
        }
        
        let tasks = [task1, task2]
        
        XCTAssertThrowsError(try tasks.awaitAll())
        
        finishedTaskOne = false
        
        XCTAssertNoThrow(try tasks.awaitAll(.global(), concurrency: 1))
        
        finishedTaskOne = false
        
        XCTAssertThrowsError(try tasks.awaitFirst())
        
        finishedTaskOne = false
        
        XCTAssertNoThrow(try tasks.awaitFirst(concurrency: 1))
    }
}
