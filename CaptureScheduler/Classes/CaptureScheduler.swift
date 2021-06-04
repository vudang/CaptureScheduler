//
//  CaptureScheduler.swift
//  CaptureScheduler
//
//  Created by Petr Bobák on 24.10.19.
//  Copyright © 2019 Veracity Protocol. All rights reserved.
//

import Foundation

public protocol CaptureSchedulerDelegate: class {
    /**
     Notifies the delegate that the scheduler did initiated capture event.
     
     - parameter progress: The current progress of the capture process.
     */
    func captureScheduler(_ scheduler: CaptureScheduler, didInitiateCaptureWithProgress progress: Progress)
}

public class CaptureScheduler: NSObject {
    // MARK: Private Vars
    private var deltaTimer: Timer?
    private var conditions: [Bool] = []
    
    // MARK: Public Vars
    public private(set) var requiredCaptures: Int
    public private(set) var timeInterval: TimeInterval
    public let minimalPositiveConditionFraction: Double
    
    /// A delegate object to receive messages about scheduled capture progress.
    public weak var delegate: CaptureSchedulerDelegate?
    
    /// A read-only property that stores current capture progress.
    public private(set) var progress: Progress
    
     /// A property that indicates whether the scheduler did completed all required capture events or not.
    public var isCompleted: Bool {
        return progress.completedUnitCount >= progress.totalUnitCount
    }
    
    /// A read-only property that indicates whether the scheduler is invalidated or not.
    public private(set) var isInvalidated = false
    
    // MARK: Public methods
    
    /**
    Initializes and returns a newly allocated capture scheduler.
     
    - parameters:
     - requiredCaptures: The number of capture events to schedule.
     - timeInterval: The time interval defines how often to check whether the `minimalPositiveConditionCount` number of positive conditions appeared in condition sequence. As a result, it also specifies the interval between invoked capture events.
     - minimalPositiveConditionFraction: The minimal percentage of positive conditions in sequence for invoking capture event `captureScheduler:didInitiateCaptureWithProgress:`.
     */
    @objc public init(requiredCaptures: Int, timeInterval: TimeInterval = 0.75, minimalPositiveConditionFraction: Double = 0.8) {
        self.requiredCaptures = requiredCaptures;
        self.timeInterval = timeInterval
        self.minimalPositiveConditionFraction = minimalPositiveConditionFraction
        self.progress = Progress(totalUnitCount: Int64(requiredCaptures))
        super.init()
    }
    
    /// Resets the state of instance.
    @objc public func reset() {
        progress = Progress(totalUnitCount: Int64(requiredCaptures))
        deltaTimer = nil
        conditions = []
        isInvalidated = false
    }
    
    /// Stops the scheduler from ever firing capture event again.
    @objc public func invalidate() {
        isInvalidated = true
        deltaTimer?.invalidate()
        deltaTimer = nil
        conditions = []
    }
    
    public func start() {
        isInvalidated = false
        if let _ = deltaTimer {
            return
        }
        
        DispatchQueue.main.async {
            // Timer needs to be on main queue.
            self.deltaTimer = Timer.scheduledTimer(timeInterval: self.timeInterval, target: self,
                                                   selector: #selector(self.timerTimeout), userInfo: nil, repeats: true)
        }
    }
    
    /// Informs the scheduler that new condition (positive or negative) did occured.
    @objc public func condition(_ condition: Bool) {
        if isCompleted || isInvalidated {
            return
        }
        
        if let _ = deltaTimer {
            conditions.append(condition)
            return
        }
        
        if condition == true {
            start()
            conditions.append(condition)
        }
    }
    
    // MARK: Private methods
    private func existsSequenceOf(length: Int) -> (Bool, Int) {
        var currentLength = 0;
        for condition in conditions {
            if condition == true {
                currentLength += 1
                if currentLength == length {
                    return (true, currentLength)
                }
            } else {
                currentLength = 0
            }
        }
        
        return (false, currentLength)
    }
    
    @objc private func timerTimeout() {
        let minimalPositiveConditionCount = Int(Double(conditions.count) * minimalPositiveConditionFraction)
        let (existsSequenceOfMinimalLength, _) = existsSequenceOf(length: minimalPositiveConditionCount)
//        print("Total Sequence Length: \(conditions.count), at least true: \(minimalPositiveConditionCount), positiveSequence: \(sequenceLength)")
        
        if existsSequenceOfMinimalLength {
            progress.completedUnitCount += 1
            
            if isCompleted {
                invalidate()
            }
            
            delegate?.captureScheduler(self, didInitiateCaptureWithProgress: progress)
        }
        
        conditions = []
    }
}
