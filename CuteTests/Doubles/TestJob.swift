//
//  TestJob.swift
//  CuteTests
//
//  Created by Ryan Baldwin on 2018-06-11.
//  Copyright © 2018 bunnyhug.me All rights reserved.
//

import Foundation
import Cute

struct TestJob: QueueJob, Equatable {
    private(set) var id: String = UUID().uuidString
    var data: Data? = nil
    var createdDate = Date()
    var action: String = "test"
}
