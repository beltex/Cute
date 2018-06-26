//
//  BackoffRetryStrategySpec.swift
//  Cute
//
//  Created by Ryan Baldwin on 2018-06-14.
//Copyright © 2018 bunnyhug.me. All rights reserved.
//

import Quick
import Nimble
@testable import Cute


class BackoffRetryStrategySpec: QuickSpec {
    override func spec() {
        describe("A BackoffRetryStrategy") {
            var strategy: BackoffRetryStrategy!
            var fixture: RetryStrategyTestFixture!
            
            beforeEach {
                strategy = BackoffRetryStrategy()
                fixture = try? RetryStrategyTestFixture(strategy: strategy)
            }
            
            afterEach {
                fixture = nil
                strategy = nil
            }
            
            it("stops the queue and re-adds the job to the front of the line") {
                let jobs = (0..<3).map { _ in TestJob() }
                fixture.queue.add(jobs)
                
                expect(fixture.queue.state).toEventually(equal(JobQueue.State.stopped))
                expect(fixture.queue.count) == jobs.count
                expect(fixture.queue.jobs.first) == jobs.first
            }
            
            it("schedules the queue to be restarted") {
                fixture.queue.add([TestJob()])
                expect(fixture.queue.state).toEventually(equal(JobQueue.State.stopped))
                expect(fixture.queue.state).toEventually(equal(JobQueue.State.starting), timeout: 20)
            }
            
            it("exponentially backs off the restarting of the queue - long running test") {
                fixture.queue.add([TestJob()])
                expect(strategy.durationShift).toEventually(equal(2), timeout: 3)
            }
            
            it("resets the backoff when a new job fails - long running test") {
                fixture.queue.add([TestJob()])
                expect(fixture.queue.state).toEventually(equal(JobQueue.State.stopped))
                
                // force a couple backoffs
                expect(strategy.durationShift).toEventually(equal(2), timeout: 5)
                
                // swap the job processor so that the job gets processed on next spin
                fixture.queue.processor = AnyJobProcessor(TestJobProcessor())
                expect(fixture.queue.state).toEventually(equal(JobQueue.State.listening), timeout: 5)
                
                // swap out the processor again, back to the failing one, then add new job
                fixture.queue.processor = AnyJobProcessor(FailingTestJobProcessor())
                fixture.queue.add([TestJob()])
                
                // at this point the strategy should know a new job has failed
                // and that the backoff strategy is starting from 1
                expect(fixture.queue.state).toEventually(equal(JobQueue.State.stopped))
                expect(strategy.durationShift).toEventually(equal(1))
            }
        }
    }
}
