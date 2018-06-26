//
//  FailingJobPersister.swift
//  CuteTests
//
//  Created by Ryan Baldwin on 2018-06-12.
//  Copyright © 2018 bunnyhug.me All rights reserved.
//

import Foundation
@testable import Cute

class FailingJobPersister: JobPersister {
    typealias JobType = TestJob
    
    struct BrutalError: Error {
        var localizedDescription: String {
            return "This is a brutal error, coming from the depths of hell (your tests)."
        }
    }
    func persist(_ jobs: [TestJob]) throws {
        throw BrutalError()
    }
    
    func delete(_ job: TestJob) throws {
        throw BrutalError()
    }
    
    func load() throws -> [TestJob] {
        throw BrutalError()
    }
    
    func clear(completion: ((Error?) -> Void)?) {
        completion?(BrutalError())
    }
}
