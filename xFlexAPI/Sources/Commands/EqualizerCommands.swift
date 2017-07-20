//
//  EqualizerCommands.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 7/20/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Equalizer Class extensions
//              - Dynamic public properties that send commands to the Radio
//              - Equalizer message enum
// --------------------------------------------------------------------------------

extension Equalizer {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (with message sent to Radio) - checked
    
    // listed in alphabetical order
    @objc dynamic public var eqEnabled: Bool {
        get { return  _eqEnabled }
        set { if _eqEnabled != newValue { _eqEnabled = newValue ; _radio!.send( kEqCmd + eqType.rawValue + " " + EqualizerToken.enabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var level63Hz: Int {
        get { return _level63Hz }
        set { if _level63Hz != newValue { _level63Hz = newValue ; _radio!.send(kEqCmd + eqType.rawValue + " " + EqualizerToken.level63Hz.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var level125Hz: Int {
        get { return _level125Hz }
        set { if _level125Hz != newValue { _level125Hz = newValue ; _radio!.send(kEqCmd + eqType.rawValue + " " + EqualizerToken.level125Hz.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var level250Hz: Int {
        get { return _level250Hz }
        set { if _level250Hz != newValue { _level250Hz = newValue ; _radio!.send(kEqCmd + eqType.rawValue + " " + EqualizerToken.level250Hz.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var level500Hz: Int {
        get { return _level500Hz }
        set { if _level500Hz != newValue { _level500Hz = newValue ; _radio!.send(kEqCmd + eqType.rawValue + " " + EqualizerToken.level500Hz.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var level1000Hz: Int {
        get { return _level1000Hz }
        set { if _level1000Hz != newValue { _level1000Hz = newValue ; _radio!.send(kEqCmd + eqType.rawValue + " " + EqualizerToken.level1000Hz.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var level2000Hz: Int {
        get { return _level2000Hz }
        set { if _level2000Hz != newValue { _level2000Hz = newValue ; _radio!.send(kEqCmd + eqType.rawValue + " " + EqualizerToken.level2000Hz.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var level4000Hz: Int {
        get { return _level4000Hz }
        set { if _level4000Hz != newValue { _level4000Hz = newValue ; _radio!.send(kEqCmd + eqType.rawValue + " " + EqualizerToken.level4000Hz.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var level8000Hz: Int {
        get { return _level8000Hz }
        set { if _level8000Hz != newValue { _level8000Hz = newValue ; _radio!.send(kEqCmd + eqType.rawValue + " " + EqualizerToken.level8000Hz.rawValue + "=\(newValue)") } } }

    // ----------------------------------------------------------------------------
    // Mark: - Tokens for Equalizer messages
    
    internal enum EqualizerToken : String {
        case level63Hz = "63hz"
        case level125Hz = "125hz"
        case level250Hz = "250hz"
        case level500Hz = "500hz"
        case level1000Hz = "1000hz"
        case level2000Hz = "2000hz"
        case level4000Hz = "4000hz"
        case level8000Hz = "8000hz"
        case enabled = "mode"
    }
}
