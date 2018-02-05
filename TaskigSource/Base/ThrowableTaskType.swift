//
//  ThrowableTaskType.swift
//  TaskigDemo
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

import Foundation

public protocol ThrowableTaskType {
    associatedtype ResultType
    
    typealias resultHandler = (TaskResult<ResultType>) -> Void
    
    var executionQueue: DispatchQueue { get }
    
    func action(completion: @escaping resultHandler)
    
    func await() throws -> ResultType
    func awaitResult() -> TaskResult<ResultType>
    func async(completion: @escaping resultHandler)
}

public extension ThrowableTaskType {
    @discardableResult
    public func awaitResult() -> TaskResult<ResultType> {
        precondition((executionQueue == .main && Thread.isMainThread == true) == false)
        
        var result: TaskResult<ResultType>!
        
        let group = DispatchGroup()
        group.enter()
        
        executionQueue.async {
            self.action(completion: { (actionResult) in
                result = actionResult
                group.leave()
            })
        }
        
        group.wait()
        
        return result
    }
    
    @discardableResult
    public func await() throws -> ResultType {
        return try awaitResult().unpack()
    }
    
    public func async(completion: @escaping resultHandler) {
        executionQueue.async {
            self.action(completion: completion)
        }
    }
    
    @discardableResult
    public static func await(executionQueue: DispatchQueue = .global(), action: @escaping () throws -> ResultType) throws -> ResultType {
        let task = ThrowableTask<ResultType> { () -> Self.ResultType in
           return try action()
        }
        
        return try task.await()
    }
}
