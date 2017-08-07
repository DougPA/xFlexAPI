//
//  AmplifierCommands.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 8/7/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation


// --------------------------------------------------------------------------------
// MARK: - Amplifier Class extensions
//              - Dynamic public properties that send commands to the Radio
//              - Amplifier message enum
// --------------------------------------------------------------------------------

extension Amplifier {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (with message sent to Radio)
    
    // listed in alphabetical order
    @objc dynamic public var ant: String {
        get { return _ant }
        set { if _ant != newValue { _ant = newValue ; _radio!.send(kAmplifierSetCmd + "\(id) " + AmplifierToken.ant.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var ip: String {
        get { return _ip }
        set { if _ip != newValue { _ip = newValue ; _radio!.send(kAmplifierSetCmd + "\(id) " + AmplifierToken.ip.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var model: String {
        get { return _model }
        set { if _model != newValue { _model = newValue ; _radio!.send(kAmplifierSetCmd + "\(id) " + AmplifierToken.model.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var port: Int {
        get { return _port }
        set { if _port != newValue { _port = newValue ; _radio!.send(kAmplifierSetCmd + "\(id) " + AmplifierToken.port.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var serialNumber: String {
        get { return _serialNumber }
        set { if _serialNumber != newValue { _serialNumber = newValue ; _radio!.send(kAmplifierSetCmd + "\(id) " + AmplifierToken.serialNumber.rawValue + "=\(newValue)") } } }
    
    // ----------------------------------------------------------------------------
    // MARK: - Tokens for Amplifier messages
    
    internal enum AmplifierToken : String {
        case ant
        case ip
        case model
        case port
        case serialNumber = "serial_num"
    }
}
