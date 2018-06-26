//
//  HaltRetryStrategySpec.swift
//  Cute
//
//  Created by Ryan Baldwin on 2018-06-14.
//Copyright © 2018 bunnyhug.me. All rights reserved.
//

import Quick
import Nimble
@testable import Cute

class HaltRetryStrategySpec: QuickSpec {
    override func spec() {
        describe("A HaltRetryStrategy") {
            var fixture: RetryStrategyTestFixture!
            
            beforeEach {
                fixture = try? RetryStrategyTestFixture(strategy: HaltRetryStrategy())
            }
            
            afterEach {
                fixture = nil
            }
            
            it("stops the queue and readds the job to the front of the queue") {
                let job = TestJob()
                fixture.queue.add([job])
                expect(fixture.queue.state).toEventually(equal(JobQueue.State.stopped))
                expect(fixture.queue.jobs.count) == 1
                expect(fixture.queue.jobs[0]) == job
            }
        }
    }
}
