//
//  JobRetryStrategy.swift
//  Cute
//
//  Created by Ryan Baldwin on 2018-06-14.
//  Copyright © 2018 bunnyhug.me. All rights reserved.
//

import Foundation

/// Defines a generic strategy for how a JobQueue should handle a job which failed to process.
/// - Attention: This class must be inherited.
public protocol JobRetryStrategy {
    
    /// Instructs how to retry the failed `job` on the provided `queue`
    ///
    /// - Parameters:
    ///   - job: The QueueJob which failed to process
    ///   - queue: The JobQueue on which the job failed.
    func retry<JobType: QueueJob>(job: JobType, failedOnQueue queue: JobQueue<JobType>)
}
