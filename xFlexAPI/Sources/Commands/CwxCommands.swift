//
//  CwxCommands.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 7/20/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Cwx Class extensions
//              - Public methods that send commands to the Radio
//              - Dynamic public properties that send commands to the Radio
//              - Cwx message enum
// --------------------------------------------------------------------------------

extension Cwx {
    
    // ------------------------------------------------------------------------------
    // MARK: - Public methods that send commands to the Radio (hardware)
    
    /// Clear the character buffer
    ///
    public func clearBuffer() {
        _radio!.send(kCwxCmd + "clear")
    }
    /// Erase "n" characters
    ///
    /// - Parameter numberOfChars: number of characters to erase
    ///
    public func erase(numberOfChars: Int) {
        _radio!.send(kCwxCmd + "erase \(numberOfChars)")
    }
    /// Insert a string of Cw, optionally with a block
    ///
    /// - Parameters:
    ///   - string:         the text to insert
    ///   - index:          the index at which to insert the messagek
    ///   - block:          an optional block
    ///
    public func insert(_ string: String, index: Int, block: Int? = nil) {
        
        // replace spaces with 0x7f
        let msg = String(string.characters.map { $0 == " " ? "\u{7f}" : $0 })
        
        if let block = block {
            
            _radio!.send(kCwxInsertCmd + "\(index) \"" + msg + "\" \(block)", replyTo: replyHandler)
            
        } else {
            
            _radio!.send(kCwxInsertCmd + "\(index) \"" + msg + "\"", replyTo: replyHandler)
        }
    }
    /// Save the specified Cwx Macro and tell the Radio (hardware)
    ///
    ///     NOTE:
    ///         Macros are numbered 0..<kMaxNumberOfMacros internally
    ///         Macros are numbered 1...kMaxNumberOfMacros in commands
    ///
    /// - Parameters:
    ///   - index:              the index of the macro
    ///   - msg:                the text of the macro
    /// - Returns:              true if found, false otherwise
    ///
    public func saveMacro(index: Int, msg: String) -> Bool {
        
        if index < 0 || index > kMaxNumberOfMacros - 1 { return false }
        
        macros[index] = msg
        
        _radio!.send(kCwxMacroCmd + "save \(index+1)" + " \"" + msg + "\"")
        
        return true
    }
    /// Send a string of Cw, optionally with a block
    ///
    /// - Parameters:
    ///   - string:         the text to send
    ///   - block:          an optional block
    ///
    public func send(_ string: String, block: Int? = nil) {
        
        // replace spaces with 0x7f
        let msg = String(string.characters.map { $0 == " " ? "\u{7f}" : $0 })
        
        if let block = block {
            
            _radio!.send(kCwxSendCmd + "\"" + msg + "\" \(block)", replyTo: replyHandler)
            
        } else {
            
            _radio!.send(kCwxSendCmd + "\"" + msg + "\"", replyTo: replyHandler)
        }
    }
    /// Send the specified Cwx Macro
    ///
    /// - Parameters:
    ///   - index: the index of the macro
    ///   - block: an optional block ( > 0)
    ///
    public func sendMacro(index: Int, block: Int? = nil) {
        
        if index < 0 || index > kMaxNumberOfMacros { return }
        
        if let block = block {
            
            _radio!.send(kCwxMacroCmd + "send \(index) \(block)", replyTo: replyHandler)
            
        } else {
            
            _radio!.send(kCwxMacroCmd + "send \(index)", replyTo: replyHandler)
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (with message sent to Radio)
    
    // listed in alphabetical order
    @objc dynamic public var delay: Int {
        get { return _delay }
        set { if _delay != newValue { let value = newValue.bound(kMinDelayMs, kMaxDelayMs) ;  _delay = value ; _radio!.send(kCwxCmd + CwxToken.delay.rawValue + " \(value)") } } }
    
    @objc dynamic public var qskEnabled: Bool {
        get { return _qskEnabled }
        set { if _qskEnabled != newValue { _qskEnabled = newValue ; _radio!.send(kCwxCmd + CwxToken.qskEnabled.rawValue + " \(newValue.asNumber())") } } }
    
    @objc dynamic public var wpm: Int {
        get { return _wpm }
        set { if _wpm != newValue { let value = newValue.bound(kMinSpeed, kMaxSpeed) ; if _wpm != value  { _wpm = value ; _radio!.send(kCwxCmd + CwxToken.wpm.rawValue + " \(value)") } } } }
    
    // ----------------------------------------------------------------------------
    // Mark: - Tokens for Cwx messages
    
    public enum CwxToken : String {
        case delay
        case qskEnabled = "qsk_enabled"
        case erase
        case sent
        case wpm = "wpm"
    }

}
