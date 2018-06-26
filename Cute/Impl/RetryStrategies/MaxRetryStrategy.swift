//
//  MaxRetryStrategy.swift
//  Cute
//
//  Created by Ryan Baldwin on 2018-06-14.
//  Copyright © 2018 bunnyhug.me. All rights reserved.
//

import Foundation

/// Will immediately retry the failed job until the maximum number
/// of failure for that job is reached. Defaults to a max of 5 retries
open class MaxRetryStrategy: JobRetryStrategy {
    /// The max number of attempts to be made to process a job,
    /// including the initial attempt, before the job is purged from the queue.
    public var maxAttempts = 5
    
    /// Maintains a list of the jobs that were retried.
    private var jobAttempts = [String: Int]()
    
    /// Initializes this strategy for a given job and the max number of attempts
    ///
    /// - Parameters:
    ///   - handling: The type of job this strategy is handling
    ///   - maxAttempts: The maximum number of times a job should be _attempted_ to be
    ///                  processed, including the initial attempt to process. If, for
    ///                  example, maxAttempts is 5, then a job will be retried a
    ///                  maximum number of 4 times.
    public convenience init(maxAttempts: Int) {
        self.init()
        self.maxAttempts = maxAttempts
    }
    
    /// Retries the job. If the maximum number of attempts has been reached for
    /// the job then the job will not be retried and will be purged from the queue.
    ///
    /// - Parameters:
    ///   - job: The job that failed
    ///   - queue: The queue on which the job failed
    public func retry<JobType: QueueJob>(job: JobType, failedOnQueue queue: JobQueue<JobType>) {
        guard attempts(forJob: job) < maxAttempts else { return }
        
        logAttempt(forJob: job)
        queue.retry(job)
    }
    
    /// Returns which attempt this is to process the given `QueueJob`
    ///
    /// - Parameter forJob: The job being processed
    /// - Returns: The number of attempts, including this attempt, that have been made to process the job.
    private func attempts(forJob job: QueueJob) -> Int {
        return jobAttempts[job.id] ?? 1
    }
    
    /// Internally logs that an attempt to process the given `QueueJob` was made.
    ///
    /// - Parameter job: The job whose attempt is to be logged.
    private func logAttempt(forJob job: QueueJob) {
        jobAttempts[job.id] = attempts(forJob: job) + 1
    }
}
