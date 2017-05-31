//
//  IqStream.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 3/9/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

final public class IqStream: NSObject {
    
    // ------------------------------------------------------------------------------
    // MARK: - Internal properties
    
    fileprivate weak var _radio: Radio!                 // The Radio that owns this Tnf
    fileprivate var _iqStreamsQ: DispatchQueue          // GCD queue that guards IqStreams
    fileprivate var _initialized = false                // True if initialized by Radio hardware
    fileprivate var _shouldBeRemoved = false            // True if being removed
    
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
    //
    fileprivate var __available = 0                     // Number of available IQ Streams
    fileprivate var __capacity = 0                      // Total Number of  IQ Streams
    fileprivate var __daxIqChannel = 0                  // Channel in use (1 - 8)
    fileprivate var __ip = ""                           // Ip Address
    fileprivate var __pan: Radio.PanadapterId?          // Source Panadapter
    fileprivate var __port = 0                          // Port number
    fileprivate var __rate = 0                          // Stream rate
    fileprivate var __streamId = ""                     // Stream Id
    fileprivate var __streaming = false                 // Stream state
    //
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
    
    // constants
    fileprivate let _log = Log.sharedInstance           // shared Log
    fileprivate let kModule = "IqStream"                // Module Name reported in log messages
    fileprivate let kNoError = "0"                      // response without error

    fileprivate let kStreamCmd = "stream "              // Command string prefixes
    fileprivate let kStreamCreateCmd = "stream create "
    
    /// Initialize an IQ Stream
    ///
    /// - Parameters:
    ///   - daxChannel:         the Channel to use
    ///   - radio:              the Radio instance
    ///   - queue:              IqStreams concurrent Queue
    ///
    init(channel: Radio.DaxIqChannel, radio: Radio, queue: DispatchQueue) {
        
        self._radio = radio
        self._iqStreamsQ = queue
        
        super.init()
        
        self._daxIqChannel = channel
//        _pan = radio.findPanadapterBy(daxIqChannel: daxIqChannel)
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - Public methods that send commands to the Radio (hardware)
    
    public func requestIqStream() { _radio?.send(kStreamCreateCmd + "daxiq=\(_daxIqChannel)", replyTo: _radio.replyHandler) }
    public func requestIqStream(ip: String, port: Int) { _radio?.send(kStreamCreateCmd + "daxiq=\(_daxIqChannel) ip=\(ip) port=\(port)", replyTo: _radio.replyHandler) }
    public func removeIqStream(_ channel: String) { _radio?.send("stream remove 0x\(channel)") }
    
    // ------------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Process the Reply to a Stream Create command, reply format: <value>,<value>,...<value>
    ///
    /// - Parameters:
    ///   - seqNum:         the Sequence Number of the original command
    ///   - responseValue:  the response value
    ///   - reply:          the reply
    ///
//    private func updateStreamId(_ seqNum: String, responseValue: String, reply: String) {
//        
//        guard responseValue == kNoError else {
//            // Anything other than 0 is an error, log it and ignore the Reply
//            _log.msg(command + ", non-zero reply - \(responseValue)", level: .error, function: #function, file: #file, line: #line)
//            return
//        }
//        //get the streamId (remove the "0x" prefix)
//        _streamId = String(reply.characters.dropFirst(2))
//    }
    
    // ------------------------------------------------------------------------------
    // MARK: - KeyValueParser Protocol methods
    //     called by Radio, executes on the radioQ
    
    /// Parse IQ Stream key/value pairs
    ///
    /// - parameter keyValues: a KeyValuesArray
    ///
    public func parseKeyValues(_ keyValues: Radio.KeyValuesArray) {
        
        // process each key/value pair, <key=value>
        for kv in keyValues {
            
            guard let token = Token(rawValue: kv.key.lowercased()) else {
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
        // if this is an initialized AudioStream and inUse becomes false
        if _initialized && _shouldBeRemoved == false {
            
            // mark it for removal
            _shouldBeRemoved = true
            
            // notify all observers
            NC.post(.iqStreamShouldBeRemoved, object: self)
        }
        // is the Tnf initialized?
        if !_initialized {
            
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
    fileprivate var _available: Int {
        get { return _iqStreamsQ.sync { __available } }
        set { _iqStreamsQ.sync(flags: .barrier) { __available = newValue } } }
    
    fileprivate var _capacity: Int {
        get { return _iqStreamsQ.sync { __capacity } }
        set { _iqStreamsQ.sync(flags: .barrier) { __capacity = newValue } } }
    
    fileprivate var _daxIqChannel: Int {
        get { return _iqStreamsQ.sync { __daxIqChannel } }
        set { _iqStreamsQ.sync(flags: .barrier) { __daxIqChannel = newValue } } }
    
    fileprivate var _ip: String {
        get { return _iqStreamsQ.sync { __ip } }
        set { _iqStreamsQ.sync(flags: .barrier) { __ip = newValue } } }
    
    fileprivate var _port: Int {
        get { return _iqStreamsQ.sync { __port } }
        set { _iqStreamsQ.sync(flags: .barrier) { __port = newValue } } }
    
    fileprivate var _pan: Radio.PanadapterId? {
        get { return _iqStreamsQ.sync { __pan } }
        set { _iqStreamsQ.sync(flags: .barrier) { __pan = newValue } } }
    
    fileprivate var _rate: Int {
        get { return _iqStreamsQ.sync { __rate } }
        set { _iqStreamsQ.sync(flags: .barrier) { __rate = newValue } } }
    
    fileprivate var _streamId: String {
        get { return _iqStreamsQ.sync { __streamId } }
        set { _iqStreamsQ.sync(flags: .barrier) { __streamId = newValue } } }
    
    fileprivate var _streaming: Bool {
        get { return _iqStreamsQ.sync { __streaming } }
        set { _iqStreamsQ.sync(flags: .barrier) { __streaming = newValue } } }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant with Radio update
    
    // listed in alphabetical order
    dynamic public var available: Int {
        get { return _available }
        set { if _available != newValue { _available = newValue } } }
    
    dynamic public var capacity: Int {
        get { return _capacity }
        set { if _capacity != newValue { _capacity = newValue } } }
    
    dynamic public var daxIqChannel: Int {
        get { return _daxIqChannel }
        set { if _daxIqChannel != newValue { _daxIqChannel = newValue } } }
    
    dynamic public var ip: String {
        get { return _ip }
        set { if _ip != newValue { _ip = newValue } } }
    
    dynamic public var port: Int {
        get { return _port  }
        set { if _port != newValue { _port = newValue } } }
    
    dynamic public var pan: Radio.PanadapterId? {
        get { return _pan }
        set { if _pan != newValue { _pan = newValue } } }
    
    dynamic public var rate: Int {
        get { return _rate  }
        set { if _rate != newValue { _rate = newValue } } }
    
    dynamic public var streamId: String {
        get { return _streamId }
        set { if _streamId != newValue { _streamId = newValue } } }
    
    dynamic public var streaming: Bool {
        get { return _streaming  }
        set { if _streaming != newValue { _streaming = newValue } } }
    
    // ----------------------------------------------------------------------------
    // Mark: - Tokens for IqStream messages (only populate values that != case value)
    
    enum Token: String {
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
