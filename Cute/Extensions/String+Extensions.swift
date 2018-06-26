//
//  String+Extensions.swift
//  Cute
//
//  Created by Ryan Baldwin on 2018-06-14.
//  Copyright © 2018 bunnyhug.me. All rights reserved.
//

import Foundation

extension String {
    /// Returns a sanitized version of this string appropriate for file use.
    ///
    /// - Returns: A sanitized, file-safe version of this string.
    public func sanitized() -> String {
        return self.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }
}
