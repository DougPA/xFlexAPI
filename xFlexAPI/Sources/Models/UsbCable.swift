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
    fileprivate var __enable = false                        //                                          //
    fileprivate var __usbLog = false                        //                                          //
    fileprivate var __usbLogLine = ""                       //                                          //
    fileprivate var __name = ""                             //                                          //
    fileprivate var __pluggedIn = false                     //                                          //
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
        
        // process each key/value pair, <key=value>
        for kv in keyValues {
            
            // check for unknown keys
            guard let token = UsbCableToken(rawValue: kv.key.lowercased()) else {
                
                // unknown Key, log it and ignore the Key
                _log.msg("Unknown token - \(kv.key)", level: .debug, function: #function, file: #file, line: #line)
                continue
            }
            // get the Bool version of the value
            let bValue = kv.value.bValue()
            
            // Known keys, in alphabetical order
            switch token {

            case .enable:
                willChangeValue(forKey: "enable")
                _enable = bValue
                didChangeValue(forKey: "enable")

            case .usbLog:
                willChangeValue(forKey: "usbLog")
                _usbLog = bValue
                didChangeValue(forKey: "usbLog")
            
            case .usbLogLine:
                willChangeValue(forKey: "usbLogLine")
                _usbLogLine = kv.value
                didChangeValue(forKey: "usbLogLine")
                
            case .name:
                willChangeValue(forKey: "name")
                _name = kv.value
                didChangeValue(forKey: "name")
                
            case .pluggedIn:
                willChangeValue(forKey: "pluggedIn")
                _pluggedIn = bValue
                didChangeValue(forKey: "pluggedIn")
                
            }
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
    internal var _enable: Bool {
        get { return _usbCableQ.sync { __enable } }
        set { _usbCableQ.sync(flags: .barrier) {__enable = newValue } } }
    
    internal var _usbLog: Bool {
        get { return _usbCableQ.sync { __usbLog } }
        set { _usbCableQ.sync(flags: .barrier) {__usbLog = newValue } } }
    
    internal var _usbLogLine: String {
        get { return _usbCableQ.sync { __usbLogLine } }
        set { _usbCableQ.sync(flags: .barrier) {__usbLogLine = newValue } } }
    
    internal var _name: String {
        get { return _usbCableQ.sync { __name } }
        set { _usbCableQ.sync(flags: .barrier) {__name = newValue } } }
    
    internal var _pluggedIn: Bool {
        get { return _usbCableQ.sync { __pluggedIn } }
        set { _usbCableQ.sync(flags: .barrier) {__pluggedIn = newValue } } }
    
    
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

