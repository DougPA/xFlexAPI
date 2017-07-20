//
//  Equalizer.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 5/31/15.
//  Copyright (c) 2015 Douglas Adams, K3TZR
//

import Foundation

// ------------------------------------------------------------------------------
// MARK: - Equalizer Class implementation
//
//      creates an Equalizer instance to be used by a Client to support the
//      rendering of an Equalizer
//
//      Note: ignores the non-"sc" version of Equalizer messages
//            The "sc" version is the standard for API Version 1.4 and greater
//
// ------------------------------------------------------------------------------

public final class Equalizer : NSObject, KeyValueParser {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    public private(set) var eqType: Radio.EqualizerType!    // Type that uniquely identifies this Equalizer
    
    // ------------------------------------------------------------------------------
    // MARK: - Internal properties
    
    internal var _radio:  Radio?                            // The Radio that owns this Equalizer
    internal let kEqCmd = "eq "                             // Equalizer command prefix
    
    // ------------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _eqQ: DispatchQueue                     // GCD queue that guards this object
    fileprivate let _log = Log.sharedInstance               // shared log
    
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    //                                                                                                  //
    fileprivate var __eqEnabled = false                                                                 //
    fileprivate var __level63Hz = 0                                                                     //
    fileprivate var __level125Hz = 0                                                                    //
    fileprivate var __level250Hz = 0                                                                    //
    fileprivate var __level500Hz = 0                                                                    //
    fileprivate var __level1000Hz = 0                                                                   //
    fileprivate var __level2000Hz = 0                                                                   //
    fileprivate var __level4000Hz = 0                                                                   //
    fileprivate var __level8000Hz = 0                                                                   //
    //                                                                                                  //
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    
    // ------------------------------------------------------------------------------
    // MARK: - Initialization
    
    /// Initialize an Equalizer
    ///
    /// - Parameters:
    ///   - radio:      the parent Radio class
    ///   - eqType:     the Equalizer type (rxsc or txsc)
    ///   - queue:      Equalizer Concurrent queue
    ///
    init( radio: Radio,  eqType: Radio.EqualizerType, queue: DispatchQueue) {
        
        self._radio = radio
        self.eqType = eqType
        
        self._eqQ = queue

        super.init()
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - KeyValueParser Protocol methods
    //      called by Radio, executes on the parseQ
    
    /// Parse Equalizer key/value pairs
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///
    func parseKeyValues(_ keyValues: Radio.KeyValuesArray) {
        
        // process each key/value pair, <key=value>
        for kv in keyValues {
            
            // check for unknown Keys
            guard let token = EqualizerToken(rawValue: kv.key.lowercased()) else {
                
                // unknown Key, log it and ignore the Key
                _log.msg("Unknown token - \(kv.key)", level: .debug, function: #function, file: #file, line: #line)
                continue
            }
            // get the Integer & Bool versions of the value
            let iValue = (kv.value).iValue()
            let bValue = (kv.value).bValue()
            
            // known Keys, in alphabetical order
            switch token {
                
            case .level63Hz:
                willChangeValue(forKey: "level63Hz")
                _level63Hz = iValue
                didChangeValue(forKey: "level63Hz")
            
            case .level125Hz:
                willChangeValue(forKey: "level125Hz")
                _level125Hz = iValue
                didChangeValue(forKey: "level125Hz")
            
            case .level250Hz:
                willChangeValue(forKey: "level250Hz")
                _level250Hz = iValue
                didChangeValue(forKey: "level250Hz")
            
            case .level500Hz:
                willChangeValue(forKey:  "level500Hz")
                _level500Hz = iValue
                didChangeValue(forKey:  "level500Hz")
            
            case .level1000Hz:
                willChangeValue(forKey: "level1000Hz")
                _level1000Hz = iValue
                didChangeValue(forKey: "level1000Hz")
            
            case .level2000Hz:
                willChangeValue(forKey: "level2000Hz")
                _level2000Hz = iValue
                didChangeValue(forKey: "level2000Hz")
            
            case .level4000Hz:
                willChangeValue(forKey: "level4000Hz")
                _level4000Hz = iValue
                didChangeValue(forKey: "level4000Hz")
            
            case .level8000Hz:
                willChangeValue(forKey: "level8000Hz")
                _level8000Hz = iValue
                didChangeValue(forKey: "level8000Hz")
            
            case .enabled:
                willChangeValue(forKey: "eqEnabled")
                _eqEnabled = bValue
                didChangeValue(forKey: "eqEnabled")
            }
        }
    }
}

// --------------------------------------------------------------------------------
// MARK: - Equalizer Class extensions
//              - Synchronized internal properties
//              - Public properties, no message to Radio
// --------------------------------------------------------------------------------

extension Equalizer {

    // ----------------------------------------------------------------------------
    // MARK: - Internal properties - with synchronization
    
    internal var _eqEnabled: Bool {
        get { return _eqQ.sync { __eqEnabled } }
        set { _eqQ.sync(flags: .barrier) { __eqEnabled = newValue } } }
    
    internal var _level63Hz: Int {
        get { return _eqQ.sync { __level63Hz } }
        set { _eqQ.sync(flags: .barrier) { __level63Hz = newValue } } }
    
    internal var _level125Hz: Int {
        get { return _eqQ.sync { __level125Hz } }
        set { _eqQ.sync(flags: .barrier) { __level125Hz = newValue } } }
    
    internal var _level250Hz: Int {
        get { return _eqQ.sync { __level250Hz } }
        set { _eqQ.sync(flags: .barrier) { __level250Hz = newValue } } }
    
    internal var _level500Hz: Int {
        get { return _eqQ.sync { __level500Hz } }
        set { _eqQ.sync(flags: .barrier) { __level500Hz = newValue } } }
    
    internal var _level1000Hz: Int {
        get { return _eqQ.sync { __level1000Hz } }
        set { _eqQ.sync(flags: .barrier) { __level1000Hz = newValue } } }
    
    internal var _level2000Hz: Int {
        get { return _eqQ.sync { __level2000Hz } }
        set { _eqQ.sync(flags: .barrier) { __level2000Hz = newValue } } }
    
    internal var _level4000Hz: Int {
        get { return _eqQ.sync { __level4000Hz } }
        set { _eqQ.sync(flags: .barrier) { __level4000Hz = newValue } } }
    
    internal var _level8000Hz: Int {
        get { return _eqQ.sync { __level8000Hz } }
        set { _eqQ.sync(flags: .barrier) { __level8000Hz = newValue } } }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (no message to Radio)
    
        // ----- None -----
    
}
