//
//  MessageLevel.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 12/23/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Foundation

// ----------------------------------------------------------------------------
// MARK: - MessageLevel enum
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// MARK: - Comparable definition

public func <(lhs: MessageLevel, rhs: MessageLevel) -> Bool {
    
    return lhs.rawValue < rhs.rawValue
}

// ----------------------------------------------------------------------------
// MARK: - Equatable definition

public func ==(lhs: MessageLevel, rhs: MessageLevel) -> Bool {
    
    return lhs.rawValue == rhs.rawValue
}

// ----------------------------------------------------------------------------
// MARK: - MessageLevel Enum

public enum MessageLevel: Int, Comparable {
    
    /// MessageLevel values.
    ///      Changes to this list must be reflected below in allCases, color & name
    case token = -3, debug = -2, verbose = -1, info = 0, warning, error, fatal
    
    // ----------------------------------------------------------------------------
    // MARK: - Static methods
    
    /// Return an array of all MessageLevels
    ///
    static let allCases: [MessageLevel] = [.token, .debug, .verbose, .info, .warning, .error, .fatal]
    
    /// Return an array of MessageLevel values
    ///
    /// - returns: an array of all MessageLevels
    ///
    public static func values() -> [Int] {
        var values = [Int]()
        
        for messageLevel in allCases {
            values.append(messageLevel.rawValue)
        }
        return values
    }
    /// Return an array of MessageLevel names
    ///
    /// - returns: an array of the names of all MessageLevels
    ///
    public static func names() -> [String] {
        var names = [String]()
        
        for messageLevel in allCases {
            names.append(messageLevel.name)
        }
        return names
    }
    /// Return the MessageLevel of a Flex Command response
    ///
    /// - Parameter response: the response as a hex String
    /// - Returns: the equivalent MessageLevel
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
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    /// Return a Color for the current MessageLevel
    ///
    public var color: NSColor {
        // arbitrary color assignments
        switch self {
            
        case .fatal:    // Red
            return NSColor(srgbRed: 1.0, green: 0.0, blue: 0.0, alpha: 0.8)
            
        case .error:    // Red
            return NSColor(srgbRed: 1.0, green: 0.0, blue: 0.0, alpha: 0.4)
            
        case .warning:  // Yellow
            return NSColor(srgbRed: 1.0, green: 1.0, blue: 0.0, alpha: 0.3)
            
        case .info:     // Green
            return NSColor(srgbRed: 0.0, green: 1.0, blue: 0.0, alpha: 0.5)
            
        case .verbose:  // Light Green
            return NSColor(srgbRed: 0.0, green: 1.0, blue: 0.0, alpha: 0.2)
            
        case .debug:    // Dark Black
            return NSColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.2)
            
        case .token:    // Light Blue
            return NSColor(srgbRed: 0.0, green: 0.0, blue: 1.0, alpha: 0.2)
        }
    }
    /// Return a Name for the current MessageLevel
    ///
    public var name: String {
        switch self {
            
        case .token:
            return "Token"
            
        case .debug:
            return "Debug"
            
        case .verbose:
            return "Verbose"
            
        case .info:
            return "Info"
            
        case .warning:
            return "Warning"
            
        case .error:
            return "Error"
            
        case .fatal:
            return "Fatal"
        }
    }
}
