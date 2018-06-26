//
//  QueueTests.swift
//  Cute
//
//  Created by Ryan Baldwin on 2018-06-11.
//  Copyright © 2018 bunnyhug.me All rights reserved.
//

import Quick
import Nimble
@testable import Cute

class JobQueueTests: QuickSpec {
    
    override func setUp() {
        continueAfterFailure = false
    }
    
    override func spec() {
        describe("A JobQueue") {
            var q: JobQueue<TestJob>!
            let qname = "TestJobQueue"
            var jobs: [TestJob]!
            
            beforeEach {
                expect {
                    q = try JobQueue(handling: TestJob.self, name: qname)
                }.toNot(throwError())
                
                jobs = makeJobs(count: 3)
            }
            
            it("is stopped by default") {
                expect(q.state) == JobQueue.State.stopped
            }
            
            it("adds the jobs in order") {
                q.add(jobs)
                
                expect(q.count).toEventually(equal(jobs.count))
                expect(q.jobs.first?.id) == jobs.first?.id
                expect(q.jobs.last?.id) == jobs.last?.id
                expect(q.jobs[1].id) == jobs[1].id
            }
            
            it("doesn't add anything when trying to add empty jobs") {
                q.add([])
                expect(q.count).toEventually(equal(0))
            }
            
            it("peeks at the next in line") {
                expect(q.peek()).to(beNil())
                q.add(jobs)
                expect(q.peek()?.id) == jobs[0].id
            }
            
            it("removes the next in line") {
                // sanity check
                expect(q.count) == 0
                q.add(jobs)
                expect(q.count).toEventually(equal(3))
                
                _ = q.remove()
                expect(q.count) == 2
                expect(q.peek()?.id) == jobs[1].id
            }
            
            it("returns nil when attempting to remove from an empty queue") {
                expect(q.count) == 0
                expect(q.remove()).to(beNil())
            }
            
            it("removes a cancelled job") {
                q.add(jobs)
                // sanity
                expect(q.jobs.last?.id).toEventually(equal(jobs[2].id))
                
                q.cancel(jobs[2].id)
                expect(q.count).toEventually(equal(2))
                expect(q.jobs.last?.id) == jobs[1].id
            }
            
            it("drains all jobs from the queue") {
                q.add(jobs)
                expect(q.jobs.count).toEventually(equal(jobs.count))
                q.drain()
                expect(q.jobs.count).toEventually(equal(0))
            }
            
            context("with a processor") {
                beforeEach {
                    q.processor = AnyJobProcessor(TestJobProcessor())
                }
                
                it("will not process jobs until started") {
                    q.add(jobs)
                    expect(q.peek()).toNot(beNil())
                    expect(q.count) == jobs.count
                }
                
                it("will process all jobs until none remain") {
                    q.start()
                    q.add(jobs)
                    expect(q.count).toEventually(equal(0))
                    expect(q.state).toEventually(equal(JobQueue.State.listening))
                }
                
                it("will by default purge failed jobs from the queue") {
                    q.add(jobs)
                    q.processor = AnyJobProcessor(FailingTestJobProcessor())
                    q.start()
                    
                    // TODO: on errors this should eventually go to `.halted`, if retries are enabled.
                    expect(q.state).toEventually(equal(JobQueue.State.listening))
                    expect(q.count) == 0
                }
                
                it("will stop processing jobs when the queue is stopped") {
                    q.add(makeJobs(count: 1000))
                    q.start()
                    expect(q.state).toEventually(equal(JobQueue.State.processing))
                    expect(q.count).toEventually(beLessThan(998))
                    
                    q.stop()
                    expect(q.state).toEventually(equal(JobQueue.State.stopped))
                    expect(q.count) > 0
                }
            }
            
            context("with a persister") {
                var persister: JobPersisterDouble!
                
                beforeEach {
                    persister = JobPersisterDouble()
                    q.persister = AnyJobPersister(persister)
                    q.add(jobs)
                    expect(q.count).toEventually(equal(jobs.count))
                }
                
                it("persists the jobs that are added") {
                    expect(persister.jobs.count).toEventually(equal(jobs.count))
                }
                
                it("deletes the persisted job when removed") {
                    _ = q.remove()
                    expect(persister.jobs.count).toEventually(equal(jobs.count-1))
                }
                
                it("deletes the persisted job when cancelled") {
                    q.cancel(jobs.first!.id)
                    expect(persister.jobs.count).toEventually(equal(jobs.count-1))
                }
                
                it("doesn't remove persisted jobs when peeked") {
                    _ = q.peek()
                    expect(persister.jobs.count) == jobs.count
                }
                
                it("loads jobs from the persister on init") {
                    // sanity check
                    expect(persister.jobs.count) == jobs.count
                    
                    var q2: JobQueue<TestJob>!
                    expect {
                        q2 = try JobQueue(handling: TestJob.self, name: qname, persister: AnyJobPersister(persister))
                    }.toNot(throwError())
                    
                    expect(q2.count).toEventually(equal(jobs.count))
                }
            }
            
            context("with a failing persister") {
                beforeEach {
                    q.persister = AnyJobPersister(FailingJobPersister())
                    q.add(jobs)
                    expect(q.count).toEventually(equal(jobs.count))
                }
                
                it("survives when failing to add jobs") {
                    // do nothing - handled in the beforeEach, for better or for worse.
                }
                
                it("survives when failing to remove a job") {
                    _ = q.remove()
                    expect(q.count).toEventually(equal(jobs.count-1))
                }
                
                it("survives when failing to cancel a job") {
                    q.cancel(jobs.first!.id)
                    expect(q.count).toEventually(equal(jobs.count-1))
                }
            }
            
            context("with a notification token") {
                var observation: QueueObservation<TestJob>?
                var token: JobQueueNotificationToken<TestJob>?
                
                let observationBlock: (JobQueue<TestJob>, [TestJob], JobQueueEvent) -> Void = { queue, jobs, event in
                    observation = QueueObservation<TestJob>(queue: queue, jobs: jobs, event: event)
                }
                
                afterEach {
                    observation = nil
                    token = nil
                }
                
                it("sends a notification when jobs are added") {
                    token = q.observe { observationBlock($0, $1, $2) }
                    q.add(jobs)
                    
                    expect(observation).toEventuallyNot(beNil())
                    expect(observation?.queue).toEventuallyNot(beNil())
                    expect(observation?.jobs).toEventually(equal(jobs))
                    expect(observation?.event).toEventually(equal(JobQueueEvent.added))
                }
                
                it("sends a notification when a job is removed") {
                    q.add(jobs)
                    expect(q.count).toEventually(equal(jobs.count))
                    
                    token = q.observe { observationBlock($0, $1, $2) }
                    let removedJob = q.remove()
                    
                    expect(observation).toEventuallyNot(beNil())
                    expect(observation?.queue).toEventuallyNot(beNil())
                    expect(observation?.jobs?.count).toEventually(equal(1))
                    expect(observation?.jobs?.first).toEventually(equal(removedJob))
                    expect(observation?.event).toEventually(equal(JobQueueEvent.removed))
                }
                
                it("sends a notification when a job is cancelled") {
                    q.add(jobs)
                    expect(q.count).toEventually(equal(jobs.count))
                    
                    token = q.observe { observationBlock($0, $1, $2) }
                    q.cancel(jobs.first!.id)
                    
                    expect(observation).toEventuallyNot(beNil())
                    expect(observation?.queue).toEventuallyNot(beNil())
                    expect(observation?.jobs?.count).toEventually(equal(1))
                    expect(observation?.jobs?.first).toEventually(equal(jobs.first!))
                    expect(observation?.event).toEventually(equal(JobQueueEvent.cancelled))
                }
                
                it("sends a notification when a job was processed") {
                    q.add(jobs)
                    expect(q.count).toEventually(equal(jobs.count))
                    
                    q.processor = AnyJobProcessor(TestJobProcessor())
                    token = q.observe { observationBlock($0, $1, $2) }
                    q.start()
                    
                    expect(observation).toEventuallyNot(beNil())
                    expect(observation?.queue).toEventuallyNot(beNil())
                    expect(observation?.jobs?.count).toEventually(equal(1))
                    expect(observation?.event).toEventually(equal(JobQueueEvent.processed))
                }
                
                it("sends a notification when a job failed to process") {
                    q.add(jobs)
                    expect(q.count).toEventually(equal(jobs.count))
                    
                    q.processor = AnyJobProcessor(FailingTestJobProcessor())
                    token = q.observe { observationBlock($0, $1, $2) }
                    q.start()
                    
                    expect(observation).toEventuallyNot(beNil())
                    expect(observation?.queue).toEventuallyNot(beNil())
                    expect(observation?.jobs?.count).toEventually(equal(1))
                    expect(observation?.event).toEventually(equal(JobQueueEvent.failedToProcess))
                }
                
                it("doesn't send notification if token goes out of scope") {
                    token = q.observe { observationBlock($0, $1, $2) }
                    q.add(jobs)
                    expect(observation).toEventuallyNot(beNil())
                    
                    observation = nil
                    token = nil
                    
                    q.add(jobs)
                    expect(q.count).toEventually(equal(jobs.count*2), timeout: 60)
                    expect(observation).to(beNil())
                }
            }
        }
    }
}

struct QueueObservation<Job: QueueJob> {
    var queue: JobQueue<Job>?
    var jobs: [Job]?
    var event: JobQueueEvent?
}

func makeJobs(count: Int) -> [TestJob] {
    return (0..<count).map {
        var j = TestJob()
        j.createdDate = j.createdDate.addingTimeInterval(TimeInterval($0 * 1))
        return j
    }
}
