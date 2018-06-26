//
//  BackoffRetryStrategy.swift
//  Cute
//
//  Created by Ryan Baldwin on 2018-06-14.
//  Copyright © 2018 bunnyhug.me. All rights reserved.
//

import Foundation


/// Will retry the job every N seconds, scaling at a power of 2,
/// until a max number of seconds is reached, at which point the queue
/// will try to re-process the job at that max time interval.
///
/// MaxRetryStrategy is appropriate for situations wherein failure may decrease over time.
/// A good example would be a Processor which is attempting to upload data to a server,
/// but the server is down. We don't want to continuously ping the server, rather we
/// want to gradually back off more and more over time until the server is back online.
open class BackoffRetryStrategy: JobRetryStrategy {
    /// Maintains a list of the jobs that were retried.
    var lastJobId: String?
    
    /// The maximum number of seconds to wait before retrying the job.
    /// Backoff attempts will scale exponentially starting at 1 second, then 2, then 4, etc.
    /// until maxBackoff is reached.
    // Defaults to 1 hour.
    var maxBackoff: TimeInterval = 60*60 // 1 hour
    
    /// Returns the number of seconds to wait until retrying a failed job
    private var backoffDuration: TimeInterval {
        return min(Double(1 << durationShift), maxBackoff)
    }
    
    /// Used to schedule when this strategy should try and restart the queue.
    var timer: Timer?
    
    /// ultimately determines how many seconds this strategy should wait
    /// before starting up the queue.
    var durationShift = 0
    
    /// Initializes this strategy for a given job and the max number of attempts
    ///
    /// - Parameters:
    ///   - handling: The type of job this strategy is handling
    ///   - maxAttempts: The maximum number of times a job should be _attempted_ to be
    ///                  processed, including the initial attempt to process. If, for
    ///                  example, maxAttempts is 5, then a job will be retried a
    ///                  maximum number of 4 times.
    public convenience init(maxBackoff: TimeInterval) {
        self.init()
        self.maxBackoff = maxBackoff
    }
    
    deinit {
        timer?.invalidate()
    }
    
    /// Retries the job. If the maximum number of attempts has been reached for
    /// the job then the job will not be retried and will be purged from the queue.
    ///
    /// - Parameters:
    ///   - job: The job that failed
    ///   - queue: The queue on which the job failed
    public func retry<JobType: QueueJob>(job: JobType, failedOnQueue queue: JobQueue<JobType>) {
        queue.stop()
        queue.retry(job)
        
        if job.id != lastJobId {
            resetBackoffDuration()
        }
        
        lastJobId = job.id
        scheduleIgnition(of: queue, in: backoffDuration)
        
        if backoffDuration < maxBackoff {
            increaseBackoffDuration()
        }
    }
    
    /// Resets the backoff for this strategy.
    private func resetBackoffDuration() {
        durationShift = 0
    }
    
    /// Increases the backoff duration for the next time this job requires a retry
    private func increaseBackoffDuration() {
        durationShift += 1
    }
    
    /// Schedules the ignition of the queue
    ///
    /// - Parameter queue: The queue to be started.
    private func scheduleIgnition<JobType: QueueJob>(of queue: JobQueue<JobType>, in duration: TimeInterval) {
        print("Scheduling queue to ignite in \(duration) seconds")
        
        DispatchQueue.main.async { [weak self] in
            self?.timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
                print("Queue igniting from BackoffRetryStrategy")
                queue.start()
            }
        }
    }
}
