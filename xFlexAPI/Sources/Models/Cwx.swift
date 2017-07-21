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
//
//      creates a Cwx instance to be used by a Client to support the
//      rendering of a Cwx
//
// --------------------------------------------------------------------------------

public final class Cwx : NSObject, KeyValueParser {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    internal var macros: [String]
    public var messageQueuedEventHandler: ((_ sequence: Int, _ bufferIndex: Int) -> Void)?
    public var charSentEventHandler: ((_ index: Int) -> Void)?
    public var eraseSentEventHandler: ((_ start: Int, _ stop: Int) -> Void)?
    
    // ------------------------------------------------------------------------------
    // MARK: - Internal properties
    
    internal var _radio: Radio?                         // The Radio that owns this Cwx
    internal let kMinDelayMs = 0                        // Min delay (ms)
    internal let kMaxDelayMs = 2000                     // Max delay (ms)
    internal let kMinSpeed = 5                          // Min speed (wpm)
    internal let kMaxSpeed = 100                        // Max speed (wpm)
    internal let kMaxNumberOfMacros = 12                // Max number of macros
    internal let kCwxCmd = "cwx "                       // Command prefixes
    internal let kCwxInsertCmd = "cwx insert "
    internal let kCwxMacroCmd = "cwx macro "
    internal let kCwxSendCmd = "cwx send "
    
    // ------------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _cwxQ: DispatchQueue                // GCD queue that guards this object
    fileprivate let _log = Log.sharedInstance           // shared log
    fileprivate let kNoError = "0"                      // Response without error

    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    //                                                                                                  //
    fileprivate var __breakInDelay = 0                  // BreakIn delay                                //
    fileprivate var __qskEnabled = false                // QSK Enabled                                  //
    fileprivate var __wpm = 0                           // Speed (wpm)                                  //
    //                                                                                                  //
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    
    // ------------------------------------------------------------------------------
    // MARK: - Initialization
    
    init(radio: Radio, queue: DispatchQueue) {
        
        self._radio = radio
        self._cwxQ = queue
        macros = [String](repeating: "", count: kMaxNumberOfMacros)
        
        super.init()
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - Public methods
    
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
    /// - Parameters:
    ///   - string:         a String processed by fixString
    ///
    /// - Returns:          the String after undoing the fixString changes
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
    /// - Parameters:
    ///   - keyValues:      array of Key/Value tuples
    ///
    func parseKeyValues(_ keyValues: Radio.KeyValuesArray)  {
        
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
                guard let token = CwxToken(rawValue: kv.key.lowercased()) else {
                    
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
                    willChangeValue(forKey: "breakInDelay")
                    _breakInDelay = iValue
                    didChangeValue(forKey: "breakInDelay")
                
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
                
                case .wpm:
                    willChangeValue(forKey: "wpm")
                    _wpm = iValue
                    didChangeValue(forKey: "wpm")
                }
            }
        }
    }
}

// --------------------------------------------------------------------------------
// MARK: - Cwx Class extensions
//              - Synchronized internal properties
//              - Public properties, no message to Radio
// --------------------------------------------------------------------------------

extension Cwx {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties - with synchronization
    
    // listed in alphabetical order
    internal var _breakInDelay: Int {
        get { return _cwxQ.sync { __breakInDelay } }
        set { _cwxQ.sync(flags: .barrier) { __breakInDelay = newValue } } }
    
    internal var _qskEnabled: Bool {
        get { return _cwxQ.sync { __qskEnabled } }
        set { _cwxQ.sync(flags: .barrier) { __qskEnabled = newValue } } }
    
    internal var _wpm: Int {
        get { return _cwxQ.sync { __wpm } }
        set { _cwxQ.sync(flags: .barrier) { __wpm = newValue } } }
    
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (no message to Radio)
    
        // ----- None -----
    

}
