//
//  XvtrCommands.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 7/19/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Xvtr Class extensions
//              - Dynamic public properties
//              - Xvtr message enum
// --------------------------------------------------------------------------------

extension Xvtr {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (with message sent to Radio)
    
    // listed in alphabetical order
    @objc dynamic public var ifFrequency: Int {
        get { return _ifFrequency }
        set { if _ifFrequency != newValue { _ifFrequency = newValue ; _radio!.send(kXvtrSetCmd + "\(id) " + XvtrToken.ifFrequency.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var loError: Int {
        get { return _loError }
        set { if _loError != newValue { _loError = newValue ; _radio!.send(kXvtrSetCmd + "\(id) " + XvtrToken.loError.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var name: String {
        get { return _name }
        set { if _name != newValue { _name = newValue ; _radio!.send(kXvtrSetCmd + "\(id) " + XvtrToken.name.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var maxPower: Int {
        get { return _maxPower }
        set { if _maxPower != newValue { _maxPower = newValue ; _radio!.send(kXvtrSetCmd + "\(id) " + XvtrToken.maxPower.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var order: Int {
        get { return _order }
        set { if _order != newValue { _order = newValue ; _radio!.send(kXvtrSetCmd + "\(id) " + XvtrToken.order.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var rfFrequency: Int {
        get { return _rfFrequency }
        set { if _rfFrequency != newValue { _rfFrequency = newValue ; _radio!.send(kXvtrSetCmd + "\(id) " + XvtrToken.rfFrequency.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var rxGain: Int {
        get { return _rxGain }
        set { if _rxGain != newValue { _rxGain = newValue ; _radio!.send(kXvtrSetCmd + "\(id) " + XvtrToken.rxGain.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var rxOnly: Bool {
        get { return _rxOnly }
        set { if _rxOnly != newValue { _rxOnly = newValue ; _radio!.send(kXvtrSetCmd + "\(id) " + XvtrToken.rxOnly.rawValue + "=\(newValue)") } } }

    // ----------------------------------------------------------------------------
    // MARK: - Tokens for Waterfall messages 
    
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
