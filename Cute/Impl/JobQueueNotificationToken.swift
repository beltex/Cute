//
//  JobQueueNotificationToken.swift
//  Cute
//
//  Created by Ryan Baldwin on 2018-06-12.
//  Copyright © 2018 bunnyhug.me All rights reserved.
//

import Foundation


/// Defines the key events which occur to a `JobQueue`'s `Job`
///
/// - added: The jobs were added to the JobQueue
/// - cancelled: The jobs were cancelled in the JobQueue
/// - removed: The jobs were removed from the JobQueue
/// - processed: The jobs were successfully processed
/// - failedToProcess: The jobs failed to successfully process
public enum JobQueueEvent {
    /// The jobs were added to the JobQueue
    case added,
    
    /// The jobs were cancelled in the JobQueue
    cancelled,
    
    /// The jobs were removed from the JobQueue
    removed,
    
    /// The jobs were successfully processed
    processed,
    
    /// The jobs failed to successfully process
    failedToProcess
}

/// A token to be strongly retained by any observers of a `JobQueue`
/// JobQueueNotificationTokens are created whenever an observer subscribes to a `JobQueue`
public class JobQueueNotificationToken<Job: QueueJob> {
    var id: String = UUID().uuidString
    var block: (JobQueue<Job>, [Job], JobQueueEvent) -> Void
    
    init(_ block: @escaping (JobQueue<Job>, [Job], JobQueueEvent) -> Void) {
        self.block = block
    }
}
