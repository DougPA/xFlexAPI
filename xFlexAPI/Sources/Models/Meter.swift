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
//
//      creates a Meter instance to be used by a Client to support the
//      rendering of a Meter
//
// ----------------------------------------------------------------------------------

public class Meter : KeyValueParser {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    public private(set) var id = ""                              // Id that uniquely identifies this Meter

    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private var _radio: Radio?                                   // The Radio that owns this Meter
    private var _initialized = false                             // True if initialized by Radio (hardware)
    private var _meterQ: DispatchQueue                           // GCD queue that guards this object

    // constants
    private let _log = Log.sharedInstance                        // shared log

    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    //                                                                                              //
    private var _description = ""                                // long description                //
    private var _fps = 0                                         // frames per second               //
    private var _high: Float = 0.0                               // high limit                      //
    private var _low: Float = 0.0                                // low limit                       //
    private var _number = ""                                     // Id of the source                //
    private var _name = ""                                       // abbreviated description         //
    private var _peak: Float = 0.0                               // peak value                      //
    private var _source = ""                                     // source                          //
    private var _units = ""                                      // value units                     //
    private var _value: Float = 0.0                              // value                           //
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
    
    /// Update meter readings, called by UdpManager, executes on the udpReceiveQ
    ///
    /// - Parameters:
    ///   - newValue:   the new value for the Meter
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
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
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
            guard let token = MeterToken(rawValue: key.lowercased()) else {
                
                // unknown Key, log it and ignore the Key
                _log.msg("Unknown token - \(kv.key)", level: .debug, function: #function, file: #file, line: #line)
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
            NC.post(.meterHasBeenAdded, object: self as Any?)
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
    // MARK: - Public properties - KVO compliant (with message sent to Radio)
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (no message to Radio)
    
    // FIXME: Should any of these send a message to the Radio?
    //          If yes, implement it, if not should they be "get" only?
    
    // listed in alphabetical order
    @objc dynamic public var description: String {
        get { return _meterQ.sync { _description } }
        set { _meterQ.sync(flags: .barrier) { _description = newValue } } }
    
    @objc dynamic public var fps: Int {
        get { return _meterQ.sync { _fps } }
        set { _meterQ.sync(flags: .barrier) { _fps = newValue } } }
    
    @objc dynamic public var high: Float {
        get { return _meterQ.sync { _high } }
        set { _meterQ.sync(flags: .barrier) { _high = newValue } } }
    
    @objc dynamic public var low: Float {
        get { return _meterQ.sync { _low } }
        set { _meterQ.sync(flags: .barrier) { _low = newValue } } }
    
    @objc dynamic public var name: String {
        get { return _meterQ.sync { _name } }
        set { _meterQ.sync(flags: .barrier) { _name = newValue } } }
    
    @objc dynamic public var number: String {
        get { return _meterQ.sync { _number } }
        set { _meterQ.sync(flags: .barrier) { _number = newValue } } }
    
    @objc dynamic public var peak: Float {
        get { return _meterQ.sync { _peak } }
        set { _meterQ.sync(flags: .barrier) { _peak = newValue } } }
    
    @objc dynamic public var source: String {
        get { return _meterQ.sync { _source } }
        set { _meterQ.sync(flags: .barrier) { _source = newValue } } }
    
    @objc dynamic public var units: String {
        get { return _meterQ.sync { _units } }
        set { _meterQ.sync(flags: .barrier) { _units = newValue } } }
    
    @objc dynamic public var value: Float {
        get { return _meterQ.sync { _value } }
        set { _meterQ.sync(flags: .barrier) { _value = newValue } } }
    
    // ----------------------------------------------------------------------------
    // Mark: - Tokens for Meter messages (only populate values that != case value)
    
    internal enum MeterToken : String {
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
