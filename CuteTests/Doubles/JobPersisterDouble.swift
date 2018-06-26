//
//  JobPersisterDouble.swift
//  CuteTests
//
//  Created by Ryan Baldwin on 2018-06-12.
//  Copyright © 2018 bunnyhug.me All rights reserved.
//

import Foundation
@testable import Cute

class JobPersisterDouble: JobPersister {
    var jobs = [TestJob]()
    
    typealias JobType = TestJob
    
    func persist(_ jobs: [TestJob]) throws {
        self.jobs.append(contentsOf: jobs)
    }
    
    func delete(_ job: TestJob) throws {
        if let idx = self.jobs.index(where: { $0.id == job.id }) {
            self.jobs.remove(at: idx)
        }
    }
    
    func load() throws -> [TestJob] {
        return self.jobs
    }
    
    func clear(completion: ((Error?) -> Void)?) {
        self.jobs.removeAll()
        completion?(nil)
    }
}
