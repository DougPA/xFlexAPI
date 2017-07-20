//
//  MemoryCommands.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 7/20/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Memory Class extensions
//              - Dynamic public properties that send commands to the Radio
//              - Memory message enum
// --------------------------------------------------------------------------------

extension Memory {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (with message sent to Radio)
    
    // listed in alphabetical order
    @objc dynamic public var digitalLowerOffset: Int {
        get { return _digitalLowerOffset }
        set { if _digitalLowerOffset != newValue { _digitalLowerOffset = newValue ; _radio.send(kMemorySetCmd + "\(id) " + MemoryToken.digitalLowerOffset.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var digitalUpperOffset: Int {
        get { return _digitalUpperOffset }
        set { if _digitalUpperOffset != newValue { _digitalUpperOffset = newValue ; _radio.send(kMemorySetCmd + "\(id) " + MemoryToken.digitalUpperOffset.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var filterHigh: Int {
        get { return _filterHigh }
        set { let value = filterHighLimits(newValue) ; if _filterHigh != value { _filterHigh = value ; _radio.send(kMemorySetCmd + "\(id) " + MemoryToken.rxFilterHigh.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var filterLow: Int {
        get { return _filterLow }
        set { let value = filterLowLimits(newValue) ; if _filterLow != value { _filterLow = value ; _radio.send(kMemorySetCmd + "\(id) " + MemoryToken.rxFilterLow.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var frequency: Int {
        get { return _frequency }
        set { if _frequency != newValue { _frequency = newValue ; _radio.send(kMemorySetCmd + "\(id) " + MemoryToken.frequency.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var group: String {
        get { return _group }
        set { let value = newValue.replacingSpacesWith("\u{007F}") ; if _group != value { _group = value ; _radio.send(kMemorySetCmd + "\(id) " + MemoryToken.group.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var mode: String {
        get { return _mode }
        set { if _mode != newValue { _mode = newValue ; _radio.send(kMemorySetCmd + "\(id)  " + MemoryToken.mode.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var name: String {
        get { return _name }
        set { let value = newValue.replacingSpacesWith("\u{007F}") ; if _name != value { _name = newValue ; _radio.send(kMemorySetCmd + "\(id) " + MemoryToken.name.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var offset: Int {
        get { return _offset }
        set { if _offset != newValue { _offset = newValue ; _radio.send(kMemorySetCmd + "\(id)  " + MemoryToken.repeaterOffset.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var offsetDirection: String {
        get { return _offsetDirection }
        set { if _offsetDirection != newValue { _offsetDirection = newValue ; _radio.send(kMemorySetCmd + "\(id) " + MemoryToken.repeaterOffsetDirection.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var owner: String {
        get { return _owner }
        set { let value = newValue.replacingSpacesWith("\u{007F}") ; if _owner != value { _owner = newValue ; _radio.send(kMemorySetCmd + "\(id) " + MemoryToken.owner.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var rfPower: Int {
        get { return _rfPower }
        set { if _rfPower != newValue && newValue.within(kMinLevel, kMaxLevel) { _rfPower = newValue ; _radio.send(kMemorySetCmd + "\(id) " + MemoryToken.rfPower.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var rttyMark: Int {
        get { return _rttyMark }
        set { if _rttyMark != newValue { _rttyMark = newValue ; _radio.send(kMemorySetCmd + "\(id) " + MemoryToken.rttyMark.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var rttyShift: Int {
        get { return _rttyShift }
        set { if _rttyShift != newValue { _rttyShift = newValue ; _radio.send(kMemorySetCmd + "\(id) " + MemoryToken.rttyShift.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var squelchEnabled: Bool {
        get { return _squelchEnabled }
        set { if _squelchEnabled != newValue { _squelchEnabled = newValue ; _radio.send(kMemorySetCmd + "\(id) " + MemoryToken.squelchEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var squelchLevel: Int {
        get { return _squelchLevel }
        set { if _squelchLevel != newValue && newValue.within(kMinLevel, kMaxLevel) { _squelchLevel = newValue ; _radio.send(kMemorySetCmd + "\(id) " + MemoryToken.squelchLevel.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var step: Int {
        get { return _step }
        set { if _step != newValue { _step = newValue ; _radio.send(kMemorySetCmd + "\(id) " + MemoryToken.step.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var toneMode: String {
        get { return _toneMode }
        set { if _toneMode != newValue { _toneMode = newValue ; _radio.send(kMemorySetCmd + "\(id) " + MemoryToken.toneMode.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var toneValue: Int {
        get { return _toneValue }
        set { if _toneValue != newValue && toneValueValid(newValue) { _toneValue = newValue ; _radio.send(kMemorySetCmd + "\(id) " + MemoryToken.toneValue.rawValue + "=\(newValue)") } } }
    
    // ----------------------------------------------------------------------------
    // Mark: - Tokens for Memory messages
    
    internal enum MemoryToken : String {
        case digitalLowerOffset = "digl_offset"
        case digitalUpperOffset = "digu_offset"
        case frequency = "freq"
        case group
        case highlight
        case highlightColor = "highlight_color"
        case mode
        case name
        case owner
        case repeaterOffsetDirection = "repeater"
        case repeaterOffset = "repeater_offset"
        case rfPower = "power"
        case rttyMark = "rtty_mark"
        case rttyShift = "rtty_shift"
        case rxFilterHigh = "rx_filter_high"
        case rxFilterLow = "rx_filter_low"
        case step
        case squelchEnabled = "squelch"
        case squelchLevel = "squelch_level"
        case toneMode = "tone_mode"
        case toneValue = "tone_value"
    }
    
}
