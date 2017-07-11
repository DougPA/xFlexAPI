//
//  Xvtr.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 6/24/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Xvtr Class implementation
//
//      creates an Xvtr instance to be used by a Client to support the
//      processing of an Xvtr
//
// --------------------------------------------------------------------------------

public final class Xvtr : NSObject, KeyValueParser {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    public private(set) var id: String = ""                 // Id that uniquely identifies this Xvtr
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private var _initialized = false                    // True if initialized by Radio hardware
    private var _radio: Radio?                          // The Radio that owns this Xvtr
    private var _xvtrQ: DispatchQueue                   // GCD queue that guards this object
    
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    //                                                                                              //
    private var __name = ""                             // Xvtr Name                                //
    private var __ifFrequency = 0                       // If Frequency                             //
    private var __inUse = false                         //                                          //
    private var __isValid = false                       //                                          //
    private var __loError = 0                           //                                          //
    private var __maxPower = 0                          //                                          //
    private var __order = 0                             //                                          //
    private var __preferred = false                     //                                          //
    private var __rfFrequency = 0                       //                                          //
    private var __rxGain = 0                            //                                          //
    private var __rxOnly = false                        //                                          //
    private var __twoMeterInt = 0                       //                                          //
    //                                                                                              //
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    
    // constants
    private let _log = Log.sharedInstance               // shared log
    fileprivate let kXvtrCommand = "xvtr "              // Xvtr command prefix
    
    // ------------------------------------------------------------------------------
    // MARK: - Initialization
    
    /// Initialize an Xvtr
    ///
    /// - Parameters:
    ///   - id:         an Xvtr Id
    ///   - radio:      parent Radio class
    ///   - queue:      Xvtr Concurrent queue
    ///
    public init(radio: Radio, id: String, queue: DispatchQueue) {
        
        self._radio = radio
        self.id = id
        self._xvtrQ = queue
        
        super.init()
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - KeyValueParser Protocol methods
    //     called by Radio, executes on the parseQ
    
    /// Parse Xvtr key/value pairs
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///
    public func parseKeyValues(_ keyValues: Radio.KeyValuesArray) {
        
        // process each key/value pair, <key=value>
        for kv in keyValues {
            
            // check for unknown keys
            guard let token = XvtrToken(rawValue: kv.key.lowercased()) else {
                
                // unknown Key, log it and ignore the Key
                _log.msg("Unknown token - \(kv.key)", level: .debug, function: #function, file: #file, line: #line)
                continue
            }
            // get the Integer and Bool version of the value
            let iValue = (kv.value).iValue()
            let bValue = kv.value.bValue()
            
            // Known keys, in alphabetical order
            switch token {
                
            case .name:
                willChangeValue(forKey: "name")
                _name = kv.value
                didChangeValue(forKey: "name")
                
            case .ifFrequency:
                willChangeValue(forKey: "ifFrequency")
                _ifFrequency = iValue
                didChangeValue(forKey: "ifFrequency")
                
            case .inUse:
                willChangeValue(forKey: "inUse")
                _inUse = bValue
                didChangeValue(forKey: "inUse")
                
            case .isValid:
                willChangeValue(forKey: "isValid")
                _isValid = bValue
                didChangeValue(forKey: "isValid")
                
            case .loError:
                willChangeValue(forKey: "loError")
                _loError = iValue
                didChangeValue(forKey: "loError")
                
            case .maxPower:
                willChangeValue(forKey: "maxPower")
                _maxPower = iValue
                didChangeValue(forKey: "maxPower")
                
            case .order:
                willChangeValue(forKey: "order")
                _order = iValue
                didChangeValue(forKey: "order")
                
            case .preferred:
                willChangeValue(forKey: "preferred")
                _preferred = bValue
                didChangeValue(forKey: "preferred")
                
            case .rfFrequency:
                willChangeValue(forKey: "rfFrequency")
                _rfFrequency = iValue
                didChangeValue(forKey: "rfFrequency")
                
            case .rxGain:
                willChangeValue(forKey: "rxGain")
                _rxGain = iValue
                didChangeValue(forKey: "rxGain")
                
            case .rxOnly:
                willChangeValue(forKey: "rxOnly")
                _rxOnly = bValue
                didChangeValue(forKey: "rxOnly")
                
            case .twoMeterInt:
                willChangeValue(forKey: "twoMeterInt")
                _twoMeterInt = iValue
                didChangeValue(forKey: "twoMeterInt")
            }
        }
        // is the waterfall initialized?
        if !_initialized && _inUse {
            
            // YES, the Radio (hardware) has acknowledged this Waterfall
            _initialized = true
            
            // notify all observers
            NC.post(.xvtrHasBeenAdded, object: self as Any?)
        }
    }
}

// --------------------------------------------------------------------------------
// MARK: - Xvtr Class extensions
//              - Synchronized internal properties
//              - Dynamic public properties
//              - Xvtr message enum
// --------------------------------------------------------------------------------

extension Xvtr {
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties - with synchronization
    
    // listed in alphabetical order
    private var _ifFrequency: Int {
        get { return _xvtrQ.sync { __ifFrequency } }
        set { _xvtrQ.sync(flags: .barrier) {__ifFrequency = newValue } } }
    
    private var _inUse: Bool {
        get { return _xvtrQ.sync { __inUse } }
        set { _xvtrQ.sync(flags: .barrier) {__inUse = newValue } } }
    
    private var _isValid: Bool {
        get { return _xvtrQ.sync { __isValid } }
        set { _xvtrQ.sync(flags: .barrier) {__isValid = newValue } } }
    
    private var _loError: Int {
        get { return _xvtrQ.sync { __loError } }
        set { _xvtrQ.sync(flags: .barrier) {__loError = newValue } } }
    
    private var _name: String {
        get { return _xvtrQ.sync { __name } }
        set { _xvtrQ.sync(flags: .barrier) {__name = newValue } } }
    
    private var _maxPower: Int {
        get { return _xvtrQ.sync { __maxPower } }
        set { _xvtrQ.sync(flags: .barrier) {__maxPower = newValue } } }
    
    private var _order: Int {
        get { return _xvtrQ.sync { __order } }
        set { _xvtrQ.sync(flags: .barrier) {__order = newValue } } }
    
    private var _preferred: Bool {
        get { return _xvtrQ.sync { __preferred } }
        set { _xvtrQ.sync(flags: .barrier) {__preferred = newValue } } }
    
    private var _rfFrequency: Int {
        get { return _xvtrQ.sync { __rfFrequency } }
        set { _xvtrQ.sync(flags: .barrier) {__rfFrequency = newValue } } }
    
    private var _rxGain: Int {
        get { return _xvtrQ.sync { __rxGain } }
        set { _xvtrQ.sync(flags: .barrier) {__rxGain = newValue } } }
    
    private var _rxOnly: Bool {
        get { return _xvtrQ.sync { __rxOnly } }
        set { _xvtrQ.sync(flags: .barrier) {__rxOnly = newValue } } }
    
    private var _twoMeterInt: Int {
        get { return _xvtrQ.sync { __twoMeterInt } }
        set { _xvtrQ.sync(flags: .barrier) {__twoMeterInt = newValue } } }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (with message sent to Radio)
    
    // listed in alphabetical order
    @objc dynamic public var ifFrequency: Int {
        get { return _ifFrequency }
        set { if _ifFrequency != newValue { _ifFrequency = newValue ; _radio!.send(kXvtrCommand + "\(id) " + XvtrToken.ifFrequency.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var loError: Int {
        get { return _loError }
        set { if _loError != newValue { _loError = newValue ; _radio!.send(kXvtrCommand + "\(id) " + XvtrToken.loError.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var name: String {
        get { return _name }
        set { if _name != newValue { _name = newValue ; _radio!.send(kXvtrCommand + "\(id) " + XvtrToken.name.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var maxPower: Int {
        get { return _maxPower }
        set { if _maxPower != newValue { _maxPower = newValue ; _radio!.send(kXvtrCommand + "\(id) " + XvtrToken.maxPower.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var order: Int {
        get { return _order }
        set { if _order != newValue { _order = newValue ; _radio!.send(kXvtrCommand + "\(id) " + XvtrToken.order.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var preferred: Bool {
        get { return _preferred }
        set { if _preferred != newValue { _preferred = newValue ; _radio!.send(kXvtrCommand + "\(id) " + XvtrToken.preferred.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var rfFrequency: Int {
        get { return _rfFrequency }
        set { if _rfFrequency != newValue { _rfFrequency = newValue ; _radio!.send(kXvtrCommand + "\(id) " + XvtrToken.rfFrequency.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var rxGain: Int {
        get { return _rxGain }
        set { if _rxGain != newValue { _rxGain = newValue ; _radio!.send(kXvtrCommand + "\(id) " + XvtrToken.rxGain.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var rxOnly: Bool {
        get { return _rxOnly }
        set { if _rxOnly != newValue { _rxOnly = newValue ; _radio!.send(kXvtrCommand + "\(id) " + XvtrToken.rxOnly.rawValue + "=\(newValue)") } } }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (no message to Radio)
    
    // FIXME: Should any of these send a message to the Radio?
    //          If yes, implement it, if not should they be "get" only?
    
    // listed in alphabetical order
    @objc dynamic public var inUse: Bool {
        return _inUse }
    
    @objc dynamic public var isValid: Bool {
        return _isValid }
    
    @objc dynamic public var twoMeterInt: Int {
        return _twoMeterInt }
    
    
    // ----------------------------------------------------------------------------
    // Mark: - Tokens for Waterfall messages (only populate values that != case value)
    
    internal enum XvtrToken : String {
        case name
        case ifFrequency = "if_freq"
        case inUse = "in_use"
        case isValid = "is_valid"
        case loError = "lo_error"
        case maxPower = "max_power"
        case order
        case preferred
        case rfFrequency = "rf_freq"
        case rxGain = "rx_gain"
        case rxOnly = "rx_only"
        case twoMeterInt = "two_meter_int"
    }
    
}
