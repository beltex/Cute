//
//  JobPersister.swift
//  Cute
//
//  Created by Ryan Baldwin on 2018-06-12.
//  Copyright © 2018 bunnyhug.me All rights reserved.
//

import Foundation

/// Provides the means of persisting jobs for a `JobQueue`.
/// `JobQueue`s which have not been assigned a `JobPersister` will operate as in-memory only queues.
public protocol JobPersister: class {
    
    /// The type of QueueJob a conforming type can persist.
    associatedtype JobType: QueueJob
    
    /// Will save the jobs to a permanent destination
    ///
    /// - Parameter jobs: The jobs to persist
    /// - Throws: If there's an error persisting 1 or more of the jobs.
    func persist(_ jobs: [JobType]) throws -> Void
    
    /// Deletes the job's persisted data
    ///
    /// - Parameter job: The job whose data is to be deleted
    /// - Throws: If there's an error deleting the job's persisted data.
    func delete(_ job: JobType) throws -> Void

    /// Loads all the Jobs from their permanent source.
    ///
    /// - Returns: An array of deserialized jobs.
    /// - Throws: If there's an error loading and deserializing 1 or more jobs from their persisted data.
    func load() throws -> [JobType]

    /// Deletes all jobs from the persisted location.
    ///
    /// - Parameter completion: An optional callback to be called after the clearing has completed.
    func clear(completion: ((Error?) -> Void)?) -> Void
}
