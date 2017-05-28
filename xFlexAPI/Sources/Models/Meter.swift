//
//  Meter.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 6/2/15.
//  Copyright (c) 2015 Douglas Adams, K3TZR
//

import Foundation

// ----------------------------------------------------------------------------------
// MARK: - Meter Class implementation
// ----------------------------------------------------------------------------------

public class Meter : KeyValueParser {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    public private(set) var id = ""                                 // Id that uniquely identifies this Meter

    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate weak var _radio: Radio?                              // The Radio that owns this Meter
    fileprivate var _initialized = false                             // True if initialized by Radio (hardware)
    fileprivate var _meterQ: DispatchQueue                           // GCD queue that guards this object

    // constants
    fileprivate let _log = Log.sharedInstance                        // shared log
    fileprivate let kModule = "Meter"                                // Module Name reported in log messages

    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    //                                                                                              //
    fileprivate var _description = ""                                // long description            //
    fileprivate var _fps = 0                                         // frames per second           //
    fileprivate var _high: Float = 0.0                               // high limit                  //
    fileprivate var _low: Float = 0.0                                // low limit                   //
    fileprivate var _number = ""                                     // Id of the source            //
    fileprivate var _name = ""                                       // abbreviated description     //
    fileprivate var _peak: Float = 0.0                               // peak value                  //
    fileprivate var _source = ""                                     // source                      //
    fileprivate var _units = ""                                      // value units                 //
    fileprivate var _value: Float = 0.0                              // value                       //
    //                                                                                              //
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------

    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    /// Initialize a Meter
    ///
    /// - Parameters:
    ///   - radio:      the parent Radio class
    ///   - id:         a Meter Id
    ///   - queue:      Meter Concurrent queue
    ///
    public init(radio: Radio, id: Radio.MeterId, queue: DispatchQueue) {
        
        self._radio = radio
        self.id = id
        
        self._meterQ = queue
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    /// Update meter readings, called by UdpManager, executes on the udpQ
    ///
    /// - parameter newValue: the new value for the Meter
    ///
    func update(_ newValue: Int16) {
        let oldValue = value
        
        switch units {

        case "Volts", "Amps":
            value = Float(newValue) / 1024.0
        
        case "SWR", "dBm", "dBFS":
            value = Float(newValue) / 128.0
        
        case "degC":
            value = Float(newValue) / 64.0
        
        default:
            break
        }
        // did it change?
        if oldValue != value {
            // notify all observers
            NC.post(.meterUpdated, object: self as Any?)
        }
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - KeyValueParser Protocol methods
    //      called by Radio, executes on the parseQ (serial)
    
    //
    /// Parse Meter key/value pairs
    ///
    /// - parameter keyValues: a KeyValuesArray
    ///
    public func parseKeyValues(_ keyValues: Radio.KeyValuesArray) {
        
        // process each key/value pair, <n.key=value>
        for kv in keyValues {
            
            // separate the Meter Number from the Key
            let numberAndKey = kv.key.components(separatedBy: ".")
            
            // get the Key
            let key = numberAndKey[1]
            
            // make Int and Float versions of the Value
            let iValue = (kv.value).iValue()
            let fValue = (kv.value).fValue()
            
            // set the Meter Number
            id = numberAndKey[0] 
            
            // check for unknown Keys
            guard let token = Token(rawValue: key.lowercased()) else {
                
                // unknown Key, log it and ignore the Key
                _log.entry(" - \(key)", level: .token, source: kModule)
                continue
            }
            
            // known Keys, in alphabetical order
            switch token {

            case .desc:
                description = kv.value
            
            case .fps:
                fps = iValue
            
            case .high:
                high = fValue
            
            case .low:
                low = fValue
            
            case .name:
                name = kv.value
            
            case .number:
                number = kv.value
                
            case .source:               // COD-, TX-, RAD, SLC
                source = kv.value
                
            case .units:
                units = kv.value
            }
        }        
        if !_initialized {
            
            // the Radio (hardware) has acknowledged this Meter
            _initialized = true
            
            // notify all observers
            NC.post(.meterInitialized, object: self as Any?)
        }
    }
    
}

// --------------------------------------------------------------------------------
// MARK: - Meter Class extensions
//              - Synchronized dynamic public properties
//              - Meter message enum
//              - Other Meter related enums
// --------------------------------------------------------------------------------

extension Meter {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant Setters / Getters with synchronization
    
    // listed in alphabetical order
    dynamic public var description: String {
        get { return _meterQ.sync { _description } }
        set { _meterQ.sync(flags: .barrier) { _description = newValue } } }
    
    dynamic public var fps: Int {
        get { return _meterQ.sync { _fps } }
        set { _meterQ.sync(flags: .barrier) { _fps = newValue } } }
    
    dynamic public var high: Float {
        get { return _meterQ.sync { _high } }
        set { _meterQ.sync(flags: .barrier) { _high = newValue } } }
    
    dynamic public var low: Float {
        get { return _meterQ.sync { _low } }
        set { _meterQ.sync(flags: .barrier) { _low = newValue } } }
    
    dynamic public var name: String {
        get { return _meterQ.sync { _name } }
        set { _meterQ.sync(flags: .barrier) { _name = newValue } } }
    
    dynamic public var number: String {
        get { return _meterQ.sync { _number } }
        set { _meterQ.sync(flags: .barrier) { _number = newValue } } }
    
    dynamic public var peak: Float {
        get { return _meterQ.sync { _peak } }
        set { _meterQ.sync(flags: .barrier) { _peak = newValue } } }
    
    dynamic public var source: String {
        get { return _meterQ.sync { _source } }
        set { _meterQ.sync(flags: .barrier) { _source = newValue } } }
    
    dynamic public var units: String {
        get { return _meterQ.sync { _units } }
        set { _meterQ.sync(flags: .barrier) { _units = newValue } } }
    
    dynamic public var value: Float {
        get { return _meterQ.sync { _value } }
        set { _meterQ.sync(flags: .barrier) { _value = newValue } } }
    
    // ----------------------------------------------------------------------------
    // Mark: - Tokens for Meter messages (only populate values that != case value)
    
    internal enum Token : String {
        case desc
        case fps
        case high = "hi"
        case low
        case name = "nam"
        case number = "num"
        case source = "src"
        case units = "unit"
    }
    
    // ----------------------------------------------------------------------------
    // Mark: - Other Meter related enums
    
        public enum MeterSource: String {
            case none = ""
            case codec = "cod"
            case tx
            case slice = "slc"
            case radio = "rad"
        }
    
        public enum MeterUnits : Int {
            case none = 0
            case dbm
            case dbfs
            case swr
            case volts
            case amps
            case degrees
        }
    
    
}
