//
//  StringExtensionTests.swift
//  Cute
//
//  Created by Ryan Baldwin on 2018-06-14.
//Copyright © 2018 bunnyhug.me. All rights reserved.
//

import Quick
import Nimble
import Cute

class StringExtensionTests: QuickSpec {
    override func spec() {
        describe("The sanitized String extension") {
            it("returns a string appropriate for file IO") {
                expect("This*is::/legal.😀,?縦書き 123".sanitized()) == "This-is-legal-縦書き-123"
            }
        }
    }
}
