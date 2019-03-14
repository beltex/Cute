//
//  JobQueue.swift
//  Cute
//
//  Created by Ryan Baldwin on 2018-06-11.
//  Copyright © 2018 bunnyhug.me All rights reserved.
//

import Foundation

/// An in-memory (with optional persistence) queue which can be processed by a JobProcessor
open class JobQueue<Job: QueueJob> {
    /// Defines the state of the queue.
    public enum State {
        /// The queue is getting ready to process jobs
        case starting,
        
        /// The queue has started and is waiting for jobs
        listening,
        
        /// The queue is currently processing jobs
        processing,
        
        /// The queue is attempting to stop processing jobs
        stopping,
        
        /// The queue is no longer processing jobs
        stopped
    }
    
    /// The jobs, in order, to be processed
    var jobs = [Job]()
    
    /// Maintains a list of weakly referenced observers of this Queue.
    /// Observers will receive notifications anytime jobs are
    /// added, removed, cancelled, processed, or failedToProcess.
    var observers = NSPointerArray.weakObjects()
    
    /// The DispatchQueue on which the manipulation of the queue will occur.
    /// Here for thread safety.
    private let queueDispatch: DispatchQueue
    private let stateDispatch: DispatchQueue
    private let processingDispatch: DispatchQueue
    
    /// Defines what to do in the case of jobs which failed to process.
    /// By default `retryStrategy` is nil, in which case
    /// failed jobs are simply removed from the queue.
    public var retryStrategy: JobRetryStrategy?
    
    /// Maintains the state of the processor.
    private var _state: State = .stopped

    /// Returns the current `JobQueue.State` of this instance
    private(set) public var state: State {
        get {
            return stateDispatch.sync {
                return _state }
        }
        
        set {
            stateDispatch.sync(flags: .barrier) {
                _state = newValue }
        }
    }
    
    /// The processor this queue will use to process pending jobs.
    private var _processor: AnyJobProcessor<Job>?
    
    /// Gets the `JobProcessor` to process the jobs on this instance, if any; otherwise `nil`.
    /// `JobQueue`s without a `JobProcessor` must manually process and remove jobs from the queue.
    public var processor: AnyJobProcessor<Job>? {
        get {
            return queueDispatch.sync { [weak self] in self?._processor }
        }
        
        set {
            queueDispatch.async(flags: .barrier) { [weak self] in
                self?._processor = newValue
            }
        }
    }
    
    /// Gets the `JobPersister` to persist jobs in this queue, if one exists; otherwise nil.
    /// JobQueues that do not have a `JobPersister` will be in-memory only.
    public var persister: AnyJobPersister<Job>?
    
    /// Initializes this JobQueue to handle the given type of Job
    ///
    /// - Parameters:
    ///   - handling: The expect type of QueueJob this JobQueue will handle
    ///   - name: The name for this queue.
    ///   - persister: A JobPersister that may be used to persist jobs.
    /// - Throws: Throws if a JobPersister is provided and it fails to load its jobs.
    public init(handling: Job.Type, name: String, persister: AnyJobPersister<Job>? = nil) throws {
        queueDispatch = DispatchQueue(label: "me.bunnyhug.cute.queue.\(name)", attributes: .concurrent)
        stateDispatch = DispatchQueue(label: "me.bunnyhug.cute.queue.\(name).StateDispatcher", attributes: .concurrent)
        processingDispatch = DispatchQueue(label: "me.bunnyhug.cute.queue.\(name).ProcessingDispatcher")
        
        self.persister = persister
        
        if let loaded = try persister?.load(), loaded.count > 0 {
            self.jobs.append(contentsOf: loaded)
        }
    }
}

// notification publishing
extension JobQueue {
    /// Notifies all the observers of this `JobQueue` that some `JobEvent` has occured involving the provided `jobs`
    ///
    /// - Important: All observers of this `JobQueue` will be asynchronously called _on the main thread_.
    /// - Parameters:
    ///   - event: The `JobEvent` that has occured
    ///   - jobs: The `Job`s affected by this event.
    private func notifyObserversThatQueue(_ event: JobQueueEvent, jobs: [Job]) {
        DispatchQueue.main.async { [weak self] in
            guard let this = self else { return }
            
            this.observers.compact()
            autoreleasepool {
                this.observers.allObjects.forEach {
                    guard let token = $0 as? JobQueueNotificationToken<Job> else { return }
                    token.block(this, jobs, event)
                }
            }
        }
    }
}

// basic functionality
extension JobQueue {
    /// Returns the number of jobs in this `JobQueue` awaiting processing.
    public var count: Int {
        return jobs.count
    }
    
    /// Adds the provided `jobs` to this `JobQueue`, while maintaining their order.
    /// - Remark: This function is thread safe.
    /// - Parameter jobs: The jobs to be added to this `JobQueue`.
    public func add(_ jobs: [Job]) {
        queueDispatch.async(flags: .barrier) { [weak self] in
            guard !jobs.isEmpty else { return }
            
            do {
                try self?.persister?.persist(jobs)
            } catch let error {
                print("Failed to persist jobs, but jobs will still be queued for processing: \(error)")
            }
            
            self?.jobs.append(contentsOf: jobs)
            self?.notifyObserversThatQueue(.added, jobs: jobs)
            
            if self?.canProcess(inState: self?.state) == true {
                self?.processJobs()
            }
        }
    }
    
    /// Queues the provided `job` for immediate processing. That is, the provided job will be inserted
    /// at the very front of this `JobQueue`
    ///
    /// - Remark: This function is thread safe
    /// - Parameter job: The job to be inserted at the front of this `JobQueue`
    public func retry(_ job: Job) {
        queueDispatch.async(flags: .barrier) { [weak self] in
            do {
                try self?.persister?.persist([job])
            } catch let error {
                print("Failed to persist job, but job will still be queued for processing: \(error)")
            }
            
            self?.jobs.insert(job, at: 0)
        }
    }
    
    /// Attempts to return without removing the next `Job` at the front of this `JobQueue`.
    ///
    /// - Remark: This function is thread safe
    /// - Returns: The next `Job` at the front of this `JobQueue`, if one exists; otherwise nil
    public func peek() -> Job? {
        return queueDispatch.sync { return jobs.first }
    }
    
    /// Removes the next `Job` from the front of this `JobQueue`
    ///
    /// - Remark: This function is thread safe
    /// - Returns: The next `Job` at the front of this `JobQueue`, if one exists; otherwise nil
    public func remove() -> Job? {
        return queueDispatch.sync(flags: .barrier) { [weak self] in
            guard (self?.jobs.count ?? 0) > 0 else { return nil }
            guard let job = self?.jobs.removeFirst() else { return nil }
            
            do {
                try self?.persister?.delete(job)
            } catch let error {
                print("Removed job from queue, but failed to remove job from from persisted source: \(error)")
            }
            
            notifyObserversThatQueue(.removed, jobs: [job])
            return job
        }
    }
    
    /// Cancels the job in this `JobQueue` with the provided `id`, if it exists.
    ///
    /// - Attention: This cannot cancel a matching `Job` if that `Job` is already being processed.
    /// - Remark: This function is thread safe
    /// - Parameter id: The `id` of the `Job` to be removed from this `JobQueue`
    public func cancel(_ id: String) {
        queueDispatch.async(flags: .barrier) { [weak self] in
            guard let idx = self?.jobs.index(where: {$0.id == id}) else { return }
            guard let job = self?.jobs[idx] else { return }
            
            self?.jobs.remove(at: idx)
            
            do {
                try self?.persister?.delete(job)
            } catch let error {
                print("Cancelled job, however failed to remove the job from the persiste: \(error)")
            }
            
            self?.notifyObserversThatQueue(.cancelled, jobs: [job])
        }
    }
    
    /// Removes all jobs from this JobQueue
    /// - Remark: This function is thread safe
    public func drain() {
        queueDispatch.async(flags: .barrier) { [weak self] in
            let jobs = self?.jobs
            self?.jobs.removeAll()
            do {
                try self?.persister?.clear()
            } catch let error {
                // note: unable to throw from within a dispatched block, so this will have to do
                print("Error: Unable to clear persistent files: \(error)")
            }
            
            if let jobs = jobs {
                self?.notifyObserversThatQueue(.removed, jobs: jobs)
            }
        }
    }
}

// Flow control
extension JobQueue {
    
    /// Tells this `JobQueue` to start processing its `Job`s
    public func start() {
        if state == .stopping || state == .stopped {
            state = .starting
            processJobs()
        }
    }
    
    /// Tells this `JobQueue` to stop processing its `Jobs`.
    public func stop() {
        switch state {
        case .stopping, .stopped:
            break // do nothing, already shutting down
        
        case .listening:
            state = .stopped
            
        case .processing, .starting:
            state = .stopping
        }
    }
    
    func canProcess(inState state: JobQueue.State?) -> Bool {
        guard let state = state else { return false }
        
        let processableStates: [JobQueue.State] = [.listening, .starting]
        return processableStates.contains(state)
    }
    
    /// Asynchronously processes this instance's jobs until it is empty or stopped.
    func processJobs() {
        processingDispatch.async() { [weak self] in
            if self?.state == .stopping {
                self?.state = .stopped
            }
            
            guard self?.state != .stopped else { return }
            
            guard let processor = self?.processor else {
                self?.state = .listening
                return
            }
            
            guard let job = self?.remove() else {
                self?.state = .listening
                return
            }
            
            self?.state = .processing
            
            // we have no idea how a JobProcessor does its work; that is, it may be performed asynchronously which,
            // if that's the case, then this dispatch queue will exit prior to the processor being completed,
            // which can and will screw up the order of our queue. As such, we must force a wait before exiting
            // this dispatch queue's process. We do this by using a DispatchGroup.
            let group = DispatchGroup()
            group.enter()
            
            processor.processJob(job) { job, error in
                if error == nil {
                    self?.notifyObserversThatQueue(.processed, jobs: [job])
                } else {
                    print("Erorr processing job in queue: \(error!)")
                    self?.notifyObserversThatQueue(.failedToProcess, jobs: [job])
                    
                    if let this = self, let strategy = this.retryStrategy {
                        strategy.retry(job: job, failedOnQueue: this)
                    } else {
                        print("No retry strategy specified. Job will be removed from queue.")
                    }
                }
                
                DispatchQueue.global(qos: .background).async { self?.processJobs() }
                group.leave()
            }
            
            group.wait()
        }
    }
}

// Delegate control
extension JobQueue {
    
    /// Subscribes a listener to this `JobQueue`.
    ///
    /// - Parameter block: The function to be called which will receive the notification
    /// - Parameter queue: The `JobQueue` from which the notification is broadcast
    /// - Parameter jobs: The jobs affected by the `JobQueueEvent`
    /// - Parameter event: The `JobQueueEvent` (such as `.added`, `.removed`, etc) affecting the provided `jobs`
    ///
    /// - Returns: A `JobQueueNotificationToken`.
    ///
    /// - Attention: The returned `JobQueueNotificationToken` is `weak`, and must be strongly retained by the receiver.
    ///              As soon as the token goes out of scope, or is set to `nil`, the observer will no longer recieve
    ///              notifications.
    public func observe(_ block: @escaping (_ queue: JobQueue<Job>, _ jobs: [Job], _ event: JobQueueEvent) -> Void) -> JobQueueNotificationToken<Job> {
        return queueDispatch.sync(flags: .barrier) {
            let observer = JobQueueNotificationToken(block)
            let pointer = Unmanaged.passUnretained(observer).toOpaque()
            observers.addPointer(pointer)
            
            return observer
        }
    }
}
