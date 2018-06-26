//
//  TestJobProcessor.swift
//  CuteTests
//
//  Created by Ryan Baldwin on 2018-06-11.
//  Copyright © 2018 bunnyhug.me All rights reserved.
//

import Foundation
@testable import Cute

class TestJobProcessor: JobProcessor {
    typealias JobType = TestJob
    
    func processJob(_ job: TestJob, completion: @escaping ((TestJob, Error?) -> Void)) {
        print("processed job: \(job)")
        // sleep the thread to somewhat mimic a super fast response.
        // this also helps with predictability in the tests.
        // kind of a hack, but hey.
        Thread.sleep(forTimeInterval: 0.010)
        completion(job, nil)
    }
}

struct TestError: Error {}
class FailingTestJobProcessor: TestJobProcessor {
    override func processJob(_ job: TestJob, completion: @escaping ((TestJob, Error?) -> Void)) {
        print("FAILED to process job: \(job)")
        completion(job, TestError())
    }
}
