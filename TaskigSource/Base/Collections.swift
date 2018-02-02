//
//  Collections.swift
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

public let DefaultConcurrency = 50

let async_custom_queue = DispatchQueue(label: "taskig.serial.queue")

public enum TaskigError: Error {
    case emptySequence
}

// MARK: - Await support for Dictionary

public extension Dictionary where Value : ThrowableTaskType {
    func awaitFirst(_ queue: DispatchQueue = .global(), concurrency: Int = DefaultConcurrency) throws -> Value.ResultType {
        return try values.awaitFirst(queue, concurrency: concurrency)
    }
    
    func awaitAll(_ queue: DispatchQueue = .global(), concurrency: Int = DefaultConcurrency) throws -> [Key: Value.ResultType] {
        let elements = Array(zip(Array(keys), try values.awaitAll(queue, concurrency: concurrency)))
        return Dictionary<Key, Value.ResultType>(uniqueKeysWithValues: elements)
    }
    
    func awaitAllResults(_ queue: DispatchQueue = .global(), concurrency: Int = DefaultConcurrency) -> [Key: TaskResult<Value.ResultType>] {
        let elements = Array(zip(Array(keys), values.awaitAllResults(queue, concurrency: concurrency)))
        return Dictionary<Key, TaskResult<Value.ResultType>>(uniqueKeysWithValues: elements)
    }
}

public extension Dictionary where Value : TaskType {
    var throwableTasks: [ThrowableTask<Value.ResultType>] {
        return values.throwableTasks
    }
    
    func awaitFirst(_ queue: DispatchQueue = .global(), concurrency: Int = DefaultConcurrency) -> Value.ResultType {
        return try! throwableTasks.awaitFirst(queue, concurrency: concurrency)
    }
    
    func awaitAll(_ queue: DispatchQueue = .global(), concurrency: Int = DefaultConcurrency) -> [Key: Value.ResultType] {
        let elements = Array(zip(Array(keys), try! throwableTasks.awaitAll(queue, concurrency: concurrency)))
        return Dictionary<Key, Value.ResultType>(uniqueKeysWithValues: elements)
    }
}

// MARK: - Await support for Sequence

public extension Sequence where Iterator.Element: ThrowableTaskType {
    func awaitFirstResult(_ queue: DispatchQueue = .global(), concurrency: Int = DefaultConcurrency) -> TaskResult<Iterator.Element.ResultType> {
        let tasks = map{$0}
        
        guard tasks.count > 0 else {
            return TaskResult.failure(TaskigError.emptySequence)
        }
        
        return Task.await(executionQueue: queue) { () -> TaskResult<Self.Element.ResultType> in
            var result: TaskResult<Self.Element.ResultType>!
            
            tasks.concurrentForEach(queue,
                                    concurrency: concurrency,
                                    transform: { $0.awaitResult() },
                                    completion: { result == nil ? result = $0 : () })
            
            return result
        }
    }
    
    func awaitAllResults(_ queue: DispatchQueue = .global(), concurrency: Int = DefaultConcurrency) -> [TaskResult<Iterator.Element.ResultType>] {
        let tasks = map{$0}
        
        return tasks.concurrentMap(queue, concurrency: concurrency) {task in task.awaitResult()}
    }
    
    func awaitFirst(_ queue: DispatchQueue = .global(), concurrency: Int = DefaultConcurrency) throws -> Iterator.Element.ResultType {
        return try awaitFirstResult(queue, concurrency: concurrency).unpack()
    }
    
    func awaitAll(_ queue: DispatchQueue = .global(), concurrency: Int = DefaultConcurrency) throws -> [Iterator.Element.ResultType] {
        return try awaitAllResults(queue, concurrency: concurrency).map{ try $0.unpack() }
    }
}

public extension Sequence where Iterator.Element : TaskType {
    var throwableTasks: [ThrowableTask<Iterator.Element.ResultType>] {
        return map {$0.throwableTask}
    }
    
    func awaitFirst(_ queue: DispatchQueue = .global(), concurrency: Int = DefaultConcurrency) -> Iterator.Element.ResultType {
        return try! throwableTasks.awaitFirst(queue)
    }
    
    func awaitAll(_ queue: DispatchQueue = .global(), concurrency: Int = DefaultConcurrency) -> [Iterator.Element.ResultType] {
        return try! throwableTasks.awaitAll(queue, concurrency: concurrency)
    }
    
}

// MARK: - Helpers

public extension Array {
    func concurrentForEach<T>(_ queue: DispatchQueue, concurrency: Int, transform: @escaping (Element) -> T, completion: @escaping (T) -> ()) {
        let workGroup = DispatchGroup()
        let maxWorkItemsSemaphore = DispatchSemaphore(value: concurrency)
        
        self.forEach ({ task in
            maxWorkItemsSemaphore.wait()
            workGroup.enter()
            
            queue.async(group: workGroup) {
                let result = transform(task)
                
                async_custom_queue.sync {
                    completion(result)
                    workGroup.leave()
                    maxWorkItemsSemaphore.signal()
                }
            }
        })
        
        workGroup.wait()
    }
    
    func concurrentMap<T>(_ queue: DispatchQueue, concurrency: Int, transform: @escaping (Element) -> T) -> [T] {
        guard count > 0 else {
            return []
        }
        
        let finishedAllTasksSemaphore = DispatchSemaphore(value: 0)
        let maxWorkItemsSemaphore = DispatchSemaphore(value: concurrency)
        
        var results = [T?](repeating: nil, count: count)
        var numberOfCompletedTasks = 0
        let numberOfTasks = count
        
        DispatchQueue.concurrentPerform(iterations: count) {index in
            let _ = maxWorkItemsSemaphore.wait()
            let result = transform(self[index])
            
            async_custom_queue.sync {
                results[index] = result
                numberOfCompletedTasks += 1
                
                if numberOfCompletedTasks == numberOfTasks {
                    finishedAllTasksSemaphore.signal()
                }
                
                maxWorkItemsSemaphore.signal()
            }
        }
        
        let _ = finishedAllTasksSemaphore.wait()
        return results.flatMap {$0}
    }
}


