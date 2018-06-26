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
    
    private var queueName: String
    
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
    public var persistenceLocation: String {
        return fileManager.currentDirectoryPath
    }
    
    /// The file manager this Persister will use for all Job IO.
    lazy private var fileManager: FileManager = {
        let fm = FileManager()
        
        guard let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Could not get applicatinSupportDirectory for current user.")
        }
        
        let path = dir.appendingPathComponent("Cute/Queues/\(queueName)", isDirectory: true)
        
        if !fm.fileExists(atPath: path.absoluteString) {
            try! fm.createDirectory(at: path, withIntermediateDirectories: true)
        }
        
        fm.changeCurrentDirectoryPath(path.path)
        print("QueueJobs will be persisted at \(fm.currentDirectoryPath)")
        return fm
    }()
    
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
            fileManager.createFile(atPath: makeFileName(forJob: j), contents: try encoder.encode(j))
        }
    }
    
    /// Deletes the job's persisted file from disk
    ///
    /// - Parameter job: The job whose persisted file is to be deleted
    /// - Throws: An error if the job's persiste file fails to delete.
    public func delete(_ job: HandlingJob) throws {
        let file = makeFileName(forJob: job)
        if fileManager.fileExists(atPath: file) { try fileManager.removeItem(atPath: file) }
    }
    
    /// Loads all jobs from file in the correct order
    ///
    /// - Returns: The array of jobs loaded from disk, in their correct order
    /// - Throws: An error if any of the jobs failed to load from disk.
    public func load() throws -> [HandlingJob] {
        let decoder = JSONDecoder()
        let jobs: [HandlingJob] = try fileManager.contentsOfDirectory(atPath: ".").sorted().compactMap { path in
            if let data = fileManager.contents(atPath: path) {
                print("loading job at \(path)")
                return try decoder.decode(Job.self, from: data)
            }
            
            return nil
        }
        
        return jobs.sorted { left, right in left.createdDate < right.createdDate }
    }
    
    /// Clears all persisted jobs from disk
    ///
    /// - Parameter completion: The block to call after the attempt to clear all jobs is complete.
    public func clear(completion: ((Error?) -> Void)?) {
        do {
            let path = fileManager.currentDirectoryPath
            try fileManager.removeItem(atPath: path)
            try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
            fileManager.changeCurrentDirectoryPath(path)
        } catch let error {
            completion?(error)
        }
        
        completion?(nil)
    }
}
