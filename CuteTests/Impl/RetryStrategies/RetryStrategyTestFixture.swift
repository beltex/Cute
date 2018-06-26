//
//  RetryStrategyTestFixture.swift
//  CuteTests
//
//  Created by Ryan Baldwin on 2018-06-14.
//  Copyright © 2018 bunnyhug.me. All rights reserved.
//

import Foundation
import Nimble
import Cute

class RetryStrategyTestFixture {
    var queue: JobQueue<TestJob>
    
    public init(strategy: JobRetryStrategy) throws {
        queue = try JobQueue(handling: TestJob.self, name: "Failing Test Queue")
        
        queue.processor = AnyJobProcessor(FailingTestJobProcessor())
        queue.retryStrategy = strategy
        queue.start()
        
        expect { [weak self] in
            self?.queue.state
        }.toEventually(equal(JobQueue.State.listening))
    }
}
