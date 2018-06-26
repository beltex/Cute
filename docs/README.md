# Cute
## A simple way to create, process, and observe Queues in Swift
Ah, queing. Everything will eventually need it. While iOS offers `NSOperation` and `NSOperationQueue`, in my experience they are messy, confusing, difficult to use, and not very portable. `Cute` attempts to solve that problem by implementing a basic, thread-safe and type-safe Queue structure, complete with type-safe processing, observing, and persistence. `Cute` is composable, portable, and easy to use.

## Table of Contents

* [Installation](#installation)
    * [Carthage](#carthage)
    * [Clone n' Build](#clone-n-build)
* [Using Cute](#using-cute)
    * [JobQueues and QueueJobs](#jobqueues-and-queuejobs)
    * [Creating a QueueJob](#creating-a-queuejob)
    * [Creating a JobQueue](#creating-a-jobqueue)
    * [Persisting QueueJobs](#persisting-queuejobs)
        * [FileBasedPersister](#filebasedpersister)
    * [Processing a JobQueue](#processing-a-jobqueue)
    * [Job Retry Strategies](#job-retry-strategies)
        * [The HaltRetryStrategy](#the-haltretrystrategy)
        * [The MaxRetryStrategy](#the-maxretrystrategy)
        * [BackoffRetryStrategy](#backoffretrystrategy)
    * [Observing JobQueues](#observing-jobqueues)

## Installation
First thing first, you need to "install" it. You have 2 options: `Carthage` and `Good Ol' Clone 'n Build`.

### Carthage
1. Add the following to your Cartfile

    > github "https://github.ehealthinnovation.org/PHIT/Cute.git" ~> 0.1
    
2. Do a `carthage update --platform iOS --cache-builds`
3. Install the framework as described in [building for iOS, tvOS, or watchOS](https://github.com/Carthage/Carthage#if-youre-building-for-ios-tvos-or-watchos)
4. Build your first queue!

### Clone n' Build
1. `git clone` this repo
2. Open the `Cute.xcodeproj` and build it.

## Using Cute
Cute attempts to make things as simple as possible for queing and processing jobs. It attempts to make no assumptions about how you use queues, including whether or not you wish to process the queues automagically. Cute is, ultimately, pretty stupid.

We will build up a JobQueue, step by step, but first - a diagram!


[Insert a diagram here]

### JobQueues and QueueJobs
Well, the naming sucks, but here's what they are:

- `QueueJob`: A protocol which defines what a job is. `QueueJob` defines 4 fields:
    - `id: String`: The unique id of a given job.
    - `createdDate: Date`: The Date the job was created
    - `data: Data?`: The optional data contained in this job which will be used by a processor
    - `action: String`: The "action" for this job, in the situation where a processor may need to do one of multiple things when processing a job. `action` is domain specific, and can be whatever you need it to be. 

- `JobQueue<Job: QueueJob>`: A generic Queue which (optionally) processes a `QueueJob`. `JobQueue`s are basic Queue structures (first in, first out) with a typical Queue interfaces:
    - `add(_: [Job])`: addes an array of jobs to the queue
    - `remove() -> Job`: Removes the next job in the queue and returns it
    - `peek() -> Job`: Returns the next job in the queue _without_ removing it.
    - `count: Int`: Returns the number of jobs in the queue.

    `Cute.JobQueue`s provide additional APIs:
    
    - `cancel(id: String)`: Removes a job from the queue with the matching `id`
    - `retry(_: Job)`: Adds the job at the front of the queue so it's next up for processing. This is typically used by a `RetryStrategy`, which we'll get to later.
    - `start()`: If the queue has been assigned a `JobProcessor`, then the queue will start feeding queued jobs to the processor.
    - `stop()`: The inverse of `start`, in that the queue will stop feeding queued jobs to the processor
    - `observe(_: @escaping (JobQueue<Job>, [Job], JobQueueEvent) -> Void) -> JobQueueNotificationToken<Job>`: Provides a means of observing activity in the queue.

### Creating a QueueJob
`QueueJob` is a simple protocol to which anything can be conformed. In my experience, conforming to a `struct` is the most convenient and, likely, the more swifty way of doing things. Because Swift 4 allows you to typealias existing structs/classes, and furthermore allows you to add extensions to those typealiases, it's easiest to create a "base" `QueueJob` for your project. You can use the following as a template:

```Swift
import Foundation
import Cute

struct CuteJob: QueueJob {
  private(set) var id: String = UUID().uuidString
  private(set) var createdDate = Date()
  var data: Data?
  var action: String = ""
}
```

With the above "base" `QueueJob`, we can easily create other "types" of jobs. For example, if we wanted to define a `QueueJob` used for uploading a FHIR Observation to a server, we could do the following:

```Swift
import Foundation
import FireKit

enum UploadAction: String {
    case create, update, delete
}

typealias ObservationUploadJob = CuteJob
extension ObservationUploadJob {
    
    var uploadAction: UploadAction? {
        return UploadAction(rawValue: action)
    }
    
    init(_ action: UploadAction, _ observation: Observation) throws {
        self.action = action.rawValue
        self.data = try JSONEncoder().encode(observation)
    }
}
```

We can now create an `ObservationUploadJob` by simply doing the following:

```Swift
import Foundation
import FireKit

let observation = Observation()
observation.valueString = "Above Threshold"
observation.subject = Reference(Patient.self, id: "\(123456)")

let job = try? ObservationUploadJob(.create, observation)
```

We now have a `QueueJob` of type `ObservationUploadJob`, complete with serialized observation data and an action specific to this domain. This job can now be submitted to any `JobQueue` which allows `ObservationUploadJob`s. 

### Creating a JobQueue
With the `ObservationUploadJob` defined, how do we create the `JobQueue` that will accept that type of job? Easy - just do the following:

```Swift
import Foundation
import Cute

let observationUploadQueue = JobQueue(handling: ObservationUploadJob.self, 
                                      name: "Observation Upload Queue")
```

That's it. We now have a JobQueue of type `JobQueue<ObservationUploadJob>` that will only accept jobs of that defined type. As such, we can submit our job to the queue by calling the `add(_: [ObservationUploadJob])` method on the queue:

```Swift
observationUploadQueue.add([job])
```
Creating a basic `JobQueue` like the one above creates an _in-memory only_ JobQueue. This means as soon as the queue goes out of scope, any jobs contained in the Queue will be lost. This might be okay in some use cases, but you may want to persist those jobs between scope or app-cycles. For that we turn to `JobPersister`s.

### Persisting QueueJobs
You can persist jobs in a JobQueue by assigning that JobQueue a `JobPersister<JobType: QueueJob>`, a protocol with an `associatedtype`. There are 4 functions defined on a `JobPersister`:

- `persist(_: [JobType]) throws`: Persists the given jobs to... somewhere!
- `delete(_: JobType) throws`: Deletes the job's persistent representation
- `load() throws -> [JobType]`: Loads and returns all jobs from their persistent representation
- `clear(completion: ((Error?) -> Void)?)`: Clear all persisted jobs

If a `JobQueue` is provided a `JobPersister`, then the `JobQueue` will attempt to `persist` every added job, while also `delete`ing every `removed` job. Furthermore, if a JobQueue is initialized with a `JobPersister`, the `JobQueue` will atttempt to `load` all jobs from the persister and `add` the returned jobs to itself.

#### FileBasedPersister
`Cute` provides a single `JobPersister` out of the box: The `FileBasedPersister`. The `FileBasedPersister` persists jobs to the local device's file system. Specifically, it will persist the jobs in the device's `Application Support` directory at `Application Support/Cute/Queues/[Queue Name]`.

So if we wanted the queue we created earlier to persist its jobs, we can either create and assign it our own `JobPersister` (if we want to persist the job somewhere other than the local FileSystem), or simply create an instance of `FileBasedPersister` and assign it.

```Swift
import Foundation
import Cute

let name = "Observation Upload Queue"
let observationUploadQueue = try JobQueue(handling: ObservationUploadJob.self,
                                      name: name)
let persister = FileBasedPersister(handling: ObservationUploadJob.self,
                                   queueName: name)
                                   
// Note: We need to type-erase using `AnyJobPersister` because you can't store
// protocols with associated types as parameters or properties.
observationUploadQueue.persister = AnyJobPersister(persister)
```
Our `observationUploadQueue` will now persist any added, removed, or cancelled jobs to the device's file system at `Application Support/Cute/Queues/Observation-Upload-Queue".

If we want our `observationUploadQueue` to load jobs and add them on `init`, we would simply pass the persister at the time of initialization:

```Swift
import Foundation
import Cute

let name = "Observation Upload Queue"
let persister = FileBasedPersister(handling: ObservationUploadJob.self,
                                   queueName: name)
let observationUploadQueue = try JobQueue(handling: ObservationUploadJob.self,
                                      name: name,
                                      persister: persister)
```
### Processing a JobQueue
By default JobQueues are in-memory only queues which don't actually do any processing. They simply maintain a First-In-First-Out data buffer which must be manually maintained. This can be useful in, say, a function which requires short controlled processing, but for background processing it stinks. Enter the `JobProcessor<JobType: QueueJob>`.

```Swift
public protocol JobProcessor: class {
    associatedtype JobType: QueueJob
    
    func processJob(_ job: JobType, completion: @escaping ((JobType, Error?) -> Void))
}
```

`JobProcessor<JobType: QueueJob>` is a protocol with an associatedtype of `JobType`, which must conform to the `QueueJob` protocol (just like `JobQueue`s and `JobPersister`s). The protocol has a single function, `processJob(_: JobType, completion: @escaping ((JobType, Error?) -> Void))`. This function receives a job, does something with the job, and then calls the completion block. If the job failed to process, we call the completion with the job that was received, along with the generated `Error`. Otherwise, if the processing was successful, we simply call the completion block with job that was successfully processed.

To continue our Observation Upload example, we could create a `JobProcessor` with the following (somewhat pseudo) code:

```Swift
class ObservationUploadJobProcessor: JobProcessor {
    typealias JobType = ObservationUploadJob

    // some server which knows how to add/update/delete, and returns a promise to do so
    var server: ObservationServer?
    
    convenience init(server: ObservationServer) {
        self.init()
        self.server = server
    }
    
    func processJob(_ job: ObservationUploadJob, completion: @escaping ((ObservationUploadJob, Error?) -> Void)) {
        guard let data = job.data else {
            fatalError("No data was found in Job, and thus we cannot upload the Observation to the server. Removing job from queue.")
        }
        
        guard let action = job.uploadAction else {
            fatalError("Could not determine the job's upload action `\(job.action)`. This seems like a bug.")
        }
        
        var observation: Observation!
        do {
            observation = try JSONDecoder().decode(Observation.self, from: data)
        } catch let error {
            fatalError("Failed to deserialize the FHIR Observation from the ObservationUploadJob. This seems like a bug: \(error)")
        }
        
        firstly {
            serverAction(action, forObservation: observation)
        }.done { Observations in
            completion(job, nil)
        }.catch { error in
            completion(job, error)
        }
    }
    
    func serverAction(_ action: ObservationUploadAction, forObservation Observation: Observation) -> Promise<[Observation]> {
        guard let server = server else {
            fatalError("No ObservationServer was set on the ObservationUploadQueueProcesser prior to it being started. This is a bug.")
        }
        
        switch action {
        case .create: return server.create(Observations: [Observation])
        case .update: return server.update(Observations: [Observation])
        case .delete: return server.delete(Observations: [Observation])
        }
    }
}
```

The above processor attempts to invoke the appropriate function on some mythical `ObservationServer`, which notifies the queue of whether or not it was successful. That's it!

You can assign a `JobQueue` any `JobProcessor` which processes the same type of job as the `JobQueue`. 

```Swift
import Foundation
import Cute

let name = "Observation Upload Queue"
let persister = FileBasedPersister(handling: ObservationUploadJob.self,
                                   queueName: name)
let observationUploadQueue = try JobQueue(handling: ObservationUploadJob.self,
                                      name: name,
                                      persister: persister)
observationUploadQueue.processor = AnyJobProcessor(ObservationUploadJobProcessor(server: MyObservationServer())
```

However, recall that `JobQueue` have `start` and `stop` methods. These methods control whether or not a `JobQueue` will forward its jobs to the assigned JobProcessor. 

```Swift
...
observationUploadQueue.processor = AnyJobProcessor(ObservationUploadJobProcessor(server: MyObservationServer())
observationUploadQueue.start()
```
By calling `start` above, we tell our ObservationUploadQueue to start forwarding jobs to the assigned `JobProcessor`. The queue will continue to send jobs to the processor until the queue is empty, after which any new jobs that were added to the queue will also be forwarded to the processor.

Conversely, we can tell the queue to stop sending jobs to its assigned processor by calling the queue's `stop` method.

```Swift
...
observationUploadQueue.stop()
```
When called, the `stop` function will waiting until the current processing job is completed, afterwhich no more jobs will be sent to the assigned processor until `start` is called.

The `start()` and `stop()` functions are important, and can be useful if we need to re-try jobs which failed to process. Speaking of which...

### Job Retry Strategies
When a `JobQueue` forwards a job to a `JobProcessor` for processing, the `JobQueue` will first _`remove()`_ that job from the queue. Any jobs that fail to process, by default, _will not be re-added to the queue_. However, `JobQueue`s _do_ provide a means of re-trying a failed job using a `JobRetryStrategy<QueueJob>`.

```Swift 4
public protocol JobRetryStrategy {
    
    /// Instructs how to retry the failed `job` on the provided `queue`
    ///
    /// - Parameters:
    ///   - job: The QueueJob which failed to process
    ///   - queue: The JobQueue on which the job failed.
    func retry<JobType: QueueJob>(job: JobType, failedOnQueue queue: JobQueue<JobType>)
}
```

A `JobRetryStrategy<QueueJob>` is a simple protocol which defines a method, `retry<JobType: QueueJob>(job: JobType, failedOnQueue queue: JobQueue<JobType>)`. This method is provided the failed job, along with the JobQueue on which the job had failed processing. 

You can create your own `JobRetryStrategy`to do whatever you want. By default, `Cute` provides 3 different retry strategies for you: 

- `HalthRetryStrategy`
- `MaxRetryStrategy`
- `BackoffRetryStrategy`.

#### The HaltRetryStrategy
The `HaltRetryStrategy` is a bit of a misleading name. It doesn't actually retry at all. Rather, the `HaltRetryStrategy` simply stops the queue and then re-queues the failed job at the front of the queue. The queue must be manually restarted. In most circumstances it is unlikely you'd want to actually use the `HaltRetryStrategy` for any kind of background processing.

#### The MaxRetryStrategy
The `MaxRetryStrategy` will re-add the job to the front of the queue such that the queue will re-attempt to process the job again (remember, queues will always `remove` the next job in line, and pass that job to the job processor). The `MaxRetryStrategy` will re-queue the failed job up to a max-number of times. If the job still fails to process after the max number of attempts is reached, the strategy will not re-add the job to the queue and the job will be purged.

#### BackoffRetryStrategy
The `BackoffRetryStrategy` will progressively "back off" attempts of processing the job, starting at 1 second. If the job fails again, the strategy will try to process the job again in 2 seconds, then 4 second, then 8, and so on, until a max-backoff is reached (defaults to 1 hour, or 3600 seconds). The `BackoffRetryStrategy` will never purge the queue of a failed job.

The `BackoffRetryStrategy` accomplishes the above by performing the following steps:

1. Stop the queue
2. re-add the job to the front of the queue
3. Schedule a `Timer` to fire in X-seconds
4. When `Timer` fires, the strategy re-starts the queue

You can define a re-try strategy for a `JobQueue` by assigning it's `retryStrategy` property to an instance of anything that conforms to the `JobRetryStrategy` protocol.

```Swift
observationUploadQueue.retryStrategy = BackoffRetryStrategy(maxBackoff: 60*60) // waits a max 1 hour
```

### Observing JobQueues
A `JobQueue` fires notifications to observers during key events. Specifically, observers receive notifications whenever a JobQueue

- adds a job
- removes a job
- cancels a job
- processes a job
- fails to process a job

An observer receives a notification by calling a `JobQueue`'s `observe` function and passing it a block. 

```Swift
let token = observationUploadQueue.observe { queue, jobs, event in
    switch event {
        case .added: 
            print("\(jobs) were added to queue \(queue)")
        case .removed:
            print("\(jobs) were removed from queue \(queue)")
        case .cancelled:
            print("\(jobs) were cancelled in queue \(queue)")
        case .processed:
            print("\(jobs) successfully processed on queue \(queue)")
        case .failedToProcess:
            print("\(jobs) failed to process on queue \(queue)")
    }
}
```
The `observe` function returns a _weak_ `JobQueueNotificationToken` which must be strongly retained. As soon as the token goes out of scop,e the `JobQueue` will stop sending notifications to that observer.
