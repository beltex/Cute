//
//  QueueProcessor.swift
//  Cute
//
//  Created by Ryan Baldwin on 2018-06-11.
//  Copyright © 2018 bunnyhug.me All rights reserved.
//

import Foundation


/// Defines an object which can process a QueueJob of a given type.
/// A JobProcessor instance can be assigned to any JobQueue of the same underlying QueueJob type.
public protocol JobProcessor: class {
    associatedtype JobType: QueueJob
    
    /// Processes a job of the given type. If the job fails to process for any reason the
    /// `Error` must be provided.
    ///
    /// - Parameters:
    ///   - job: The QueueJob to be processed
    ///   - completion: The block to be called when the job has completed processing. The function _must_ be called
    ///                 and should be provided the original `job` that was provided to the processor.
    ///                 If the JobProcessor fails to process the `job`, then the JobProcessor _must_ provide an
    ///                 `Error` to the receiver.
    func processJob(_ job: JobType, completion: @escaping ((JobType, Error?) -> Void))
}
