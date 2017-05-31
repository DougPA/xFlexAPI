//
//  Cwx.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 6/30/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Cwx Class implementation
// --------------------------------------------------------------------------------

public final class Cwx : NSObject, KeyValueParser {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    private(set) var macros: [String]
    public var messageQueuedEventHandler: ((_ sequence: Int, _ bufferIndex: Int) -> Void)?
    public var charSentEventHandler: ((_ index: Int) -> Void)?
    public var eraseSentEventHandler: ((_ start: Int, _ stop: Int) -> Void)?
    
    // ------------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate weak var  radio: Radio?                 // The Radio that owns this Cwx
    fileprivate var _cwxQ: DispatchQueue                // GCD queue that guards this object

    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    //                                                                                              //
    fileprivate var __delay = 0                         // Delay (ms)                               //
    fileprivate var __qskEnabled = false                // QSK Enabled                              //
    fileprivate var __speed = 0                         // Speed (wpm)                              //
    //                                                                                              //
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------

    // constants
    fileprivate let _log = Log.sharedInstance           // shared log
    fileprivate let kModule = "Cwx"                     // Module Name reported in log messages
    fileprivate let kMinDelayMs = 0                     // Min delay (ms)
    fileprivate let kMaxDelayMs = 2000                  // Max delay (ms)
    fileprivate let kMinSpeed = 5                       // Min speed (wpm)
    fileprivate let kMaxSpeed = 100                     // Max speed (wpm)
    fileprivate let kMaxNumberOfMacros = 12             // Max number of macros

    fileprivate let kCwxCmd = "cwx "                    // Command prefixes
    fileprivate let kCwxInsertCmd = "cwx insert "
    fileprivate let kCwxMacroCmd = "cwx macro "
    fileprivate let kCwxSendCmd = "cwx send "
    
    fileprivate let kNoError = "0"                      // Response without error
    
    // ------------------------------------------------------------------------------
    // MARK: - Initialization
    
    init(radio: Radio, queue: DispatchQueue) {
        
        self.radio = radio
        self._cwxQ = queue
        macros = [String](repeating: "", count: kMaxNumberOfMacros)
        
        super.init()
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - Public methods that send commands to the Radio (hardware)
    
    public func clearBuffer() { radio!.send(kCwxCmd + "clear") }
    public func erase(numberOfChars: Int) { radio!.send(kCwxCmd + "erase \(numberOfChars)") }

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
            
            radio!.send(kCwxSendCmd + "\"" + msg + "\" \(block)", replyTo: replyHandler)
            
        } else {
            
            radio!.send(kCwxSendCmd + "\"" + msg + "\"", replyTo: replyHandler)
        }
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
            
            radio!.send(kCwxInsertCmd + "\(index) \"" + msg + "\" \(block)", replyTo: replyHandler)
            
        } else {
            
            radio!.send(kCwxInsertCmd + "\(index) \"" + msg + "\"", replyTo: replyHandler)
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
            
            radio!.send(kCwxMacroCmd + "send \(index) \(block)", replyTo: replyHandler)
            
        } else {
            
            radio!.send(kCwxMacroCmd + "send \(index)", replyTo: replyHandler)
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
        
        radio!.send(kCwxMacroCmd + "save \(index+1)" + " \"" + msg + "\"")
        
        return true
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - Other Public methods
    
    /// Get the specified Cwx Macro
    ///
    ///     NOTE:
    ///         Macros are numbered 0..<kMaxNumberOfMacros internally
    ///         Macros are numbered 1...kMaxNumberOfMacros in commands
    ///
    /// - Parameters:
    ///   - index:              the index of the macro
    ///   - macro:              on return, contains the text of the macro
    /// - Returns:              true if found, false otherwise
    ///
    public func getMacro(index: Int, macro: inout String) -> Bool {
        
        if index < 0 || index > kMaxNumberOfMacros - 1 { return false }
        
        macro = macros[index]
        
        return true
    }
    
    // --------------------------------------------------------------------------------
    // MARK: - Cwx Reply Handler
    
    /// Process a Cwx command reply
    ///
    /// - Parameters:
    ///   - command:        the original command
    ///   - seqNum:         the Sequence Number of the original command
    ///   - responseValue:  the response value
    ///   - reply:          the reply
    ///
    func replyHandler(_ command: String, seqNum: String, responseValue: String, reply: String) {
        
        // if a block was specified for the "cwx send" command the response is "charPos,block"
        // if no block was given the response is "charPos"
        let values = reply.components(separatedBy: ",")
        
        let components = values.count
        
        // zero or anything greater than 2 is an error, log it and ignore the Reply
        guard components == 1 || components == 2 else {
            
            _log.msg(command + ", Invalid reply", level: .warning, function: #function, file: #file, line: #line)
            return
        }
        // get the character position
        let charPos = Int(values[0])

        // not an integer, log it and ignore the Reply
        guard charPos != nil else {
            
            _log.msg(command + ", Invalid character position", level: .warning, function: #function, file: #file, line: #line)
            return
        }
        
        if components == 1 {
            
            // 1 component - no block number
            
            // inform the Event Handler (if any), use 0 as a block identifier
            messageQueuedEventHandler?(charPos!, 0)
        
        } else {
            
            // 2 components - get the block number
            let block = Int(values[1])
            
            // not an integer, log it and ignore the Reply
            guard block != nil else {

                _log.msg(command + ", Invalid block", level: .warning, function: #function, file: #file, line: #line)
                return
            }
            // inform the Event Handler (if any)
            messageQueuedEventHandler?(charPos!, block!)
        }
    }

    // ------------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Undo any changes made to a Macro string by the fixString method on Radio
    ///
    /// - parameter string:     a String processed by fixString
    ///
    /// - returns:              the String after undoing the fixString changes
    ///
    private func unfixString(_ string: String) -> String {
        var newString: String = ""
        
        for char in string.characters {
            
            if char == "\u{007F}" {
                newString += " "
            
            } else if char == "*" {
                newString += "="
            
            } else {
                newString.append(char)
            }
        }
        return newString
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - KeyValueParser protocol methods
    
    /// Parse Cwx key/value pairs, called by Radio, executes on the radioQ
    ///
    /// - parameter keyValues:  array of Key/Value tuples
    ///
    public func parseKeyValues(_ keyValues: Radio.KeyValuesArray)  {
        
        // process each key/value pair, <key=value>
        for kv in keyValues {

            // is it a Macro?
            if kv.key.hasPrefix("macro") && kv.key.lengthOfBytes(using: String.Encoding.ascii) > 5 {
                
                // YES, get the index
                let index = Int(kv.key.substring(from: kv.key.characters.index(kv.key.startIndex, offsetBy: 5))) ?? 0
                
                // ignore invalid indexes
                if index < 1 || index > kMaxNumberOfMacros { continue }
                
                // update the macro after "unFixing" the string
                macros[index - 1] = unfixString(kv.value)
                
            } else {
                
                // Check for Unknown token
                guard let token = Token(rawValue: kv.key.lowercased()) else {
                    
                    // unknown token, log it and ignore the token
                     _log.msg("Unknown token - \(kv.key)", level: .debug, function: #function, file: #file, line: #line)
                    continue
                }
                
                // get the String, Bool and Integer versions of the value
                let sValue = kv.value.replacingOccurrences(of: "\"", with:"") as String
                let bValue = kv.value.bValue()
                let iValue = kv.value.iValue()
                
                // Known tokens, in alphabetical order
                switch token {
                    
                case .breakInDelay:
                    willChangeValue(forKey: "delay")
                    _delay = iValue
                    didChangeValue(forKey: "delay")
                
                case .erase:
                    let values = sValue.components(separatedBy: ",")
                    if values.count != 2 { break }
                    let start = Int(values[0])
                    let stop = Int(values[1])
                    if let start = start, let stop = stop {
                        // inform the Event Handler (if any)
                        eraseSentEventHandler?(start, stop)
                    }

                case .qskEnabled:
                    willChangeValue(forKey: "qskEnabled")
                    _qskEnabled = bValue
                    didChangeValue(forKey: "qskEnabled")
                    
                case .sent:
                    // inform the Event Handler (if any)
                    charSentEventHandler?(iValue)
                
                case .speed:
                    willChangeValue(forKey: "speed")
                    _speed = iValue
                    didChangeValue(forKey: "speed")
                }
            }
        }
    }
}

// --------------------------------------------------------------------------------
// MARK: - Cwx Class extensions
//              - Synchronized internal properties
//              - Dynamic public properties
//              - Opus message enum
// --------------------------------------------------------------------------------

extension Cwx {
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties - with synchronization
    
    // listed in alphabetical order
    fileprivate var _delay: Int {
        get { return _cwxQ.sync { __delay } }
        set { _cwxQ.sync(flags: .barrier) { __delay = newValue } } }
    
    fileprivate var _qskEnabled: Bool {
        get { return _cwxQ.sync { __qskEnabled } }
        set { _cwxQ.sync(flags: .barrier) { __qskEnabled = newValue } } }
    
    fileprivate var _speed: Int {
        get { return _cwxQ.sync { __speed } }
        set { _cwxQ.sync(flags: .barrier) { __speed = newValue } } }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant with Radio update
    
    // listed in alphabetical order
    dynamic public var delay: Int {
        get { return _delay }
        set { if _delay != newValue { let value = newValue.bound(kMinDelayMs, kMaxDelayMs) ; if _delay != value  { _delay = value ; radio!.send(kCwxCmd + "delay \(value)") } } } }
    
    dynamic public var qskEnabled: Bool {
        get { return _qskEnabled }
        set { if _qskEnabled != newValue { _qskEnabled = newValue ; radio!.send(kCwxCmd + "qsk_enabled \(newValue.asNumber())") } } }
    
    dynamic public var speed: Int {
        get { return _speed }
        set { if _speed != newValue { let value = newValue.bound(kMinSpeed, kMaxSpeed) ; if _speed != value  { _speed = value ; radio!.send(kCwxCmd + "wpm \(value)") } } } }
    
    // ----------------------------------------------------------------------------
    // Mark: - Tokens for Cwx messages (only populate values that != case value)
    
    enum Token : String {
        case breakInDelay = "break_in_delay"
        case erase
        case qskEnabled = "qsk_enabled"
        case sent
        case speed = "wpm"
    }

}
