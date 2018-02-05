//
//  ViewController.swift
//  TaskigDemo
//
//  Created by Thomas Sempf on 2017-12-01.
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

import UIKit
import Taskig

extension String: Error {}

extension URL: ThrowableTaskType {
    typealias ReturnType = (Data, HTTPURLResponse)
    public var executionQueue: DispatchQueue { return DispatchQueue.global() }
    
    public func action(completion: @escaping (TaskResult<(Data, HTTPURLResponse)>) -> Void) {
        let session = URLSession(configuration: .ephemeral)
        let task = session.dataTask(with: self) { (data, response, error) in
            guard error == nil else {
                completion(.failure(error!))
                return
            }
            
            completion(.success((data!, response as! HTTPURLResponse)))
        }
        task.resume()
    }
}

extension UIView {
    static func animateTask(withDuration duration: TimeInterval, animations: @escaping () -> Void) -> Task<Bool> {
        return Task<Bool>(executionQueue: .main) { (completion) in
            UIView.animate(withDuration: duration, animations: animations, completion: { (success) in
                completion(success)
            })
        }
    }
}

func currentQueueName() -> String? {
    let name = __dispatch_queue_get_label(nil)
    return String(cString: name, encoding: .utf8)
}

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        test()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func encrypt(message: String) -> Task<String> {
        return Task<String> {
            // do encryption here
            return message
        }
    }

    func test() {
        let mainTask = Task<Void>(executionQueue: .main) {
            // crash if on main thread
            print("On Main Thread")
        }
        
        Task.async(executionQueue: .background) {
            mainTask.await()
        }
        
        let task = ThrowableTask<String>(action: { (resultHanlder) -> Void in
            resultHanlder(.success("Async with result"))
        })
        
        let taskNothing = ThrowableTask<Void> { (resultHanlder) in
            print("Async with Void")
            resultHanlder(.success(Void()))
        }
        
        let taskFails = ThrowableTask<Int> {
            throw "Failing task..."
        }
        
        let taskDirect = Task<String> { () -> String in
            return ("Direkt value")
        }
        
        let intTask = Task<Int> { (completion) in
            completion(9)
        }
        
        Task.async() {
            print("global")
        }
        
        Task.async(executionQueue: .main) {
            print("Global On Main")
        }
        
        Task.async(executionQueue: .utility) {
            print("Running on utility queue")
            
            guard currentQueueName() == DispatchQueue.utility.label else {
                print("Error wrong dispatch queue")
                return
            }
        }
        
        let convertDataToTextTask = { (data: Data) -> ThrowableTask<String> in
            return ThrowableTask<String>(action: { () -> String in
                guard let text = String(data: data, encoding: .utf8) else {
                    throw "Failed to convert data to string"
                }
                
                return text
            })
        }
        
        let updateUiTask = { (text: String) -> Task<Void> in
            return Task<Void>(executionQueue: .main, action: {
                print(text)
            })
            
        }
        
        Task.async {
            do {
                let urlResult = try URL(string: "https://loripsum.net/api")!.await()
                
                let text = try convertDataToTextTask(urlResult.0).await()
                
                updateUiTask(text).await()
            } catch {
                print(error)
            }
        }
        
        do {
            taskNothing.async()
            
            print(intTask.await())
            
            print(try task.await())
            
            print(taskDirect.await())
            
            do {
                try taskFails.await()
            } catch {
                print(error)
            }
            
            let (data, response) = try URL(string: "https://loripsum.net/api")!.await()
            print("Status code: \(response.statusCode)")
            print(data.debugDescription)
            print(String(data: data, encoding: .utf8)!)
        } catch {
            print(error)
        }

    }
}

