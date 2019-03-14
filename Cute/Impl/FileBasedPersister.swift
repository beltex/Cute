//
//  FileBasedPersister.swift
//  Cute
//
//  Created by Ryan Baldwin on 2018-06-12.
//  Copyright © 2018 bunnyhug.me All rights reserved.
//

import Foundation


/// A JobPersister which persists QueueJobs to the device's local file system
public class FileBasedPersister<HandlingJob: QueueJob>: JobPersister {
    typealias Job = HandlingJob
    
    private let queueName: String

    /// Creates a name for the given job, based on the job's `id` and `createdDate`.
    ///
    /// - Parameter job: The job from which a filename will be generated
    /// - Returns: The filename for the given job.
    private func makeFileName(forJob job: HandlingJob) -> String {
        let name = "\(job.createdDate.timeIntervalSince1970)-\(job.id.sanitized()).json"
        print("FileName for job \(job): \(name)")
        return name
    }
    
    /// Provides the path to where this Persister is performing its IO.
    lazy public var persistenceLocation: URL = {
        let fm = fileManager

        guard let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Could not get applicationSupportDirectory for current user.")
        }

        let path: URL = dir.appendingPathComponent("Cute/Queues/\(queueName)", isDirectory: true)

        // note: Apple recommends not checking for the existence of the directory and just creating it instead
        do {
            try fm.createDirectory(at: path, withIntermediateDirectories: true)
        } catch let error {
            fatalError("Unable to create directory: \(error)")
        }

        print("QueueJobs will be persisted at \(path.path)")
        return path
    }()

    /// The file manager this Persister will use for all Job IO.
    private var fileManager = FileManager()

    /// Initializes this JobPersister
    ///
    /// - Parameters:
    ///   - handling: The type of QueueJob this persister will handle
    ///   - queueName: The name of the queue this persister is saving jobs for.
    public init(handling: HandlingJob.Type, queueName: String) {
        self.queueName = queueName.sanitized()
    }
    
    /// Writes a JSONEncoded version of the QueueJobs to the `Application Support/Cute/Queues/[Queue Name]` directory
    ///
    /// - Parameter jobs: The QueueJobs to persist
    /// - Throws: An error any of the jobs fail to persist.
    public func persist(_ jobs: [HandlingJob]) throws {
        let encoder = JSONEncoder()
        
        for j in jobs {
            var path = persistenceLocation
            path.appendPathComponent(makeFileName(forJob: j), isDirectory: false)
            let data = try encoder.encode(j)
            try data.write(to: path)
        }
    }
    
    /// Deletes the job's persisted file from disk
    ///
    /// - Parameter job: The job whose persisted file is to be deleted
    /// - Throws: An error if the job's persiste file fails to delete.
    public func delete(_ job: HandlingJob) throws {
        var path = persistenceLocation
        path.appendPathComponent(makeFileName(forJob: job))
        try fileManager.removeItem(at: path)
    }
    
    /// Loads all jobs from file in the correct order
    ///
    /// - Returns: The array of jobs loaded from disk, in their correct order
    /// - Throws: An error if any of the jobs failed to load from disk.
    public func load() throws -> [HandlingJob] {
        let decoder = JSONDecoder()
        let jobs: [HandlingJob] = try fileManager.contentsOfDirectory(at: persistenceLocation, includingPropertiesForKeys: [], options: .skipsSubdirectoryDescendants).compactMap { path in
            let data = try Data(contentsOf: path)
            return try decoder.decode(Job.self, from: data)
        }
        
        return jobs.sorted { left, right in left.createdDate < right.createdDate }
    }
    
    /// Clears all persisted jobs from disk
    ///
    /// - Parameter completion: The block to call after the attempt to clear all jobs is complete.
    public func clear(completion: ((Error?) -> Void)?) throws {

        let files = try fileManager.contentsOfDirectory(at: persistenceLocation, includingPropertiesForKeys: [], options: .skipsSubdirectoryDescendants)

        files.forEach {
            do {
                try fileManager.removeItem(at: $0)
            } catch let error {
                completion?(error)
            }
        }

        completion?(nil)
    }
}
