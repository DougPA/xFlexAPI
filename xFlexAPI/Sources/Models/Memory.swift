//
//  Memory.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 8/20/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Memory Class implementation
//
//      creates a Memory instance to be used by a Client to support the
//      processing of a Memory
//
// --------------------------------------------------------------------------------

public final class Memory : NSObject, KeyValueParser {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    public private(set) var id: String                  // Id that uniquely identifies this Memory
    
    // ------------------------------------------------------------------------------
    // MARK: - Internal properties
    
    internal var _radio: Radio!                         // The Radio that owns this Memory
    internal let kMinLevel = 0                          // control range
    internal let kMaxLevel = 100
    internal let kMemorySetCmd = "memory set "
    
    // ------------------------------------------------------------------------------
    // MARK: - Private properties

    fileprivate var _memoryQ: DispatchQueue             // GCD queue that guards this object
    fileprivate var _initialized = false                // True if initialized by Radio hardware
    fileprivate let _log = Log.sharedInstance           // shared log
    
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    //                                                                                                  //
    fileprivate var __digitalLowerOffset = 0            // Digital Lower Offset                         //
    fileprivate var __digitalUpperOffset = 0            // Digital Upper Offset                         //
    fileprivate var __filterHigh = 0                    // Filter high                                  //
    fileprivate var __filterLow = 0                     // Filter low                                   //
    fileprivate var __frequency = 0                     // Frequency (Hz)                               //
    fileprivate var __group = ""                        // Group                                        //
    fileprivate var __mode = ""                         // Mode                                         //
    fileprivate var __name = ""                         // Name                                         //
    fileprivate var __offset = 0                        // Offset (Hz)                                  //
    fileprivate var __offsetDirection = ""              // Offset direction                             //
    fileprivate var __owner = ""                        // Owner                                        //
    fileprivate var __rfPower = 0                       // Rf Power                                     //
    fileprivate var __rttyMark = 0                      // RTTY Mark                                    //
    fileprivate var __rttyShift = 0                     // RTTY Shift                                   //
    fileprivate var __squelchEnabled = false            // Squelch enabled                              //
    fileprivate var __squelchLevel = 0                  // Squelch level                                //
    fileprivate var __step = 0                          // Step (Hz)                                    //
    fileprivate var __toneMode = ""                     // Tone Mode                                    //
    fileprivate var __toneValue = 0                     // Tone values (Hz)                             //
    //                                                                                                  //
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------

    // ------------------------------------------------------------------------------
    // MARK: - Initialization
    
    init(radio: Radio, id: Radio.MemoryId, queue: DispatchQueue) {
        
        self._radio = radio
        self.id = id
        self._memoryQ = queue
        
        super.init()
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - Public methods that send commands to the Radio (hardware)
    
    public func select() { _radio.send("memory apply \(id)") }
    
    // ------------------------------------------------------------------------------
    // MARK: - Private methods
            
    /// Restrict the Filter High value
    ///
    /// - Parameters:
    ///   - value:          the value
    /// - Returns:          adjusted value
    ///
    func filterHighLimits(_ value: Int) -> Int {
        
        var newValue = (value < filterHigh + 10 ? filterHigh + 10 : value)
        
        if let modeType = Slice.Mode(rawValue: mode.lowercased()) {
            switch modeType {
                
            case .cw:
                newValue = (newValue > 12_000 - _radio!.cwPitch ? 12_000 - _radio!.cwPitch : newValue)
                
            case .rtty:
                newValue = (newValue > 4_000 ? 4_000 : newValue)
                
            case .dsb, .am, .sam, .fm, .nfm, .dfm, .dstr:
                newValue = (newValue > 12_000 ? 12_000 : newValue)
                newValue = (newValue < 10 ? 10 : newValue)
                
            case .lsb, .digl:
                newValue = (newValue > 0 ? 0 : newValue)
                
            case .usb, .digu, .fdv:
                newValue = (newValue > 12_000 ? 12_000 : newValue)
            }
        }
        return newValue
    }
    /// Restrict the Filter Low value
    ///
    /// - Parameters:
    ///   - value:          the value
    /// - Returns:          adjusted value
    ///
    func filterLowLimits(_ value: Int) -> Int {
        
        var newValue = (value > filterHigh - 10 ? filterHigh - 10 : value)
        
        if let modeType = Slice.Mode(rawValue: mode.lowercased()) {
            switch modeType {
                
            case .cw:
                newValue = (newValue < -12_000 - _radio!.cwPitch ? -12_000 - _radio!.cwPitch : newValue)
                
            case .rtty:
                newValue = (newValue < -12_000 ? -12_000 : newValue)
                
            case .dsb, .am, .sam, .fm, .nfm, .dfm, .dstr:
                newValue = (newValue < -12_000 ? -12_000 : newValue)
                newValue = (newValue > -10 ? -10 : newValue)
                
            case .lsb, .digl:
                newValue = (newValue < -12_000 ? -12_000 : newValue)
                
            case .usb, .digu, .fdv:
                newValue = (newValue < 0 ? 0 : newValue)
            }
        }
        return newValue
    }
    /// Validate the Tone Value
    ///
    /// - Parameters:
    ///   - value:          a Tone Value
    /// - Returns:          true = Valid
    ///
    func toneValueValid( _ value: Int) -> Bool {
        
        return toneMode == ToneMode.ctcssTx.rawValue && toneValue.within(0, 301)
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - KeyValueParser protocol methods
    
    //
    // Parse Memory key/value pairs
    //     called by Radio, executes on the parseQ
    //
    func parseKeyValues(_ keyValues: Radio.KeyValuesArray)  {
        
        // process each key/value pair, <key=value>
        for kv in keyValues {
            
            // Check for Unknown token
            guard let token = MemoryToken(rawValue: kv.key.lowercased()) else {
                // unknown token, log it and ignore the token
                _log.msg("Unknown token - \(kv.key)", level: .debug, function: #function, file: #file, line: #line)
                continue
            }
            
            // get the String, Integer & Double versions of the value
            // "fix" the String version
            let sValue = kv.value.replacingSpacesWith("\u{007F}")
            let iValue = kv.value.iValue()
            let bValue = kv.value.bValue()
            
            // Known tokens, in alphabetical order
            switch (token) {

            case .digitalLowerOffset:
                willChangeValue(forKey: "digitalLowerOffset")
                _digitalLowerOffset = iValue
                didChangeValue(forKey: "digitalLowerOffset")
            
            case .digitalUpperOffset:
                willChangeValue(forKey: "digitalUpperOffset")
                _digitalUpperOffset = iValue
                didChangeValue(forKey: "digitalUpperOffset")
                
            case .frequency:
                willChangeValue(forKey: "frequency")
                _frequency = kv.value.mhzToHz()
                didChangeValue(forKey: "frequency")
            
            case .group:
                willChangeValue(forKey: "group")
                _group = sValue
                didChangeValue(forKey: "group")
            
            case .highlight:            // not implemented
                break
            
            case .highlightColor:       // not implemented
                break
            
            case .mode:
                willChangeValue(forKey: "mode")
                _mode = sValue
                didChangeValue(forKey: "mode")
            
            case .name:
                willChangeValue(forKey: "name")
                _name = sValue
                didChangeValue(forKey: "name")
            
            case .owner:
                willChangeValue(forKey: "owner")
                _owner = sValue
                didChangeValue(forKey: "owner")
            
            case .repeaterOffsetDirection:
                willChangeValue(forKey: "offsetDirection")
                _offsetDirection = kv.value.lowercased()
                didChangeValue(forKey: "offsetDirection")
            
            case .repeaterOffset:
                willChangeValue(forKey: "offset")
                _offset = iValue
                didChangeValue(forKey: "offset")
            
            case .rfPower:
                willChangeValue(forKey: "rfPower")
                _rfPower = iValue
                didChangeValue(forKey: "rfPower")
            
            case .rttyMark:
                willChangeValue(forKey: "rttyMark")
                _rttyMark = iValue
                didChangeValue(forKey: "rttyMark")
            
            case .rttyShift:
                willChangeValue(forKey: "rttyShift")
                _rttyShift = iValue
                didChangeValue(forKey: "rttyShift")
                
           case .rxFilterHigh:
                willChangeValue(forKey: "filterHigh")
                _filterHigh = filterHighLimits(iValue)
                didChangeValue(forKey: "filterHigh")
            
            case .rxFilterLow:
                willChangeValue(forKey: "filterLow")
                _filterLow = filterLowLimits(iValue)
                didChangeValue(forKey: "filterLow")
            
            case .squelchEnabled:
                willChangeValue(forKey: "squelchEnabled")
                _squelchEnabled = bValue
                didChangeValue(forKey: "squelchEnabled")
            
            case .squelchLevel:
                willChangeValue(forKey: "squelchLevel")
                _squelchLevel = iValue
                didChangeValue(forKey: "squelchLevel")
            
            case .step:
                willChangeValue(forKey: "step")
                _step = iValue
                didChangeValue(forKey: "step")
            
            case .toneMode:
                willChangeValue(forKey: "toneMode")
                _toneMode = kv.value.lowercased()
                didChangeValue(forKey: "toneMode")
            
            case .toneValue:
                willChangeValue(forKey: "toneValue")
                _toneValue = iValue
                didChangeValue(forKey: "toneValue")
            }
        }
        // is the Memory initialized?
        if !_initialized  {
            
            // YES, the Radio (hardware) has acknowledged this Memory
            _initialized = true
            
            // notify all observers
            NC.post(.memoryHasBeenAdded, object: self as Any?)
        }
    }
}

// --------------------------------------------------------------------------------
// MARK: - Memory Class extensions
//              - Synchronized internal properties
//              - Public properties, no message to Radio
// --------------------------------------------------------------------------------

extension Memory {

    // ----------------------------------------------------------------------------
    // MARK: - Internal properties - with synchronization
    
    // listed in alphabetical order
    internal var _digitalLowerOffset: Int {
        get { return _memoryQ.sync { __digitalLowerOffset } }
        set { _memoryQ.sync(flags: .barrier) { __digitalLowerOffset = newValue } } }
    
    internal var _digitalUpperOffset: Int {
        get { return _memoryQ.sync { __digitalUpperOffset } }
        set { _memoryQ.sync(flags: .barrier) { __digitalUpperOffset = newValue } } }
    
    internal var _filterHigh: Int {
        get { return _memoryQ.sync { __filterHigh } }
        set { _memoryQ.sync(flags: .barrier) { __filterHigh = newValue } } }
    
    internal var _filterLow: Int {
        get { return _memoryQ.sync { __filterLow } }
        set { _memoryQ.sync(flags: .barrier) { __filterLow = newValue } } }
    
    internal var _frequency: Int {
        get { return _memoryQ.sync { __frequency } }
        set { _memoryQ.sync(flags: .barrier) { __frequency = newValue } } }
    
    internal var _group: String {
        get { return _memoryQ.sync { __group } }
        set { _memoryQ.sync(flags: .barrier) { __group = newValue } } }
    
    internal var _mode: String {
        get { return _memoryQ.sync { __mode } }
        set { _memoryQ.sync(flags: .barrier) { __mode = newValue } } }
    
    internal var _name: String {
        get { return _memoryQ.sync { __name } }
        set { _memoryQ.sync(flags: .barrier) { __name = newValue } } }
    
    internal var _offset: Int {
        get { return _memoryQ.sync { __offset } }
        set { _memoryQ.sync(flags: .barrier) { __offset = newValue } } }
    
    internal var _offsetDirection: String {
        get { return _memoryQ.sync { __offsetDirection } }
        set { _memoryQ.sync(flags: .barrier) { __offsetDirection = newValue } } }
    
    internal var _owner: String {
        get { return _memoryQ.sync { __owner } }
        set { _memoryQ.sync(flags: .barrier) { __owner = newValue } } }
    
    internal var _rfPower: Int {
        get { return _memoryQ.sync { __rfPower } }
        set { _memoryQ.sync(flags: .barrier) { __rfPower = newValue } } }
    
    internal var _rttyMark: Int {
        get { return _memoryQ.sync { __rttyMark } }
        set { _memoryQ.sync(flags: .barrier) { __rttyMark = newValue } } }
    
    internal var _rttyShift: Int {
        get { return _memoryQ.sync { __rttyShift } }
        set { _memoryQ.sync(flags: .barrier) { __rttyShift = newValue } } }
    
    internal var _squelchEnabled: Bool {
        get { return _memoryQ.sync { __squelchEnabled } }
        set { _memoryQ.sync(flags: .barrier) { __squelchEnabled = newValue } } }
    
    internal var _squelchLevel: Int {
        get { return _memoryQ.sync { __squelchLevel } }
        set { _memoryQ.sync(flags: .barrier) { __squelchLevel = newValue } } }
    
    internal var _step: Int {
        get { return _memoryQ.sync { __step } }
        set { _memoryQ.sync(flags: .barrier) { __step = newValue } } }
    
    internal var _toneMode: String {
        get { return _memoryQ.sync { __toneMode } }
        set { _memoryQ.sync(flags: .barrier) { __toneMode = newValue } } }
    
    internal var _toneValue: Int {
        get { return _memoryQ.sync { __toneValue } }
        set { _memoryQ.sync(flags: .barrier) { __toneValue = newValue } } }
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (no message to Radio)
    
        // ----- None -----
    
    // ----------------------------------------------------------------------------
    // Mark: - Memory related enums
    
    public enum TXOffsetDirection : String {            // Tx offset types
        case down
        case simplex
        case up
    }
    
    public enum ToneMode : String {                     // Tone modes
        case ctcssTx = "ctcss_tx"
        case off
    }

}
