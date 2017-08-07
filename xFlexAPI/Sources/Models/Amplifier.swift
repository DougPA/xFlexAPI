//
//  Amplifier.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 8/7/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation


// ------------------------------------------------------------------------------
// MARK: - Amplifier Class implementation
//
//      creates an Amplifier instance to be used by a Client to support the
//      control of an external Amplifier
//
// ------------------------------------------------------------------------------

public final class Amplifier: NSObject {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    public private(set) var id: String = ""                 // Id that uniquely identifies this Amplifier
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    internal var _radio: Radio?                             // The Radio that owns this Amplifier
    internal let kAmplifierSetCmd = "amplifier set "        // Amplifier command prefix
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _initialized = false                    // True if initialized by Radio hardware
    fileprivate var _amplifierQ: DispatchQueue              // GCD queue that guards this object
    fileprivate let _log = Log.sharedInstance               // shared log
    
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    //                                                                                                  //
    fileprivate var __ant = ""                              // Antenna list                             //
    fileprivate var __ip = ""                               // Ip Address (dotted decimal)              //
    fileprivate var __model = ""                            // Amplifier model                          //
    fileprivate var __port = 0                              //                                          //
    fileprivate var __serialNumber = ""                     // Serial number                            //
    //                                                                                                  //
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    
    // ------------------------------------------------------------------------------
    // MARK: - Initialization
    
    /// Initialize an Amplifier
    ///
    /// - Parameters:
    ///   - id:         an Xvtr Id
    ///   - radio:      parent Radio class
    ///   - queue:      Xvtr Concurrent queue
    ///
    public init(radio: Radio, id: String, queue: DispatchQueue) {
        
        self._radio = radio
        self.id = id
        self._amplifierQ = queue
        
        super.init()
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - KeyValueParser Protocol methods
    //     called by Radio, executes on the parseQ
    
    /// Parse Amplifier key/value pairs
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///
    func parseKeyValues(_ keyValues: Radio.KeyValuesArray) {
        
        // process each key/value pair, <key=value>
        for kv in keyValues {
            
            // check for unknown keys
            guard let token = AmplifierToken(rawValue: kv.key.lowercased()) else {
                
                // unknown Key, log it and ignore the Key
                _log.msg("Unknown token - \(kv.key)", level: .debug, function: #function, file: #file, line: #line)
                continue
            }
            // get the Integer version of the value
            let iValue = (kv.value).iValue()
            
            // Known keys, in alphabetical order
            switch token {
                
            case .ant:
                willChangeValue(forKey: "ant")
                _ant = kv.value
                didChangeValue(forKey: "ant")
                
            case .ip:
                willChangeValue(forKey: "ip")
                _ip = kv.value
                didChangeValue(forKey: "ip")
                
            case .model:
                willChangeValue(forKey: "model")
                _model = kv.value
                didChangeValue(forKey: "model")
                
            case .port:
                willChangeValue(forKey: "port")
                _port = iValue
                didChangeValue(forKey: "port")
                
            case .serialNumber:
                willChangeValue(forKey: "serialNumber")
                _serialNumber = kv.value
                didChangeValue(forKey: "serialNumber")
            }
        }
        // is the Amplifier initialized?
        if !_initialized {
            
            // YES, the Radio (hardware) has acknowledged this AMplifier
            _initialized = true
            
            // notify all observers
            NC.post(.amplifierHasBeenAdded, object: self as Any?)
        }
    }
}

// --------------------------------------------------------------------------------
// MARK: - Amplifier Class extensions
//              - Synchronized internal properties
//              - Public properties, no message to Radio
// --------------------------------------------------------------------------------

extension Amplifier {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties - with synchronization
    
    // listed in alphabetical order
    internal var _ant: String {
        get { return _amplifierQ.sync { __ant } }
        set { _amplifierQ.sync(flags: .barrier) {__ant = newValue } } }
    
    internal var _ip: String {
        get { return _amplifierQ.sync { __ip } }
        set { _amplifierQ.sync(flags: .barrier) {__ip = newValue } } }
    
    internal var _model: String {
        get { return _amplifierQ.sync { __model } }
        set { _amplifierQ.sync(flags: .barrier) {__model = newValue } } }
    
    internal var _port: Int {
        get { return _amplifierQ.sync { __port } }
        set { _amplifierQ.sync(flags: .barrier) {__port = newValue } } }
    
    internal var _serialNumber: String {
        get { return _amplifierQ.sync { __serialNumber } }
        set { _amplifierQ.sync(flags: .barrier) {__serialNumber = newValue } } }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (no message to Radio)
    
    // FIXME: Should any of these send a message to the Radio?
    //          If yes, implement it, if not should they be "get" only?
    
}
