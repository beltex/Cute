//
//  AnyQueueProcessor .swift
//  Cute
//
//  Created by Ryan Baldwin on 2018-06-11.
//  Copyright © 2018 bunnyhug.me All rights reserved.
//

import Foundation


/// A type-erased wrapper for a JobProcessor.
/// Use this if you need to define an argument of a JobProcessor, or if you need to store
/// a JobProcessor as a property.
///
/// Examples:
///
///     struct MyJobType: QueueJob { ... }
///     var persister: AnyJobProcessor<MyJobType>
///     func someFunc(usingProcessor: AnyJobPersister<MyJobType>)
open class AnyJobProcessor<HandlingJob: QueueJob>: JobProcessor {
    /// The expected QueueJob type this erasure is wrapping
    public typealias JobType = HandlingJob
    
    private let _processJob: (_: HandlingJob, @escaping ((HandlingJob, Error?) -> Void)) -> Void
    
    /// Creates a new wrapper for the given `JobPersister`
    public init<P: JobProcessor>(_ processor: P) where P.JobType == HandlingJob {
        _processJob = processor.processJob
    }
    
    /// Processes a job of the given type using the internal `JobProcessor`.
    /// If the job fails to process for any reason the `Error` must be provided.
    ///
    /// - Parameters:
    ///   - job: The QueueJob to be processed
    ///   - completion: The block to be called when the job has completed processing. The function _must_ be called
    ///                 and should be provided the original `job` that was provided to the processor.
    ///                 If the JobProcessor fails to process the `job`, then the JobProcessor _must_ provide an
    ///                 `Error` to the receiver.
    /// - Important: If the `completion` is called with an `Error`, and the `JobQueue` has a `JobRetryStrategy`,
    ///              then the job will be requeued. Otherwise the job will be purged from the JobQueue.
    public func processJob(_ job: HandlingJob, completion: @escaping ((HandlingJob, Error?) -> Void)) {
        _processJob(job, completion)
    }
}
