//
//  QueueJob.swift
//  Cute
//
//  Created by Ryan Baldwin on 2018-06-09.
//  Copyright © 2018 bunnyhug.me All rights reserved.
//

import Foundation

/// Defines a job which can be enqueued.
public protocol QueueJob: Codable {
    /// The ID of this job, which can be used in a modest attempt to cancel the job, if required.
    var id: String { get }
    
    /// Any data associated with this job.
    var data: Data? { get set }
    
    /// The date/time the job was created
    var createdDate: Date { get }
    
    /// The intended action to be performed by the Processor of this job.
    var action: String { get set }
}
