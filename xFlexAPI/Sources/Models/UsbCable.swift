//
//  UsbCable.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 6/25/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - USB Cable Class implementation
//
//      creates a USB Cable instance to be used by a Client to support the
//      processing of USB connections to the Radio (hardware)
//
// --------------------------------------------------------------------------------

public final class UsbCable : NSObject, KeyValueParser {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    public private(set) var id: String = ""                 // Id that uniquely identifies this UsbCable
    public private(set) var cableType: UsbCableType         // Type of this UsbCable
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    internal var _radio: Radio?                             // The Radio that owns this UsbCable
    internal let kUsbCableSetCmd = "usb_cable set "         // UsbCable command prefixes
    internal let kUsbCableSetBitCmd = "usb_cable set bit "
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _initialized = false                    // True if initialized by Radio hardware
    fileprivate var _usbCableQ: DispatchQueue               // GCD queue that guards this object
    fileprivate let _log = Log.sharedInstance               // shared log
    
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    //                                                                                                  //
    fileprivate var __autoReport = false                    //                                          //
    fileprivate var __band = ""                             //                                          //
    fileprivate var __dataBits = 0                          //                                          //
    fileprivate var __enable = false                        //                                          //
    fileprivate var __flowControl = ""                      //                                          //
    fileprivate var __name = ""                             //                                          //
    fileprivate var __parity = ""                           //                                          //
    fileprivate var __pluggedIn = false                     //                                          //
    fileprivate var __polarity = ""                         //                                          //
    fileprivate var __preamp = ""                           //                                          //
    fileprivate var __source = ""                           //                                          //
    fileprivate var __sourceRxAnt = ""                      //                                          //
    fileprivate var __sourceSlice = 0                       //                                          //
    fileprivate var __sourceTxAnt = ""                      //                                          //
    fileprivate var __speed = 0                             //                                          //
    fileprivate var __stopBits = 0                          //                                          //
    fileprivate var __usbLog = false                        //                                          //
    fileprivate var __usbLogLine = ""                       //                                          //
    //                                                                                                  //
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    
    // ------------------------------------------------------------------------------
    // MARK: - Initialization
    
    /// Initialize a UsbCable
    ///
    /// - Parameters:
    ///   - id:             a UsbCable serial number
    ///   - radio:          parent Radio class
    ///   - queue:          UsbCable Concurrent queue
    ///   - cableType:      the type of UsbCable
    ///
    public init(radio: Radio, id: String, queue: DispatchQueue, cableType: UsbCableType) {
        
        self._radio = radio
        self.id = id
        self._usbCableQ = queue
        self.cableType = cableType
        
        super.init()
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - KeyValueParser Protocol methods
    //     called by Radio, executes on the parseQ
    
    /// Parse USB Cable key/value pairs
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///
    func parseKeyValues(_ keyValues: Radio.KeyValuesArray) {
        // TYPE: CAT
        //      <type, > <enable, > <pluggedIn, > <name, > <source, > <sourceTxAnt, > <sourceRxAnt, > <sourceSLice, > <autoReport, >
        //      <preamp, > <polarity, > <log, > <speed, > <dataBits, > <stopBits, > <parity, > <flowControl, >
        //
        // SA3923BB8|usb_cable A5052JU7 type=cat enable=1 plugged_in=1 name=THPCATCable source=tx_ant source_tx_ant=ANT1 source_rx_ant=ANT1 source_slice=0 auto_report=1 preamp=0 polarity=active_low band=0 log=0 speed=9600 data_bits=8 stop_bits=1 parity=none flow_control=none

        
        // FIXME: Need other formats
        

        // is the Status for a cable of this type?
        if cableType.rawValue == keyValues[0].value {
            
            // YES,
            // process each key/value pair, <key=value>
            for kv in keyValues {
                
                // check for unknown keys
                guard let token = UsbCableToken(rawValue: kv.key.lowercased()) else {
                    
                    // unknown Key, log it and ignore the Key
                    _log.msg("Unknown token - \(kv.key)", level: .debug, function: #function, file: #file, line: #line)
                    continue
                }
                // get the Integer & Bool version of the value
                let bValue = kv.value.bValue()
                let iValue = kv.value.iValue()
                
                // Known keys, in alphabetical order
                switch token {
                    
                case .autoReport:
                    willChangeValue(forKey: "autoReport")
                    _autoReport = bValue
                    didChangeValue(forKey: "autoReport")
                    
                case .band:
                    willChangeValue(forKey: "band")
                    _band = kv.value
                    didChangeValue(forKey: "band")
                    
                case .cableType:
                    // ignore this token's value (set by init)
                    break
                    
                case .dataBits:
                    willChangeValue(forKey: "dataBits")
                    _dataBits = iValue
                    didChangeValue(forKey: "dataBits")
                    
                case .enable:
                    willChangeValue(forKey: "enable")
                    _enable = bValue
                    didChangeValue(forKey: "enable")
                    
                case .flowControl:
                    willChangeValue(forKey: "flowControl")
                    _flowControl = kv.value
                    didChangeValue(forKey: "flowControl")
                    
                case .name:
                    willChangeValue(forKey: "name")
                    _name = kv.value
                    didChangeValue(forKey: "name")
                    
                case .parity:
                    willChangeValue(forKey: "parity")
                    _parity = kv.value
                    didChangeValue(forKey: "parity")
                    
                case .pluggedIn:
                    willChangeValue(forKey: "pluggedIn")
                    _pluggedIn = bValue
                    didChangeValue(forKey: "pluggedIn")
                    
                case .polarity:
                    willChangeValue(forKey: "polarity")
                    _polarity = kv.value
                    didChangeValue(forKey: "polarity")
                    
                case .preamp:
                    willChangeValue(forKey: "preamp")
                    _preamp = kv.value
                    didChangeValue(forKey: "preamp")
                    
                case .source:
                    willChangeValue(forKey: "source")
                    _source = kv.value
                    didChangeValue(forKey: "source")
                    
                case .sourceRxAnt:
                    willChangeValue(forKey: "sourceRxAnt")
                    _sourceRxAnt = kv.value
                    didChangeValue(forKey: "sourceRxAnt")
                    
                case .sourceSlice:
                    willChangeValue(forKey: "sourceSlice")
                    _sourceSlice = iValue
                    didChangeValue(forKey: "sourceSlice")
                    
                case .sourceTxAnt:
                    willChangeValue(forKey: "sourceTxAnt")
                    _sourceTxAnt = kv.value
                    didChangeValue(forKey: "sourceTxAnt")
                    
                case .speed:
                    willChangeValue(forKey: "speed")
                    _speed = iValue
                    didChangeValue(forKey: "speed")
                    
                case .stopBits:
                    willChangeValue(forKey: "stopBits")
                    _stopBits = iValue
                    didChangeValue(forKey: "stopBits")
                    
                case .usbLog:
                    willChangeValue(forKey: "usbLog")
                    _usbLog = bValue
                    didChangeValue(forKey: "usbLog")
                    
//                case .usbLogLine:
//                    willChangeValue(forKey: "usbLogLine")
//                    _usbLogLine = kv.value
//                    didChangeValue(forKey: "usbLogLine")
                    
                }
            }

        } else {
            
            // NO, log the error
            _log.msg("Status type (\(keyValues[0])) != Cable type (\(cableType)))", level: .error, function: #function, file: #file, line: #line)
        }
        
        // is the waterfall initialized?
        if !_initialized {
            
            // YES, the Radio (hardware) has acknowledged this UsbCable
            _initialized = true
            
            // notify all observers
            NC.post(.usbCableHasBeenAdded, object: self as Any?)
        }
    }
}

// --------------------------------------------------------------------------------
// MARK: - UsbCable Class extensions
//              - Synchronized internal properties
//              - Public properties, no message to Radio
// --------------------------------------------------------------------------------

extension UsbCable {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties - with synchronization
    
    // listed in alphabetical order
    internal var _autoReport: Bool {
        get { return _usbCableQ.sync { __autoReport } }
        set { _usbCableQ.sync(flags: .barrier) {__autoReport = newValue } } }
    
    internal var _band: String {
        get { return _usbCableQ.sync { __band } }
        set { _usbCableQ.sync(flags: .barrier) {__band = newValue } } }
    
    internal var _dataBits: Int {
        get { return _usbCableQ.sync { __dataBits } }
        set { _usbCableQ.sync(flags: .barrier) {__dataBits = newValue } } }
    
    internal var _enable: Bool {
        get { return _usbCableQ.sync { __enable } }
        set { _usbCableQ.sync(flags: .barrier) {__enable = newValue } } }
    
    internal var _flowControl: String {
        get { return _usbCableQ.sync { __flowControl } }
        set { _usbCableQ.sync(flags: .barrier) {__flowControl = newValue } } }
    
    internal var _name: String {
        get { return _usbCableQ.sync { __name } }
        set { _usbCableQ.sync(flags: .barrier) {__name = newValue } } }
    
    internal var _parity: String {
        get { return _usbCableQ.sync { __parity } }
        set { _usbCableQ.sync(flags: .barrier) {__parity = newValue } } }
    
    internal var _pluggedIn: Bool {
        get { return _usbCableQ.sync { __pluggedIn } }
        set { _usbCableQ.sync(flags: .barrier) {__pluggedIn = newValue } } }
    
    internal var _polarity: String {
        get { return _usbCableQ.sync { __polarity } }
        set { _usbCableQ.sync(flags: .barrier) {__polarity = newValue } } }
    
    internal var _preamp: String {
        get { return _usbCableQ.sync { __preamp } }
        set { _usbCableQ.sync(flags: .barrier) {__preamp = newValue } } }
    
    internal var _source: String {
        get { return _usbCableQ.sync { __source } }
        set { _usbCableQ.sync(flags: .barrier) {__source = newValue } } }
    
    internal var _sourceRxAnt: String {
        get { return _usbCableQ.sync { __sourceRxAnt } }
        set { _usbCableQ.sync(flags: .barrier) {__sourceRxAnt = newValue } } }
    
    internal var _sourceSlice: Int {
        get { return _usbCableQ.sync { __sourceSlice } }
        set { _usbCableQ.sync(flags: .barrier) {__sourceSlice = newValue } } }
    
    internal var _sourceTxAnt: String {
        get { return _usbCableQ.sync { __sourceTxAnt } }
        set { _usbCableQ.sync(flags: .barrier) {__sourceTxAnt = newValue } } }
    
    internal var _speed: Int {
        get { return _usbCableQ.sync { __speed } }
        set { _usbCableQ.sync(flags: .barrier) {__speed = newValue } } }
    
    internal var _stopBits: Int {
        get { return _usbCableQ.sync { __stopBits } }
        set { _usbCableQ.sync(flags: .barrier) {__stopBits = newValue } } }
    
    internal var _usbLog: Bool {
        get { return _usbCableQ.sync { __usbLog } }
        set { _usbCableQ.sync(flags: .barrier) {__usbLog = newValue } } }
    
//    internal var _usbLogLine: String {
//        get { return _usbCableQ.sync { __usbLogLine } }
//        set { _usbCableQ.sync(flags: .barrier) {__usbLogLine = newValue } } }
//    
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (no message to Radio)
    
    // FIXME: Should any of these send a message to the Radio?
    //          If yes, implement it, if not should they be "get" only?
    
    // listed in alphabetical order

    
    // ----------------------------------------------------------------------------
    // MARK: - UsbCable relate enum
    
    public enum UsbCableType: String {
        case bcd
        case bit
        case cat
        case dstar
        case invalid
        case ldpa
    }

}

