//
//  ThrowableTask.swift
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

public struct ThrowableTask<T>: ThrowableTaskType {
    public typealias ResultType = T
    
    public let executionQueue: DispatchQueue
    
    private let actionBlock: (@escaping resultHandler) -> Void
    
    public var isCancelled: Bool = false
    
    public init(executionQueue: DispatchQueue = .global(), action: @escaping (@escaping resultHandler) -> Void) {
        self.actionBlock = action
        self.executionQueue = executionQueue
    }
    
    public init(executionQueue: DispatchQueue = .global(), action: @escaping () throws -> T) {
        self.executionQueue = executionQueue
        self.actionBlock = { (completion) in
            do {
                let result = try action()
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    public func action(completion: @escaping resultHandler) {
        actionBlock(completion)
    }
}

public extension ThrowableTask where T == Void {
    public func async() {
        executionQueue.async {
            self.action(completion: { (_) in })
        }
    }
}

extension ThrowableTask: CancellableTaskType {
    @discardableResult
    public func awaitResult() -> TaskResult<ResultType> {
        precondition((executionQueue == .main && Thread.isMainThread == true) == false)
        
        var result: TaskResult<ResultType>!
        
        let group = DispatchGroup()
        group.enter()
        
        executionQueue.async {
            guard self.isCancelled == false else {
                result = .failure(CancellableTaskError.taskWasCancelled)
                group.leave()
                return
            }
            
            self.action(completion: { (actionResult) in
                result = actionResult
                group.leave()
            })
        }
        
        group.wait()
        
        return result
    }

    public func async(completion: @escaping resultHandler) {
        executionQueue.async {
            guard self.isCancelled == false else {
                completion(.failure(CancellableTaskError.taskWasCancelled))
                return
            }
            
            self.action(completion: completion)
        }
    }
}
