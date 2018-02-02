//
//  TaskigCancellableTaskTests.swift
//  TaskigTestsOSX
//
//  Created by Thomas Sempf on 2018-01-26.
//  Copyright © 2018 Stendahls AB. All rights reserved.
//

import XCTest
import Taskig

class TaskigCancellableTaskTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testThatThrowableTaskAsyncCanBeCancelled() {
        let resultValue = "FooBar"
        let finishExpectation = expectation(description: "Finish")
        
        var task = ThrowableTask<String> { () -> String in
            XCTAssert(false, "Should never be called for a cancelled task")
            return resultValue
        }
        
        task.isCancelled = true
        
        task.async { (completion) in
            defer { finishExpectation.fulfill() }
            guard case TaskResult.failure(CancellableTaskError.taskWasCancelled) = completion else {
                XCTAssert(false, "Result was not CancellableTaskError.taskWasCancelled")
                return
            }
        }
        
        wait(for: [finishExpectation], timeout: 0.5)
    }
    
    func testThatThrowableTaskAwaitCanBeCancelled() {
        let resultValue = "FooBar"
        
        var task = ThrowableTask<String> { () -> String in
            XCTAssert(false, "Should never be called for a cancelled task")
            return resultValue
        }
        
        task.isCancelled = true
        
        XCTAssertThrowsError(try task.await())
    }
    
    func testThatThrowableTaskAwaitResultCanBeCancelled() {
        let resultValue = "FooBar"
        
        var task = ThrowableTask<String> { () -> String in
            XCTAssert(false, "Should never be called for a cancelled task")
            return resultValue
        }
        
        task.isCancelled = true
        
        guard case TaskResult.failure(CancellableTaskError.taskWasCancelled) = task.awaitResult() else {
            XCTAssert(false, "Result was not CancellableTaskError.taskWasCancelled")
            return
        }
    }
    
    func testThatCancelWorksWithAnArrayOfThrowableTasks() {
        var tasks = (0..<10)
            .map({ number in
                ThrowableTask<String>(action: { () -> String in
                    return "\(number)"
                })
            })
        
        tasks[7].isCancelled = true
        
        let successCount = tasks.awaitAllResults()
            .flatMap({ try? $0.unpack() })
            .count
        
        XCTAssertTrue(successCount == 9)

        XCTAssertThrowsError(try tasks.awaitAll())
        
        XCTAssertNoThrow(try tasks.awaitFirst())
        
        XCTAssertThrowsError(try [tasks[7]].awaitFirst())
    }
    
    func testThatCancelWorksWithDictionaryOfThrowableTasks() {
        var taskDictionary = (0..<10)
            .reduce(into: [Int: ThrowableTask<String>]()) { ( dict, number) in
                let value = number
                dict[value] = ThrowableTask<String>(action: { () -> String in
                    return "\(value)"
                })
            }
        
        taskDictionary[7]?.isCancelled = true
        
        let successCount = taskDictionary.awaitAllResults()
            .flatMap({ try? $0.value.unpack() })
            .count
        
        XCTAssertTrue(successCount == 9)
        
        XCTAssertThrowsError(try taskDictionary.awaitAll())
        
        XCTAssertNoThrow(try taskDictionary.awaitFirst())
        
        XCTAssertThrowsError(try [7: taskDictionary[7]!].awaitFirst())
    }
}

