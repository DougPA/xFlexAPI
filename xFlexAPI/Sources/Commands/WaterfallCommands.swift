//
//  WaterfallCommands.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 7/19/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Waterfall Class extensions
//              - Dynamic public properties that send commands to the Radio
//              - Waterfall message enum
// --------------------------------------------------------------------------------

extension Waterfall {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (with message sent to Radio)
    
    // listed in alphabetical order
    @objc dynamic public var autoBlackEnabled: Bool {
        get { return _autoBlackEnabled }
        set { if _autoBlackEnabled != newValue { _autoBlackEnabled = newValue ; _radio!.send(kDisplayPanafallSetCmd + "0x\(id) " + WaterfallToken.autoBlackEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var blackLevel: Int {
        get { return _blackLevel }
        set { if _blackLevel != newValue { _blackLevel = newValue ; _radio!.send(kDisplayPanafallSetCmd + "0x\(id) " + WaterfallToken.blackLevel.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var colorGain: Int {
        get { return _colorGain }
        set { if _colorGain != newValue { _colorGain = newValue ; _radio!.send(kDisplayPanafallSetCmd + "0x\(id) " + WaterfallToken.colorGain.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var gradientIndex: Int {
        get { return _gradientIndex }
        set { if _gradientIndex != newValue { _gradientIndex = newValue ; _radio!.send(kDisplayPanafallSetCmd + "0x\(id) " + WaterfallToken.gradientIndex.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var lineDuration: Int {
        get { return _lineDuration }
        set { if _lineDuration != newValue { _lineDuration = newValue ; _radio!.send(kDisplayPanafallSetCmd + "0x\(id) " + WaterfallToken.lineDuration.rawValue + "=\(newValue)") } } }
    
    
    // ----------------------------------------------------------------------------
    // MARK: - Tokens for Waterfall messages 
    
    internal enum WaterfallToken : String {
        // on Waterfall
        case autoBlackEnabled = "auto_black"
        case blackLevel = "black_level"
        case colorGain = "color_gain"
        case gradientIndex = "gradient_index"
        case lineDuration = "line_duration"
        // unused here
        case available
        case band
        case bandwidth
        case capacity
        case center
        case daxIq = "daxiq"
        case daxIqRate = "daxiq_rate"
        case loopA = "loopa"
        case loopB = "loopb"
        case panadapterId = "panadapter"
        case rfGain = "rfgain"
        case rxAnt = "rxant"
        case wide
        case xPixels = "x_pixels"
        case xvtr
    }

}
