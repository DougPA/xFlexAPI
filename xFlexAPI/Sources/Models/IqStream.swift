//
//  IqStream.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 3/9/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// ------------------------------------------------------------------------------
// MARK: - IqStream Class implementation
//
//      creates a udp stream of I / Q data, from a Panadapter in the Radio (hardware) to
//      to the Client, to be used by the client for various purposes (e.g. CW Skimmer,
//      digital modes, etc.)
//
// ------------------------------------------------------------------------------

final public class IqStream: NSObject {
    
    // ------------------------------------------------------------------------------
    // MARK: - Public properties
    
    public private(set) var id = ""                 // Stream Id
    
    // ------------------------------------------------------------------------------
    // MARK: - Internal properties
    
    private var _radio: Radio!                      // The Radio that owns this Tnf
    private var _iqStreamsQ: DispatchQueue          // GCD queue that guards IqStreams
    private var _initialized = false                // True if initialized by Radio hardware
    private var _shouldBeRemoved = false            // True if being removed
    
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    //                                                                                              //
    private var __available = 0                     // Number of available IQ Streams               //
    private var __capacity = 0                      // Total Number of  IQ Streams                  //
    private var __daxIqChannel = 0                  // Channel in use (1 - 8)                       //
    private var __ip = ""                           // Ip Address                                   //
    private var __pan: Radio.PanadapterId?          // Source Panadapter                            //
    private var __port = 0                          // Port number                                  //
    private var __rate = 0                          // Stream rate                                  //
    private var __streaming = false                 // Stream state                                 //
    //                                                                                              //
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
    
    // constants
    private let _log = Log.sharedInstance           // shared Log
    
    /// Initialize an IQ Stream
    ///
    /// - Parameters:
    ///   - daxChannel:         the Channel to use
    ///   - radio:              the Radio instance
    ///   - queue:              IqStreams concurrent Queue
    ///
    init(radio: Radio, id: String, queue: DispatchQueue) {
        
        self._radio = radio
        self.id = id
        self._iqStreamsQ = queue
        
        super.init()
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - KeyValueParser Protocol methods
    //     called by Radio, executes on the radioQ
    
    /// Parse IQ Stream key/value pairs
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///
    public func parseKeyValues(_ keyValues: Radio.KeyValuesArray) {
        
        // process each key/value pair, <key=value>
        for kv in keyValues {
            
            guard let token = IqStreamToken(rawValue: kv.key.lowercased()) else {
                // unknown Key, log it and ignore the Key
                _log.msg("Unknown token - \(kv.key)", level: .debug, function: #function, file: #file, line: #line)
                continue
            }
            // get the Int and Bool versions of the value
            let iValue = (kv.value).iValue()
            let bValue = (kv.value).bValue()
            
            // known keys, in alphabetical order
            switch token {
                
            case .available:
                willChangeValue(forKey: "available")
                _available = iValue
                didChangeValue(forKey: "available")
                
            case .capacity:
                willChangeValue(forKey: "capacity")
                _capacity = iValue
                didChangeValue(forKey: "capacity")
                
            case .daxIqChannel:
                willChangeValue(forKey: "daxIqChannel")
                _daxIqChannel = iValue
                didChangeValue(forKey: "daxIqChannel")
                
            case .ip:
                willChangeValue(forKey: "ip")
                _ip = kv.value
                didChangeValue(forKey: "ip")
            
            case .pan:
                willChangeValue(forKey: "pan")
                _pan = String(kv.value.characters.dropFirst(2))
                didChangeValue(forKey: "pan")                
                
            case .port:
                willChangeValue(forKey: "port")
                _port = iValue
                didChangeValue(forKey: "port")
                
            case .rate:
                willChangeValue(forKey: "rate")
                _rate = iValue
                didChangeValue(forKey: "rate")

            case .streaming:
                willChangeValue(forKey: "streaming")
                _streaming = bValue
                didChangeValue(forKey: "streaming")
            }
        }
        // is the Stream initialized?
        if !_initialized && _ip != "" {
            
            // YES, the Radio (hardware) has acknowledged this Tnf
            _initialized = true
            
            // notify all observers
            NC.post(.iqStreamInitialized, object: self as Any?)
        }
    }
}

// --------------------------------------------------------------------------------
// MARK: - IqStream Class extensions
//              - Synchronized internal properties
//              - Dynamic public properties
//              - AudioStream message enum
// --------------------------------------------------------------------------------

extension IqStream {
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties - with synchronization
    
    // listed in alphabetical order
    private var _available: Int {
        get { return _iqStreamsQ.sync { __available } }
        set { _iqStreamsQ.sync(flags: .barrier) { __available = newValue } } }
    
    private var _capacity: Int {
        get { return _iqStreamsQ.sync { __capacity } }
        set { _iqStreamsQ.sync(flags: .barrier) { __capacity = newValue } } }
    
    private var _daxIqChannel: Int {
        get { return _iqStreamsQ.sync { __daxIqChannel } }
        set { _iqStreamsQ.sync(flags: .barrier) { __daxIqChannel = newValue } } }
    
    private var _ip: String {
        get { return _iqStreamsQ.sync { __ip } }
        set { _iqStreamsQ.sync(flags: .barrier) { __ip = newValue } } }
    
    private var _port: Int {
        get { return _iqStreamsQ.sync { __port } }
        set { _iqStreamsQ.sync(flags: .barrier) { __port = newValue } } }
    
    private var _pan: Radio.PanadapterId? {
        get { return _iqStreamsQ.sync { __pan } }
        set { _iqStreamsQ.sync(flags: .barrier) { __pan = newValue } } }
    
    private var _rate: Int {
        get { return _iqStreamsQ.sync { __rate } }
        set { _iqStreamsQ.sync(flags: .barrier) { __rate = newValue } } }
    
    private var _streaming: Bool {
        get { return _iqStreamsQ.sync { __streaming } }
        set { _iqStreamsQ.sync(flags: .barrier) { __streaming = newValue } } }
        
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (with message sent to Radio)
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (no message to Radio)
    
    // FIXME: Should any of these send a message to the Radio?
    //          If yes, implement it, if not should they be "get" only?
    
    // listed in alphabetical order
    @objc dynamic public var available: Int {
        return _available }
    
    @objc dynamic public var capacity: Int {
        return _capacity }
    
    @objc dynamic public var daxIqChannel: Int {
        get { return _daxIqChannel }
        set { if _daxIqChannel != newValue { _daxIqChannel = newValue } } }
    
    @objc dynamic public var ip: String {
        get { return _ip }
        set { if _ip != newValue { _ip = newValue } } }
    
    @objc dynamic public var port: Int {
        get { return _port  }
        set { if _port != newValue { _port = newValue } } }
    
    @objc dynamic public var pan: Radio.PanadapterId? {
        get { return _pan }
        set { if _pan != newValue { _pan = newValue } } }
    
    @objc dynamic public var rate: Int {
        get { return _rate  }
        set { if _rate != newValue { _rate = newValue } } }
    
    @objc dynamic public var streaming: Bool {
        get { return _streaming  }
        set { if _streaming != newValue { _streaming = newValue } } }
    
    // ----------------------------------------------------------------------------
    // Mark: - Tokens for IqStream messages (only populate values that != case value)
    
    internal enum IqStreamToken: String {
        case available
        case capacity
        case daxIqChannel = "daxiq"
        case ip
        case pan
        case port
        case rate
        case streaming
    }
}
