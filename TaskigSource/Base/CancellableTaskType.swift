//
//  CancellableTask.swift
//  TaskigDemo
//
//  Created by Thomas Sempf on 2018-01-26.
//  Copyright © 2018 Stendahls AB. All rights reserved.
//

import Foundation

public protocol CancellableTaskType {
    var isCancelled: Bool { get }
}

public enum CancellableTaskError: Error {
    case taskWasCancelled
}
