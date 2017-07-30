//
//  UsbCableCommands.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 7/21/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - UsbCable Class extensions
//              - Dynamic public properties that send commands to the Radio
//              - UsbCable message enum
// --------------------------------------------------------------------------------

extension UsbCable {

    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (with message sent to Radio)
    
    // listed in alphabetical order
    @objc dynamic public var autoReport: Bool {
        get { return _autoReport }
        set { if _autoReport != newValue { _autoReport = newValue ; _radio!.send(kUsbCableSetCmd + "\(id) " + UsbCableToken.autoReport.rawValue + " \(newValue.asNumber())") } } }
    
    @objc dynamic public var band: String {
        get { return _band }
        set { if _band != newValue { _band = newValue ; _radio!.send(kUsbCableSetCmd + "\(id) " + UsbCableToken.band.rawValue + " \(newValue)") } } }
    
    @objc dynamic public var dataBits: Int {
        get { return _dataBits }
        set { if _dataBits != newValue { _dataBits = newValue ; _radio!.send(kUsbCableSetCmd + "\(id) " + UsbCableToken.dataBits.rawValue + " \(newValue)") } } }
    
    @objc dynamic public var enable: Bool {
        get { return _enable }
        set { if _enable != newValue { _enable = newValue ; _radio!.send(kUsbCableSetCmd + "\(id) " + UsbCableToken.enable.rawValue + " \(newValue.asNumber())") } } }
    
    @objc dynamic public var flowControl: String {
        get { return _flowControl }
        set { if _flowControl != newValue { _flowControl = newValue ; _radio!.send(kUsbCableSetCmd + "\(id) " + UsbCableToken.flowControl.rawValue + " \(newValue)") } } }
    
    @objc dynamic public var name: String {
        get { return _name }
        set { if _name != newValue { _name = newValue ; _radio!.send(kUsbCableSetCmd + "\(id) " + UsbCableToken.name.rawValue + " \(newValue)") } } }
    
    @objc dynamic public var parity: String {
        get { return _parity }
        set { if _parity != newValue { _parity = newValue ; _radio!.send(kUsbCableSetCmd + "\(id) " + UsbCableToken.parity.rawValue + " \(newValue)") } } }
    
    @objc dynamic public var pluggedIn: Bool {
        get { return _pluggedIn }
        set { if _pluggedIn != newValue { _pluggedIn = newValue ; _radio!.send(kUsbCableSetCmd + "\(id) " + UsbCableToken.pluggedIn.rawValue + " \(newValue.asNumber())") } } }
    
    @objc dynamic public var polarity: String {
        get { return _polarity }
        set { if _polarity != newValue { _polarity = newValue ; _radio!.send(kUsbCableSetCmd + "\(id) " + UsbCableToken.polarity.rawValue + " \(newValue)") } } }
    
    @objc dynamic public var preamp: String {
        get { return _preamp }
        set { if _preamp != newValue { _preamp = newValue ; _radio!.send(kUsbCableSetCmd + "\(id) " + UsbCableToken.preamp.rawValue + " \(newValue)") } } }
    
    @objc dynamic public var source: String {
        get { return _source }
        set { if _source != newValue { _source = newValue ; _radio!.send(kUsbCableSetCmd + "\(id) " + UsbCableToken.source.rawValue + " \(newValue)") } } }
    
    @objc dynamic public var sourceRxAnt: String {
        get { return _sourceRxAnt }
        set { if _sourceRxAnt != newValue { _sourceRxAnt = newValue ; _radio!.send(kUsbCableSetCmd + "\(id) " + UsbCableToken.sourceRxAnt.rawValue + " \(newValue)") } } }
    
    @objc dynamic public var sourceSlice: Int {
        get { return _sourceSlice }
        set { if _sourceSlice != newValue { _sourceSlice = newValue ; _radio!.send(kUsbCableSetCmd + "\(id) " + UsbCableToken.source.rawValue + " \(newValue)") } } }
    
    @objc dynamic public var sourceTxAnt: String {
        get { return _sourceTxAnt }
        set { if _sourceTxAnt != newValue { _sourceTxAnt = newValue ; _radio!.send(kUsbCableSetCmd + "\(id) " + UsbCableToken.sourceTxAnt.rawValue + " \(newValue)") } } }
    
    @objc dynamic public var speed: Int {
        get { return _speed }
        set { if _speed != newValue { _speed = newValue ; _radio!.send(kUsbCableSetCmd + "\(id) " + UsbCableToken.speed.rawValue + " \(newValue)") } } }
    
    @objc dynamic public var stopBits: Int {
        get { return _stopBits }
        set { if _stopBits != newValue { _stopBits = newValue ; _radio!.send(kUsbCableSetCmd + "\(id) " + UsbCableToken.stopBits.rawValue + " \(newValue)") } } }
    
    @objc dynamic public var usbLog: Bool {
        get { return _usbLog }
        set { if _usbLog != newValue { _usbLog = newValue ; _radio!.send(kUsbCableSetCmd + "\(id) " + UsbCableToken.usbLog.rawValue + " \(newValue.asNumber())") } } }
    
//    @objc dynamic public var usbLogLine: String {
//        get { return _usbLogLine }
//        set { if _usbLogLine != newValue { _usbLogLine = _name ; _radio!.send(kUsbCableSetCmd + "\(id) " + UsbCableToken.usbLogLine.rawValue + " \(newValue)") } } }
    
    
    // ----------------------------------------------------------------------------
    // MARK: - Tokens for UsbCable messages
    
    internal enum UsbCableToken : String {
        case autoReport = "auto_report"
        case band
        case cableType = "type"
        case dataBits = "data_bits"
        case enable
        case flowControl = "flow_control"
        case name
        case parity
        case pluggedIn = "plugged_in"
        case polarity
        case preamp
        case source
        case sourceRxAnt = "source_rx_ant"
        case sourceSlice = "source_slice"
        case sourceTxAnt = "source_tx_ant"
        case speed
        case stopBits = "stop_bits"
        case usbLog = "log"
//        case usbLogLine = "log_line"
    }
}
