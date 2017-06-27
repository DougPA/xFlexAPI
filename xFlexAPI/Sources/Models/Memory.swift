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
    // MARK: - fileprivate properties

    fileprivate var _memoryQ: DispatchQueue             // GCD queue that guards this object

    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    //                                                                                              //
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
    //                                                                                              //
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------

    fileprivate var _radio: Radio!                      // The Radio that owns this Memory
    fileprivate var _initialized = false                // True if initialized by Radio hardware
    
    // constants
    fileprivate let _log = Log.sharedInstance           // shared log
    fileprivate let kMinLevel = 0                       // control range
    fileprivate let kMaxLevel = 100
    
    // ------------------------------------------------------------------------------
    // MARK: - Initialization
    
    init(radio: Radio, memoryId: Radio.MemoryId, queue: DispatchQueue) {
        
        self._radio = radio
        self.id = memoryId
        self._memoryQ = queue
        
        super.init()
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - Public methods that send commands to the Radio (hardware)
    
    public func select() { _radio.send("memory apply \(id)") }
    
    // ------------------------------------------------------------------------------
    // MARK: - fileprivate methods
            
    /// Restrict the Filter High value
    ///
    /// - Parameter value:  the value
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
    /// - Parameter value:  the value
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
    /// - Parameter value:  a Tone Value
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
    public func parseKeyValues(_ keyValues: Radio.KeyValuesArray)  {
        
        // process each key/value pair, <key=value>
        for kv in keyValues {
            
            // Check for Unknown token
            guard let token = Token(rawValue: kv.key.lowercased()) else {
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
//              - Dynamic public properties
//              - Memory message enum
// --------------------------------------------------------------------------------

extension Memory {

    // ----------------------------------------------------------------------------
    // MARK: - fileprivate properties - with synchronization
    
    // listed in alphabetical order
    fileprivate var _digitalLowerOffset: Int {
        get { return _memoryQ.sync { __digitalLowerOffset } }
        set { _memoryQ.sync(flags: .barrier) { __digitalLowerOffset = newValue } } }
    
    fileprivate var _digitalUpperOffset: Int {
        get { return _memoryQ.sync { __digitalUpperOffset } }
        set { _memoryQ.sync(flags: .barrier) { __digitalUpperOffset = newValue } } }
    
    fileprivate var _filterHigh: Int {
        get { return _memoryQ.sync { __filterHigh } }
        set { _memoryQ.sync(flags: .barrier) { __filterHigh = newValue } } }
    
    fileprivate var _filterLow: Int {
        get { return _memoryQ.sync { __filterLow } }
        set { _memoryQ.sync(flags: .barrier) { __filterLow = newValue } } }
    
    fileprivate var _frequency: Int {
        get { return _memoryQ.sync { __frequency } }
        set { _memoryQ.sync(flags: .barrier) { __frequency = newValue } } }
    
    fileprivate var _group: String {
        get { return _memoryQ.sync { __group } }
        set { _memoryQ.sync(flags: .barrier) { __group = newValue } } }
    
    fileprivate var _mode: String {
        get { return _memoryQ.sync { __mode } }
        set { _memoryQ.sync(flags: .barrier) { __mode = newValue } } }
    
    fileprivate var _name: String {
        get { return _memoryQ.sync { __name } }
        set { _memoryQ.sync(flags: .barrier) { __name = newValue } } }
    
    fileprivate var _offset: Int {
        get { return _memoryQ.sync { __offset } }
        set { _memoryQ.sync(flags: .barrier) { __offset = newValue } } }
    
    fileprivate var _offsetDirection: String {
        get { return _memoryQ.sync { __offsetDirection } }
        set { _memoryQ.sync(flags: .barrier) { __offsetDirection = newValue } } }
    
    fileprivate var _owner: String {
        get { return _memoryQ.sync { __owner } }
        set { _memoryQ.sync(flags: .barrier) { __owner = newValue } } }
    
    fileprivate var _rfPower: Int {
        get { return _memoryQ.sync { __rfPower } }
        set { _memoryQ.sync(flags: .barrier) { __rfPower = newValue } } }
    
    fileprivate var _rttyMark: Int {
        get { return _memoryQ.sync { __rttyMark } }
        set { _memoryQ.sync(flags: .barrier) { __rttyMark = newValue } } }
    
    fileprivate var _rttyShift: Int {
        get { return _memoryQ.sync { __rttyShift } }
        set { _memoryQ.sync(flags: .barrier) { __rttyShift = newValue } } }
    
    fileprivate var _squelchEnabled: Bool {
        get { return _memoryQ.sync { __squelchEnabled } }
        set { _memoryQ.sync(flags: .barrier) { __squelchEnabled = newValue } } }
    
    fileprivate var _squelchLevel: Int {
        get { return _memoryQ.sync { __squelchLevel } }
        set { _memoryQ.sync(flags: .barrier) { __squelchLevel = newValue } } }
    
    fileprivate var _step: Int {
        get { return _memoryQ.sync { __step } }
        set { _memoryQ.sync(flags: .barrier) { __step = newValue } } }
    
    fileprivate var _toneMode: String {
        get { return _memoryQ.sync { __toneMode } }
        set { _memoryQ.sync(flags: .barrier) { __toneMode = newValue } } }
    
    fileprivate var _toneValue: Int {
        get { return _memoryQ.sync { __toneValue } }
        set { _memoryQ.sync(flags: .barrier) { __toneValue = newValue } } }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant with Radio update
    
    // listed in alphabetical order
    @objc dynamic public var digitalLowerOffset: Int {
        get { return _digitalLowerOffset }
        set { if _digitalLowerOffset != newValue { _digitalLowerOffset = newValue ; _radio.send("memory set \(id) digl_offset=\(newValue)") } } }
    
    @objc dynamic public var digitalUpperOffset: Int {
        get { return _digitalUpperOffset }
        set { if _digitalUpperOffset != newValue { _digitalUpperOffset = newValue ; _radio.send("memory set \(id) digu_offset=\(newValue)") } } }
    
    @objc dynamic public var filterHigh: Int {
        get { return _filterHigh }
        set { let value = filterHighLimits(newValue) ; if _filterHigh != value { _filterHigh = value ; _radio.send("memory set \(id) rx_filter_high=\(value)") } } }
    
    @objc dynamic public var filterLow: Int {
        get { return _filterLow }
        set { let value = filterLowLimits(newValue) ; if _filterLow != value { _filterLow = value ; _radio.send("memory set \(id) rx_filter_low=\(value)") } } }
    
    @objc dynamic public var frequency: Int {
        get { return _frequency }
        set { if _frequency != newValue { _frequency = newValue ; _radio.send("memory set \(id) freq=\(newValue)") } } }
    
    @objc dynamic public var group: String {
        get { return _group }
        set { let value = newValue.replacingSpacesWith("\u{007F}") ; if _group != value { _group = value ; _radio.send("memory set \(id) group=\(value)") } } }
    
    @objc dynamic public var mode: String {
        get { return _mode }
        set { if _mode != newValue { _mode = newValue ; _radio.send("memory set \(id) mode=\(newValue)") } } }
    
    @objc dynamic public var name: String {
        get { return _name }
        set { let value = newValue.replacingSpacesWith("\u{007F}") ; if _name != value { _name = newValue ; _radio.send("memory set \(id) name=\(value)") } } }
    
    @objc dynamic public var offset: Int {
        get { return _offset }
        set { if _offset != newValue { _offset = newValue ; _radio.send("memory set \(id) repeater_offset=\(newValue)") } } }
    
    @objc dynamic public var offsetDirection: String {
        get { return _offsetDirection }
        set { if _offsetDirection != newValue { _offsetDirection = newValue ; _radio.send("memory set \(id) repeater=" + newValue) } } }
    
    @objc dynamic public var owner: String {
        get { return _owner }
        set { let value = newValue.replacingSpacesWith("\u{007F}") ; if _owner != value { _owner = newValue ; _radio.send("memory set \(id) owner=\(value)") } } }
    
    @objc dynamic public var rfPower: Int {
        get { return _rfPower }
        set { if _rfPower != newValue && newValue.within(kMinLevel, kMaxLevel) { _rfPower = newValue ; _radio.send("memory set \(id) power=\(newValue)") } } }
    
    @objc dynamic public var rttyMark: Int {
        get { return _rttyMark }
        set { if _rttyMark != newValue { _rttyMark = newValue ; _radio.send("memory set \(id) rtty_mark=\(newValue)") } } }
    
    @objc dynamic public var rttyShift: Int {
        get { return _rttyShift }
        set { if _rttyShift != newValue { _rttyShift = newValue ; _radio.send("memory set \(id) rtty_shift=\(newValue)") } } }
    
    @objc dynamic public var squelchEnabled: Bool {
        get { return _squelchEnabled }
        set { if _squelchEnabled != newValue { _squelchEnabled = newValue ; _radio.send("memory set \(id) squelch=" + newValue.asNumber()) } } }
    
    @objc dynamic public var squelchLevel: Int {
        get { return _squelchLevel }
        set { if _squelchLevel != newValue && newValue.within(kMinLevel, kMaxLevel) { _squelchLevel = newValue ; _radio.send("memory set \(id) squelchLevel=\(newValue)") } } }
    
    @objc dynamic public var step: Int {
        get { return _step }
        set { if _step != newValue { _step = newValue ; _radio.send("memory set \(id) step=\(newValue)") } } }
    
    @objc dynamic public var toneMode: String {
        get { return _toneMode }
        set { if _toneMode != newValue { _toneMode = newValue ; _radio.send("memory set \(id) mode=" + newValue) } } }
    
    @objc dynamic public var toneValue: Int {
        get { return _toneValue }
        set { if _toneValue != newValue && toneValueValid(newValue) { _toneValue = newValue ; _radio.send("memory set \(id) tone_value=\(newValue)") } } }
    
    // ----------------------------------------------------------------------------
    // Mark: - Tokens for Memory messages (only populate values that != case value)
    
    enum Token : String {
        case digitalLowerOffset = "digl_offset"
        case digitalUpperOffset = "digu_offset"
        case frequency = "freq"
        case group
        case highlight
        case highlightColor = "highlight_color"
        case mode
        case name
        case owner
        case repeaterOffsetDirection = "repeater"
        case repeaterOffset = "repeater_offset"
        case rfPower = "power"
        case rttyMark = "rtty_mark"
        case rttyShift = "rtty_shift"
        case rxFilterHigh = "rx_filter_high"
        case rxFilterLow = "rx_filter_low"
        case step
        case squelchEnabled = "squelch"
        case squelchLevel = "squelch_level"
        case toneMode = "tone_mode"
        case toneValue = "tone_value"
    }
    
    // ----------------------------------------------------------------------------
    // Mark: - Other enums
    
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
