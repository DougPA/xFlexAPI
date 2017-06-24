//
//  Tnf.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 6/30/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Foundation

// ------------------------------------------------------------------------------
// MARK: - TNF Class implementation
//
//      creates a Tnf instance to be used by a Client to support the
//      rendering of a Tnf
//
// ------------------------------------------------------------------------------

public final class Tnf : NSObject, KeyValueParser {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    public private(set) var id: Radio.TnfId             // Id that uniquely identifies this Tnf
    public var minWidth = 5                             // default minimum Tnf width (Hz)
    public var maxWidth = 6000                          // default maximum Tnf width (Hz)

    // ------------------------------------------------------------------------------
    // MARK: - Internal properties
    
    private weak var _radio: Radio?                 // The Radio that owns this Tnf
    private var _tnfQ: DispatchQueue                // GCD queue that guards this object
    private var _initialized = false                // True if initialized by Radio hardware

    // constants
    private let _log = Log.sharedInstance           // shared Log
    private let kSetCommand = "tnf set "            // Tnf Set command prefix
    
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    //                                                                                              //
    private var __depth = Tnf.Depth.normal.rawValue // Depth (Normal, Deep, Very Deep)              //
    private var __frequency = 0                     // Frequency (Hz)                               //
    private var __permanent = false                 // True =                                       //
    private var __width = 0                         // Width (Hz)                                   //
    //                                                                                              //
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    
    // ------------------------------------------------------------------------------
    // MARK: - Initialization
    
    /// Initialize a Tnf
    ///
    /// - Parameters:
    ///   - id:         a Tnf Id
    ///   - radio:      parent Radio class
    ///   - queue:      Tnf Concurrent queue
    ///
    public convenience init(id: Radio.TnfId, radio: Radio, queue: DispatchQueue) {
        self.init(id: id, radio: radio, frequency: 0, depth: Tnf.Depth.normal.rawValue, width: 0, permanent: false, queue: queue)
    }
    /// Initialize a Tnf
    ///
    /// - Parameters:
    ///   - id:         a Tnf Id
    ///   - radio:      parent Radio class
    ///   - frequency:  Tnf frequency (Hz)
    ///   - queue:      Tnf Concurrent queue
    ///
    public convenience init(id: Radio.TnfId, radio: Radio, frequency: Int, queue: DispatchQueue) {
        self.init(id: id, radio: radio, frequency: frequency, depth: Tnf.Depth.normal.rawValue, width: 0, permanent: false, queue: queue)
    }
    /// Initialize a Tnf
    ///
    /// - Parameters:
    ///   - id:         a Tnf Id
    ///   - radio:      parent Radio class
    ///   - frequency:  Tnf frequency (Hz)
    ///   - depth:      a Depth value
    ///   - width:      a Width value
    ///   - permanent:  true = permanent
    ///   - queue:      Tnf Concurrent queue
    ///
    public init(id: Radio.TnfId, radio: Radio, frequency: Int, depth: Int, width: Int, permanent: Bool, queue: DispatchQueue) {
        
        self.id = id
        self._radio = radio
        self._tnfQ = queue

        super.init()

        self.frequency = frequency
        self.depth = depth
        self.width = width
        self.permanent = permanent
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - Public methods
    
    // ------------------------------------------------------------------------------
    // MARK: - KeyValueParser Protocol methods
    //     called by Radio, executes on the radioQ
    
    /// Parse Tnf key/value pairs
    ///
    /// - parameter keyValues: a KeyValuesArray
    ///
    public func parseKeyValues(_ keyValues: Radio.KeyValuesArray) {
        
        // process each key/value pair, <key=value>
        for kv in keyValues {
            
            // check for unknown keys
            guard let token = Token(rawValue: kv.key.lowercased()) else {
                // unknown Key, log it and ignore the Key
                _log.msg("Unknown token - \(kv.key)", level: .debug, function: #function, file: #file, line: #line)
                continue
            }
            // known keys, in alphabetical order
            switch token {
                
            case .depth:
                willChangeValue(forKey: "depth")
                _depth = Int(kv.value) ?? 1
                didChangeValue(forKey: "depth")
            
            case .frequency:
                willChangeValue(forKey: "frequency")
                _frequency = kv.value.mhzToHz()
                didChangeValue(forKey: "frequency")
            
            case .permanent:
                willChangeValue(forKey: "permanent")
                _permanent = kv.value.bValue()
                didChangeValue(forKey: "permanent")
            
            case .width:
                willChangeValue(forKey: "width")
                _width = kv.value.mhzToHz()
                didChangeValue(forKey: "width")
            }
        }
        // is the Tnf initialized?
        if !_initialized && _frequency != 0 {
            
            // YES, the Radio (hardware) has acknowledged this Tnf
            _initialized = true
            
            // notify all observers
            NC.post(.tnfHasBeenAdded, object: self as Any?)

        }
    }
}

// --------------------------------------------------------------------------------
// MARK: - Tnf Class extensions
//              - Synchronized internal properties
//              - Dynamic public properties
//              - Tnf message enum
// --------------------------------------------------------------------------------

extension Tnf {
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties - with synchronization
    
    // listed in alphabetical order
    private var _depth: Int {
        get { return _tnfQ.sync { __depth } }
        set { _tnfQ.sync(flags: .barrier) { __depth = newValue } } }
    
    private var _frequency: Int {
        get { return _tnfQ.sync { __frequency } }
        set { _tnfQ.sync(flags: .barrier) { __frequency = newValue } } }
    
    private var _permanent: Bool {
        get { return _tnfQ.sync { __permanent } }
        set { _tnfQ.sync(flags: .barrier) { __permanent = newValue } } }
    
    private var _width: Int {
        get { return _tnfQ.sync { __width } }
        set { _tnfQ.sync(flags: .barrier) { __width = newValue } } }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant with Radio update
    
    // listed in alphabetical order
    @objc dynamic public var depth: Int {
        get { return _depth }
        set { if _depth != newValue { if depth.within(Depth.normal.rawValue, Depth.veryDeep.rawValue) { _depth = newValue ; _radio!.send(kSetCommand + "\(id) depth=\(newValue)") } } } }
    
    @objc dynamic public var frequency: Int {
        get { return _frequency }
        set { if _frequency != newValue { _frequency = newValue ; _radio!.send(kSetCommand + "\(id) freq=\(newValue.hzToMhz())") } } }
    
    @objc dynamic public var permanent: Bool {
        get { return _permanent }
        set { if _permanent != newValue { _permanent = newValue ; _radio!.send(kSetCommand + "\(id) permanent=\(newValue.asNumber())") } } }
    
    @objc dynamic public var width: Int {
        get { return _width  }
        set { if _width != newValue { if width.within(minWidth, maxWidth) { _width = newValue ; _radio!.send(kSetCommand + "\(id) width=\(newValue.hzToMhz())") } } } }
    
    // ----------------------------------------------------------------------------
    // Mark: - Tokens for Tnf messages (only populate values that != case value)
    
    internal enum Token : String {
        case depth
        case frequency = "freq"
        case permanent
        case width
    }
    
    public enum Depth : Int {
        case normal = 1
        case deep = 2
        case veryDeep = 3
    }

}

