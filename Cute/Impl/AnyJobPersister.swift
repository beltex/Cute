//
//  AnyJobPersister.swift
//  Cute
//
//  Created by Ryan Baldwin on 2018-06-12.
//  Copyright © 2018 bunnyhug.me All rights reserved.
//

import Foundation


/// A type-erased wrapper for a JobPersister.
/// Use this if you need to define an argument of a JobPersister, or if you need to store
/// a JobPersister as a property.
///
/// Examples:
///
///     struct MyJobType: QueueJob { ... }
///     var persister: AnyJobPersister<MyJobType>
///     func someFunc(takingPersister: AnyJobPersister<MyJobType>)
public class AnyJobPersister<HandlingJob: QueueJob>: JobPersister {
    /// The expected QueueJob type this erasure is wrapping
    public typealias JobType = HandlingJob
    
    private let _persist: (_ jobs: [HandlingJob]) throws -> Void
    private let _delete: (_ job: HandlingJob) throws -> Void
    private let _load: () throws -> [HandlingJob]
    private let _clear: (_ completion: ((Error?) -> Void)?) throws -> Void
    
    /// Creates a new wrapper for the given `JobPersister`
    public init<P: JobPersister>(_ persister: P) where P.JobType == HandlingJob {
        _persist = persister.persist
        _delete = persister.delete
        _load = persister.load
        _clear = persister.clear
    }
    
    /// Will save the jobs to a permanent destination using the internal `JobPersister`
    ///
    /// - Parameter jobs: The jobs to persist
    /// - Throws: If there's an error persisting 1 or more of the jobs.
    public func persist(_ jobs: [HandlingJob]) throws {
        try _persist(jobs)
    }
    
    /// Deletes the job's persisted data using the internal `JobPersister`
    ///
    /// - Parameter job: The job whose data is to be deleted
    /// - Throws: If there's an error deleting the job's persisted data.
    public func delete(_ job: HandlingJob) throws {
        try _delete(job)
    }
    
    /// Loads all the Jobs from their permanent source using the internal `JobPersister`
    ///
    /// - Returns: An array of deserialized jobs.
    /// - Throws: If there's an error loading and deserializing 1 or more jobs from their persisted data.
    public func load() throws -> [HandlingJob] {
        return try _load()
    }
    
    /// Deletes all jobs from the persisted location using the internal `JobPersister`
    ///
    /// - Parameter completion: An optional callback to be called after the clearing has completed.
    public func clear(completion: ((Error?) -> Void)? = nil) throws {
        try _clear(completion)
    }
}
