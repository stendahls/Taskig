//
//  TaskigDemoTests.swift
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
import Taskig

fileprivate enum TestError: Error {
    case general
}

class TaskigHelpersTests: XCTestCase {
    private func currentQueueName() -> String? {
        let name = __dispatch_queue_get_label(nil)
        return String(cString: name, encoding: .utf8)
    }
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testThatTaskResultUnpackReturnsValueOnSuccess() {
        let value = "FooBar"
        let result = TaskResult<String>.success(value)
        XCTAssert(try result.unpack() == value)
    }
    
    func testThatTaskResultUnpackThrowsOnFailure() {
        let result = TaskResult<String>.failure(TestError.general)
        XCTAssertThrowsError(try result.unpack())
    }
    
    func testThatShortcutUserInteractiveReturnsRightQueue() {
        DispatchQueue.userInteractive.sync {
            XCTAssert(currentQueueName() == DispatchQueue.global(qos: .userInteractive).label)
        }
    }
    
    func testThatShortcutUserInitiatedReturnsRightQueue() {
        DispatchQueue.userInitiated.sync {
            XCTAssert(currentQueueName() == DispatchQueue.global(qos: .userInitiated).label)
        }
    }

    func testThatShortcutUtilityReturnsRightQueue() {
        DispatchQueue.utility.sync {
            XCTAssert(currentQueueName() == DispatchQueue.global(qos: .utility).label)
        }
    }

    func testThatShortcutBackgroundReturnsRightQueue() {
        DispatchQueue.background.sync {
            XCTAssert(currentQueueName() == DispatchQueue.global(qos: .background).label)
        }
    }

}
