//
//  Pinger.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 12/14/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Foundation

// ------------------------------------------------------------------------------
// MARK: - Pinger Class implementation
//
//      generates "ping" messages once a second, if no reply is received
//      sends a .tcpPingTimeout Notification
//
// ------------------------------------------------------------------------------

public final class Pinger {
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private var _tcpManager: TcpManager                 // a TcpManager instance
    private var _pingTimer: DispatchSourceTimer!        // periodic timer for ping
    private var _pingQ: DispatchQueue!                  // Queue for Pinger synchronization
    private var _lastPingRxTime: Date!                  // Time of the last ping response
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    /// Initialize a Pinger
    ///
    /// - parameter tcpManager: a TcpManager class instance
    ///
    public init(tcpManager: TcpManager, pingQ: DispatchQueue) {
        
        self._tcpManager = tcpManager
        self._pingQ = pingQ
        
        // start pinging
        startPingTimer()
    }
    
    deinit {

        // stop pinging
        stopPingTimer()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    /// Process the Response to a Ping
    ///
    public func pingReply(_ command: String, seqNum: String, responseValue: String, reply: String) {
        
        _pingQ.async {
            
            // save the time of the Response
            self._lastPingRxTime = Date(timeIntervalSinceNow: 0)
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Start the Ping timer
    ///
    private func startPingTimer() {
        
        // tell the Radio to expect pings
        let _ = _tcpManager.send("keepalive enable")
        
        // fake the first response
        _lastPingRxTime = Date(timeIntervalSinceNow: 0)
        
        // create the timer's dispatch source
        _pingTimer = DispatchSource.makeTimerSource(flags: [.strict], queue: _pingQ)
        
        // Set timer for 1 second with 100 millisecond leeway
        _pingTimer.scheduleRepeating(deadline: DispatchTime.now(), interval: .seconds(1), leeway: .milliseconds(100))      // Every second +/- 10%
        
        // inform observers
        NC.post(.tcpPingStarted, object: nil)
        
        // set the event handler
        _pingTimer.setEventHandler { [ unowned self] in
            
            // get current datetime
            let now = Date(timeIntervalSinceNow:0)
            
            // has it been 4 seconds since the last response?
            if now.timeIntervalSince(self._lastPingRxTime) > 4.0 {
                
                // YES, timeout, inform observers
                NC.post(.tcpPingTimeout, object: nil)
                
                // stop the Timer
                self.stopPingTimer()
                
            } else {
                
                // NO, send another Ping
                let _ = self._tcpManager.send("ping", replyTo: self.pingReply)
            }
        }
        
        // start the timer
        _pingTimer.resume()
    }
    /// Stop the Ping timer
    ///
    private func stopPingTimer() {
        
        // stop the Timer (if any)
        _pingTimer?.cancel();
    }
    
}
