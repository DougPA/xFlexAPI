//
//  PanadapterCommands.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 7/19/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Panadapter Class extensions
//              - Dynamic public properties
//              - Panadapter message enum
// --------------------------------------------------------------------------------

extension Panadapter {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (with message sent to Radio) - checked
    
    // listed in alphabetical order
    @objc dynamic public var average: Int {
        get { return _average }
        set {if _average != newValue { _average = newValue ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) " + PanadapterToken.average.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var band: String {
        get { return _band }
        set { if _band != newValue { _band = newValue ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) " + PanadapterToken.band.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var bandwidth: Int {
        get { return _bandwidth }
        set { if _bandwidth != newValue { _bandwidth = newValue ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) " + PanadapterToken.center.rawValue + "=\(newValue.hzToMhz()) autocenter=1") } } }
    
    // FIXME: Where does autoCenter come from?
    
    @objc dynamic public var center: Int {
        get { return _center }
        set { if _center != newValue { _center = newValue ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) " + PanadapterToken.center.rawValue +  "=\(newValue.hzToMhz())") } } }
    
    @objc dynamic public var daxIqChannel: Int {
        get { return _daxIqChannel }
        set { if _daxIqChannel != newValue { _daxIqChannel = newValue ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) " + PanadapterToken.daxIqChannel.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var fps: Int {
        get { return _fps }
        set { if _fps != newValue { _fps = newValue ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) " + PanadapterToken.fps.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var loopAEnabled: Bool {
        get { return _loopAEnabled }
        set { if _loopAEnabled != newValue { _loopAEnabled = newValue ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) " + PanadapterToken.loopAEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var loopBEnabled: Bool {
        get { return _loopBEnabled }
        set { if _loopBEnabled != newValue { _loopBEnabled = newValue ; radio!.send(kDisplayPanafallSetCmd + "0x\(id)  " + PanadapterToken.loopBEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var maxDbm: CGFloat {
        get { return _maxDbm }
        set { let value = newValue > 20.0 ? 20.0 : newValue ; if _maxDbm != value { _maxDbm = value ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) " + PanadapterToken.maxDbm.rawValue + "=\(value)") } } }
    
    @objc dynamic public var minDbm: CGFloat {
        get { return _minDbm }
        set { let value  = newValue < -180.0 ? -180.0 : newValue ; if _minDbm != value { _minDbm = value ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) " + PanadapterToken.minDbm.rawValue + "=\(value)") } } }
    
    @objc dynamic public var panDimensions: CGSize {
        get { return _panDimensions }
        set { if _panDimensions != newValue { _panDimensions = newValue ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) " + "xpixels" + "=\(newValue.width) " + "ypixels" + "=\(newValue.height)") } } }
    
    @objc dynamic public var rfGain: Int {
        get { return _rfGain }
        set { if _rfGain != newValue { _rfGain = newValue ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) " + PanadapterToken.rfGain.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var rxAnt: String {
        get { return _rxAnt }
        set { if _rxAnt != newValue { _rxAnt = newValue ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) " + PanadapterToken.rxAnt.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var weightedAverageEnabled: Bool {
        get { return _weightedAverageEnabled }
        set { if _weightedAverageEnabled != newValue { _weightedAverageEnabled = newValue ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) " + PanadapterToken.weightedAverageEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var wnbEnabled: Bool {
        get { return _wnbEnabled }
        set { if _wnbEnabled != newValue { _wnbEnabled = newValue ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) " + PanadapterToken.wnbEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var wnbLevel: Int {
        get { return _wnbLevel }
        set { if _wnbLevel != newValue { _wnbLevel = newValue ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) " + PanadapterToken.wnbLevel.rawValue + "=\(newValue)") } } }

    // ----------------------------------------------------------------------------
    // MARK: - Tokens for Panadapter messages 
    
    internal enum PanadapterToken : String {
        // on Panadapter
        case antList = "ant_list"
        case average
        case band
        case bandwidth
        case center
        case daxIqChannel = "daxiq"
        case fps
        case loopAEnabled = "loopa"
        case loopBEnabled = "loopb"
        case maxBw = "max_bw"
        case maxDbm = "max_dbm"
        case minBw = "min_bw"
        case minDbm = "min_dbm"
        case preamp = "pre"
        case rfGain = "rfgain"
        case rxAnt = "rxant"
        case waterfallId = "waterfall"
        case weightedAverageEnabled = "weighted_average"
        case wide
        case wnbEnabled = "wnb"
        case wnbLevel = "wnb_level"
        case wnbUpdating = "wnb_updating"
        case xPixels = "x_pixels"
        case xvtrLabel = "xvtr"
        case yPixels = "y_pixels"
        // unused here
        case available
        case capacity
        case daxIqRate = "daxiq_rate"
    }

}
