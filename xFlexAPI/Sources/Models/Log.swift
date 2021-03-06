//
//  Log.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 9/6/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Protocols

public protocol LogHandler
{
    // method to process Log entries
    func msg(_ msg: String, level: MessageLevel, function: StaticString, file: StaticString, line: Int ) -> Void
}

public enum MessageLevel: Int {
    
    case debug = -2
    case verbose = -1
    case info = 0
    case warning = 1
    case error = 2
    case severe = 3
    
    /// Return the MessageLevel of a Flex Command response
    ///
    /// - Parameter response:   the Flex response as a hex String
    /// - Returns:              the equivalent xFlexAPI MessageLevel
    ///
    public static func from(_ response: String) -> MessageLevel {
        var value = MessageLevel.verbose            // "1" is converted to .verbose
        
        // is the response "informational"
        if response.characters.first != "1" {
            
            // NO, convert the hex String to an Int
            let number = Int(response, radix: 16) ?? 0
            
            // mask out the error status (bits 24-25) & slide right
            let bitValue =  ( number & 0x03000000 ) >> 24
            
            // convert to a Message Level
            value = MessageLevel(rawValue: bitValue)!
        }
        return value
    }
}

// ----------------------------------------------------------------------------
// MARK: - Log implementation
// ----------------------------------------------------------------------------

public final class Log {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    public var delegate: LogHandler?
    
    // ----------------------------------------------------------------------------
    // MARK: - Singleton
    
    /// Provide access to the Log singleton
    ///
    public static var sharedInstance = Log()
    
    private init() {
        // "private" prevents others from calling init()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    /// Create an entry in a Log (if any). May be called from any thread
    ///
    /// - Parameters:
    ///   - msg:        a message String
    ///   - level:      the severity level
    ///   - function:   the function where the message originated
    ///   - file:       the file where the message originated
    ///   - line:       the line where the message originated
    ///
    public func msg(_ msg: String, level: MessageLevel, function: StaticString, file: StaticString, line: Int ) {
        
        // pass the entry to the delegate (if any)
        delegate?.msg(msg, level: level, function: function, file: file, line: line )
    }
}
