//
//  FileBasedPersisterTests.swift
//  Cute
//
//  Created by Ryan Baldwin on 2018-06-12.
//  Copyright © 2018 bunnyhug.me All rights reserved.
//

import Quick
import Nimble
@testable import Cute

class FileBasedPersisterTests: QuickSpec {
    override func spec() {
        describe("A FileBasedPersister") {
            var persister: FileBasedPersister<TestJob>!
            
            beforeEach {
                persister = FileBasedPersister(handling: TestJob.self, queueName: "MyTestQueue")
            }
            
            afterEach {
                waitUntil(timeout: 5) { done in
                    persister.clear { error in
                        if let err = error { print(err) }
                        done()
                    }
                }
            }
            
            it("persists at the expected location") {
                expect(persister.persistenceLocation.contains("Cute/Queues/MyTestQueue")) == true
            }
            
            it("can persist jobs") {
                try! persister.persist([TestJob()])
                expect(try? FileManager.default.contentsOfDirectory(atPath: persister.persistenceLocation).count) == 1
            }
            
            it("can remove a job") {
                let job = TestJob()
                try! persister.persist([job])
                try! persister.delete(job)
                expect(try? FileManager.default.contentsOfDirectory(atPath: persister.persistenceLocation).count) == 0
            }
            
            it("can load jobs") {
                let jobs: [TestJob] = (0..<3).map {
                    var job = TestJob()
                    job.createdDate = job.createdDate.addingTimeInterval(Double($0)*0.001)
                    return job
                }
                
                var loadedJobs = [TestJob]()
                expect {
                    try persister.persist(jobs)
                    loadedJobs.append(contentsOf: try persister.load())
                    return nil
                }.toNot(throwError())
                
                expect(loadedJobs) == jobs
            }
            
            it("clears all jobs from disk") {
                expect {
                    try persister.persist((0..<3).map { _ in TestJob() })
                }.toNot(throwError())
                
                // sanity check
                expect(try? FileManager.default.contentsOfDirectory(atPath: persister.persistenceLocation).count) > 0
                
                waitUntil { done in persister.clear { _ in done() } }
                expect(try? FileManager.default.contentsOfDirectory(atPath: persister.persistenceLocation).count) == 0
            }
            
        }
    }
}
