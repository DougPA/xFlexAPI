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
    @objc dynamic public var enable: Bool {
        get { return _enable }
        set { if _enable != newValue { _enable = newValue ; _radio!.send(kUsbCableSetCmd + "\(id) " + UsbCableToken.enable.rawValue + " \(newValue.asNumber())") } } }
    
    @objc dynamic public var name: String {
        get { return _name }
        set { if _name != newValue { _name = newValue ; _radio!.send(kUsbCableSetCmd + "\(id) " + UsbCableToken.name.rawValue + " \(newValue)") } } }
    
    @objc dynamic public var pluggedIn: Bool {
        get { return _pluggedIn }
        set { if _pluggedIn != newValue { _pluggedIn = newValue ; _radio!.send(kUsbCableSetCmd + "\(id) " + UsbCableToken.pluggedIn.rawValue + " \(newValue.asNumber())") } } }
    
    @objc dynamic public var usbLog: Bool {
        get { return _usbLog }
        set { if _usbLog != newValue { _usbLog = newValue ; _radio!.send(kUsbCableSetCmd + "\(id) " + UsbCableToken.usbLog.rawValue + " \(newValue.asNumber())") } } }
    
    @objc dynamic public var usbLogLine: String {
        get { return _usbLogLine }
        set { if _usbLogLine != newValue { _usbLogLine = _name ; _radio!.send(kUsbCableSetCmd + "\(id) " + UsbCableToken.usbLogLine.rawValue + " \(newValue)") } } }
    
    
    // ----------------------------------------------------------------------------
    // MARK: - Tokens for UsbCable messages
    
    internal enum UsbCableToken : String {
        case enable
        case name
        case pluggedIn = "plugged_in"
        case usbLog = "log"
        case usbLogLine = "log_line"
    }
}
