# Taskig

[![CI Status](http://img.shields.io/travis/stendahls/Taskig.svg?style=flat)](https://travis-ci.org/stendahls/Taskig)
[![Version](https://img.shields.io/cocoapods/v/Taskig.svg?style=flat)](http://cocoapods.org/stendahls/Taskig)
[![License](https://img.shields.io/cocoapods/l/Taskig.svg?style=flat)](http://cocoapods.org/stendahls/Taskig)
[![Platform](https://img.shields.io/cocoapods/p/Taskig.svg?style=flat)](http://cocoapods.org/stendahls/Taskig)

An async/await inspired library which makes asynchronous programming in Swift a joy!

Taskig makes it easy to execute code on different threads, e.g. background or main, and then compose these tasks via async/await methodology. Taskig was heavily inspired by AsyncTask (https://github.com/zhxnlai/AsyncTask)

## Features
- Taskig is **composable**, allowing you to build complex workflow.
- Taskig supports native **error handling** with `do-catch` and `try`.
- Taskig is **protocol oriented**; you can turn any object into a Task.

Without Taskig:
```swift
// submit a task to the global queue for background execution
DispatchQueue.global(qos: .userInteractive).async {
    let enhancedImage = self.applyImageFilter(image) // expensive operation taking a few seconds

    // update UI on the main queue
    DispatchQueue.main.async {
        self.imageView.image = enhancedImage

        UIView.animateWithDuration(0.3, animations: {
            self.imageView.alpha = 1
        }) { completed in
            // add code to happen next here
        }
    }
}
```

With Taskig:
```swift
Task.async {
    let enhancedImage = self.applyImageFilter(image)

    Task.async(executionQueue: .main) { self.imageView.image = enhancedImage }

    UIView.animateTask(withDuration: 0.3) { self.label.alpha = 1 }.await()

    // add code to happen next here
}
```

It even allows you to extend existing types:
```swift
let (data, response) = try! NSURL(string: "www.google.com")!.await()
```

## Installation

### [CocoaPods](http://cocoapods.org)
Taskig is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "Taskig"
```

## Usage
In Taskig, a `Task` represents the eventual result of an asynchronous operation, as do Future and Promise in other libraries. It can wrap both synchronous and asynchronous APIs. To create a `Task`, initialize it with a closure. To make it reusable, write functions that return a task.

```swift
// synchronous API wrapped in task
func encrypt(message: String) -> Task<String> {
    return Task {
        encrypt(message)
    }
}

// asynchronous API wrapped in task
func get(URL: NSURL) -> Task<(NSData?, NSURLResponse?, NSError?)> {
    return Task {completionHandler in
        NSURLSession().dataTaskWithURL(URL, completionHandler: completionHandler).resume()
    }
}
```

To get the result of a `Task`, use `async` or `await`. `async` is just like `dispatch_async`, and you can supply a completion handler. `await`, on the contrary, blocks the current thread and waits for the task to finish. To avoid deadlocks on the main thread Taskig contains a precondition check, which will end in a crash if you try to call `await` on the main thread!

```swift
// async
encrypt(message).async { ciphertext in /* do somthing */ }
get(URL).async {(data, response, error) in /* do somthing */ }

// await
let ciphertext = encrypt(message).await()
let (data, response, error) = get(URL).await()
```

When you create a task, you can specify on which queue the task should be executed. Under the hood Taskig uses dispatch queues to execute tasks, therefore all standard dispatch queues are available for execution: background, utility, userInitiated, userInteractive and main, but you can also use your application specific ones.

```swift
Task<Void>(executionQueue: .main) {
    print("On Main Thread")
    //Update UI here
}

Task<Int>(executionQueue: .background) { () -> Int in
    // Calculate something in the background
    return 42
}
```

### Composing Tasks
You can use multiple await expressions to ensure that each statement completes before executing the next statement:

```swift
Task {
    print(“downloading image”)
    var image = downloadImage.await()
    imageView.updateWithImage(image).await()
    
    print(“processing image”)
    image = processImage(image).await()
    imageView.updateWithImage(image).await()
    
    print(“finished”)
}.async()
```

### Collections of Tasks
Taskig also supports collections, dictionaries and sequences, of tasks. On both of them you can either call `awaitFirst` or `awaitAll` to execute them in parallel:

```swift
// Get first result returned
let uLs = ["https://web1.swift.org", "https://web2.swift.org"]
let first = replicatedURLs.map(get).awaitFirst()

// Get all results
let messages = ["1", "2", "3"]
let all = messages.map(encrypt).awaitAll()
```

You can control the amount of concurrent parallel task by using the concurrency parameter:

```swift
let numbersStrings = (0...900).map{ String($0) }

// Maximum of 5 parallel tasks
let all = numbersStrings.map(encrypt).awaitAll(concurrency: 5)
```

### Handling Errors
Swift provide first-class support for [error handling](https://developer.apple.com/library/ios/documentation/Swift/Conceptual/Swift_Programming_Language/ErrorHandling.html). In Taskig, a `ThrowableTask` takes a throwing closure and propagates the error.

```swift
extension String: Error {}

func toStringExceptZero(number: Int) -> ThrowableTask<String> {
    return ThrowableTask<String> {
        guard number != 0 else {
            throw "FoundZero"
        }
    
        return "\(number)"
    }
}

do {
    try toStringExceptZero(number: 0).await()
} catch {
    // Prints "FoundZero" error
    print(error)
}
```

Alternatively you can use awaitResult() to get an result enum which is either `.success(value)` with the task result value or `.failure(error)` with the task error.

```swift
if case let .failure(error) = toStringExceptZero(number: 0).awaitResult() {
    print(error)
}
```

### Extending Tasks
Taskig is [protocol oriented](https://developer.apple.com/videos/play/wwdc2015/408/); it defines `TaskType` and `ThrowableTaskType` and provides the default implementation of `async`, `awaitResult` and `await` using protocol extension. In other words, these protocols are easy to implement, and you can `await` on any object that confronts to them. Being able to extend tasks powerful because it allows tasks to encapsulate states and behaviors.

In the following example, by extending `NSURL` to be `TaskType`, we make data fetching a part of the NSURL class. To confront to the `TaskType` protocol, just specify an action and the return type.

```swift
extension URL: ThrowableTaskType {
    typealias ReturnType = (Data, HTTPURLResponse)
    
    public var executionQueue: DispatchQueue { return DispatchQueue.global() }

    public func action(completion: @escaping (TaskResult<(Data, HTTPURLResponse)>) -> Void) {
        URLSession.shared.dataTask(with: self) { (data, response, error) in
            guard error == nil else {
                completion(.failure(error!))
                return
            }
        
            completion(.success((data!, response as! HTTPURLResponse)))
        }.resume()
    }
}
```

This extension allows us to write the following code:

```swift
let (data, response) = try! NSURL(string: "www.google.com")!.await()
```

### Cancellation Support
`ThrowableTaskType` tasks can support cancellation via the `CancellableTaskType` protocol. A cancelled task will throw an `CancellableTaskError.taskWasCancelled` error. The `ThrowableTask` implementation already supports this.

```swift
var task = ThrowableTask<String> { () -> String in
    return "Foobar"
}

task.isCancelled = true

do {
    try task.await()
} catch {
    // CancellableTaskError.taskWasCancelled thrown
    print(error)
}
```

## Author

Thomas Sempf

## License

Taskig is available under the MIT license. See the LICENSE file for more info.
