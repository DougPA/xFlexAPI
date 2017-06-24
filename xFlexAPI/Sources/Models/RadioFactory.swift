//
//  RadioFactory.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 5/13/15
//  Copyright (c) 2015 Douglas Adams, K3TZR
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - RadioFactory implementation
//
//      listens for the udp broadcasts announcing the presence of a Flex-6000
//      Radio, reports changes to the list of available radios
//
// --------------------------------------------------------------------------------

public final class RadioFactory: NSObject, GCDAsyncUdpSocketDelegate {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    typealias IPAddress = String                            // dotted decimal form
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
//    private var _vita = Vita()                          // a Vita-49 packet
    private var _notSeenInterval: TimeInterval = 3.0    // Interval that represents a timeout
    private var _udpSocket: GCDAsyncUdpSocket?          // socket to receive broadcasts
    private var _timeoutTimer: DispatchSourceTimer!     // timer fired every "checkInterval"
    private var _availableRadios =                      // Radios identified by IP Address
        [IPAddress : RadioParameters]()

    // GCD Queues
    private let _discoveryQ =   DispatchQueue(label: "RadioFactory" + ".discoveryQ")
    private var _timerQ =       DispatchQueue(label: "RadioFactory" + ".timerQ")
    private let _radiosQ =      DispatchQueue(label: "RadioFactory" + ".radiosQ", attributes: .concurrent)
    
    // constants
    private let _log =      Log.sharedInstance          // shared log
    private let kModule =   "RadioFactory"              // Module Name reported in log messages

    // ----------------------------------------------------------------------------
    // MARK: - Private Getter / Setter with synchronization
    
    private var availableRadios: [IPAddress : RadioParameters] {
        get { return _radiosQ.sync { _availableRadios } }
        set { _radiosQ.sync(flags: .barrier) { _availableRadios = newValue } } }
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    /// Initialize a RadioFactory
    ///
    /// - Parameters:
    ///   - discoveryPort: port number
    ///   - checkInterval: how often to check
    ///   - notSeenInterval: timeout interval
    ///
    public init(discoveryPort: UInt16 = 4992, checkInterval: TimeInterval = 1.0, notSeenInterval: TimeInterval = 3.0) {
        
        super.init()
        
        // create a Udp socket
        _udpSocket = GCDAsyncUdpSocket( delegate: self, delegateQueue: _discoveryQ )
        
        // if created
        if let sock = _udpSocket {
            
            // set socket options
            sock.setPreferIPv4()
            sock.setIPv6Enabled(false)

            // enable port reuse (allow multiple apps to use same port)
            do {
                try sock.enableReusePort(true)
            
            } catch let error as NSError {
                _log.msg("Port reuse not enabled: \(error.localizedDescription)", level: .warning, function: #function, file: #file, line: #line)
            }
            
            // bind the socket to the Flex Discovery Port
            do {
                try sock.bind(toPort: discoveryPort)
            }
            catch let error as NSError {
                fatalError("Bind to port error: \(error.localizedDescription)")
            }
            
            do {
                
                // attempt to start receiving
                try sock.beginReceiving()
                
                // create the timer's dispatch source
                _timeoutTimer = DispatchSource.makeTimerSource(flags: [.strict], queue: _timerQ)
                
                // Set timer with 100 millisecond leeway
                _timeoutTimer.scheduleRepeating(deadline: DispatchTime.now(), interval: checkInterval, leeway: .milliseconds(100))      // Every second +/- 10%
                
                // set the event handler
                _timeoutTimer.setEventHandler { [ unowned self] in
                    
                    var deleteList = [RadioParameters]()
                    
                    // check the timestamps of the UDPBroadcasts
                    for (_, radioParameters) in self.availableRadios {
                        
                        // is it past expiration?
                        if radioParameters.lastSeen.timeIntervalSinceNow < -notSeenInterval {
                            
                            // YES, add to the delete list
                            deleteList.append(radioParameters)
                        }
                    }
                    // are there any deletions?
                    if deleteList.count > 0 {
                        
                        // YES, remove the Radio(s)
                        for radioParameters in deleteList {
                            
                            self.availableRadios[radioParameters.ipAddress] = nil
                        }
                        // send the updated list of radios to all observers
                        NC.post(.radiosAvailable, object: Array(self.availableRadios.values) as Any?)
                    }
                }
                
            } catch let error as NSError {
                fatalError("Begin receiving error: \(error.localizedDescription)")
            }
            // start the timer
            _timeoutTimer.resume()
        }
    }
    
    deinit {
        _timeoutTimer?.cancel()
        
        _udpSocket?.close()
    }
    
    /// send a Notification containing a list of current radios
    ///
    public func updateAvailableRadios() {
        
        // send the current list of radios to all observers
        NC.post(.radiosAvailable, object: Array(self.availableRadios.values) as Any?)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - GCDAsyncUdpSocket delegate methods
    //    Note: called on its GCD thread
    
    /// The Socket received data
    ///
    /// - parameter sock:          the GCDAsyncUdpSocket
    /// - parameter data:          the Data received
    /// - parameter address:       the Address of the sender
    /// - parameter filterContext: the FilterContext
    ///
    @objc public func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        
        // VITA encoded Discovery packet
        if let vitaPacket = Vita.decode(vitaPacket: data) {
            
            // parse the packet to obtain a Radio instance
            if let radioParameters = vitaPacket.parseDiscoveryPacket() {
                
                // is it new?
                if availableRadios[radioParameters.ipAddress] == nil {
                
                    // YES, add it to the collection
                    availableRadios[radioParameters.ipAddress] = radioParameters
                    
                    // send the updated list of radios to all observers
                    NC.post(.radiosAvailable, object: Array(self.availableRadios.values) as Any?)
                }
                else {
                    
                    _timerQ.sync {
                        // NO, update the time last seen
                        availableRadios[radioParameters.ipAddress]?.lastSeen = Date()
                    }
                }
                
            }
        }
    }
    
}
