//
//  HaltRetryStrategy.swift
//  Cute
//
//  Created by Ryan Baldwin on 2018-06-14.
//  Copyright © 2018 bunnyhug.me. All rights reserved.
//

import Foundation

/// A retry strategy that doesn't actually retry anything.
/// Rather, this strategy will simply stop the queue, halting all further progress,
/// queue the job for immediate processing when the queue is started again.
open class HaltRetryStrategy: JobRetryStrategy {
    
    /// Stops the queue and inserts the job to be at the front of the queue,
    /// Thus guaranteeing it to be retried when the queue starts back up again.
    /// - Parameters:
    ///   - job: The job that failed
    ///   - queue: The queue on which the job failed
    public func retry<JobType: QueueJob>(job: JobType, failedOnQueue queue: JobQueue<JobType>) {
        queue.stop()
        queue.retry(job)
    }
}
