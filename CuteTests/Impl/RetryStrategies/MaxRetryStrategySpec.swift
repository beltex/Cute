//
//  MaxRetryStrategySpec.swift
//  Cute
//
//  Created by Ryan Baldwin on 2018-06-14.
//  Copyright © 2018 bunnyhug.me. All rights reserved.
//

import Quick
import Nimble
@testable import Cute

class MaxRetryStrategySpec: QuickSpec {
    override func spec() {
        describe("A MaxRetryStrategy") {
            var strategy: MaxRetryStrategy!
            var fixture: RetryStrategyTestFixture!
            
            beforeEach {
                strategy = MaxRetryStrategy()
                fixture = try? RetryStrategyTestFixture(strategy: strategy)
            }
            
            afterEach {
                fixture = nil
                strategy = nil
            }
            
            it("retries the job a max number of times before purging") {
                var retryMap = [String: Int]()
                let token = fixture.queue.observe { queue, jobs, event in
                    if event == JobQueueEvent.failedToProcess {
                        let job = jobs.first!
                        retryMap[job.id] = (retryMap[job.id] ?? 0) + 1
                    }
                }

                expect(token).toNot(beNil()) // just to prevent a warning about token not being read
                
                let jobs = (0..<3).map { _ in TestJob() }
                fixture.queue.add(jobs)
                
                expect(retryMap[jobs[0].id]).toEventually(equal(5))
                expect(retryMap[jobs[1].id]).toEventually(equal(5))
                expect(retryMap[jobs[2].id]).toEventually(equal(5))
                expect(fixture.queue.count) == 0
            }
        }
    }
}
