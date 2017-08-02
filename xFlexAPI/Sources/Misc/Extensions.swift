//
//  Extensions.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 8/15/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Foundation

// ----------------------------------------------------------------------------
// MARK: - Date

public extension Date {
    
    /// Create a Date/Time in the local time zone
    ///
    /// - Returns: a DateTime string
    ///
    func currentTimeZoneDate() -> String {
        let dtf = DateFormatter()
        dtf.timeZone = TimeZone.current
        dtf.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        return dtf.string(from: self)
    }
}

// ----------------------------------------------------------------------------
// MARK: - NotificationCenter

public extension NotificationCenter {
    
    /// post a Notification by Name
    ///
    /// - Parameters:
    ///   - notification:   Notification Name
    ///   - object:         associated object
    ///
    public class func post(_ name: String, object: Any?) {
        
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: name), object: object)
        
    }
    /// post a Notification by Type
    ///
    /// - Parameters:
    ///   - notification:   Notification Type
    ///   - object:         associated object
    ///
    public class func post(_ notification: NotificationType, object: Any?) {
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: notification.rawValue), object: object)
        
    }
    /// setup a Notification Observer by Name
    ///
    /// - Parameters:
    ///   - observer:       the object receiving Notifications
    ///   - selector:       a Selector to receive the Notification
    ///   - type:           Notification name
    ///   - object:         associated object (if any)
    ///
    public class func makeObserver(_ observer: Any, with selector: Selector, of name: String, object: Any?) {
        
        NotificationCenter.default.addObserver(observer, selector: selector, name: NSNotification.Name(rawValue: name), object: object)
    }
    /// setup a Notification Observer by Type
    ///
    /// - Parameters:
    ///   - observer:       the object receiving Notifications
    ///   - selector:       a Selector to receive the Notification
    ///   - type:           Notification type
    ///   - object:         associated object (if any)
    ///
    public class func makeObserver(_ observer: Any, with selector: Selector, of type: NotificationType, object: Any?) {
        
        NotificationCenter.default.addObserver(observer, selector: selector, name: NSNotification.Name(rawValue: type.rawValue), object: object)
    }
    /// remove a Notification Observer by Type
    ///
    /// - Parameters:
    ///   - observer:       the object receiving Notifications
    ///   - type:           Notification type
    ///   - object:         associated object (if any)
    ///
    public class func deleteObserver(_ observer: Any, of type: NotificationType, object: Any?) {
        
        NotificationCenter.default.removeObserver(observer, name: NSNotification.Name(rawValue: type.rawValue), object: object)
    }
}

// ----------------------------------------------------------------------------
// MARK: - Sequence Type

public extension Sequence {

    /// Find an element in an array
    ///
    /// - Parameters:
    ///   - match:      comparison closure
    /// - Returns:      the element (or nil)
    ///
    func findElement(_ match:(Iterator.Element)->Bool) -> Iterator.Element? {
        
        for element in self where match(element) {
            return element
        }
        return nil
    }
}

// ----------------------------------------------------------------------------
// MARK: - String

public extension String {

    /// Convert a Mhz string to an Hz Int
    ///
    /// - Returns:      the Int equivalent
    ///
    func mhzToHz() -> Int {
        return Int( (Double(self) ?? 0) * 1_000_000 )
    }
    /// Return the Integer value (or 0 if invalid)
    ///
    /// - Returns:      the Int equivalent
    ///
    func iValue() -> Int {
        return Int(self) ?? 0
    }
    /// Return the Bool value (or false if invalid)
    ///
    /// - Returns:      a Bool equivalent
    ///
    func bValue() -> Bool {
        return (Int(self) ?? 0) == 1 ? true : false
    }
    /// Return the Float value (or 0 if invalid)
    ///
    /// - Returns:      a Float equivalent
    ///
    func fValue() -> Float {
        return Float(self) ?? 0
    }
    /// Return the Double value (or 0 if invalid)
    ///
    /// - Returns:      a Double equivalent
    ///
    func dValue() -> Double {
        return Double(self) ?? 0
    }
    /// Replace spaces with a specified value
    ///
    /// - Parameters:
    ///   - value:      the String to replace spaces
    /// - Returns:      the adjusted String
    ///
    func replacingSpacesWith(_ value: String) -> String {
        return self.replacingOccurrences(of: " ", with: value)
    }
}

// ----------------------------------------------------------------------------
// MARK: - Bool

public extension Bool {

    /// Return "1" / "0" for true / false Booleans
    ///
    /// - Returns:      a String
    ///
    func asNumber() -> String {
        return (self ? "1" : "0")
    }
    /// Return "True" / "False" Strings for true / false Booleans
    ///
    /// - Returns:      a String
    ///
    func asString() -> String {
        return (self ? "True" : "False")
    }
    /// Return "T" / "F" Strings for true / false Booleans
    ///
    /// - Returns:      a String
    ///
    func asLetter() -> String {
        return (self ? "T" : "F")
    }
}

// ----------------------------------------------------------------------------
// MARK: - Int

public extension Int {
    
    /// Convert an Int Hz value to a Mhz string
    ///
    /// - Returns:      the String equivalent
    ///
    func hzToMhz() -> String {
        
        // convert to a String with up to 2 leading & with 6 trailing places
        return String(format: "%02.6f", Float(self) / 1_000_000.0)
    }
    /// Determine if a value is between two other values (inclusive)
    ///
    /// - Parameters:
    ///   - value1:     low value (may be + or -)
    ///   - value2:     high value (may be + or -)
    /// - Returns:      true - self within two values
    ///
    func within(_ value1: Int, _ value2: Int) -> Bool {

        return (self >= value1) && (self <= value2)
    }

    /// Force a value to be between two other values (inclusive)
    ///
    /// - Parameters:
    ///   - value1:     the Minimum
    ///   - value2:     the Maximum
    /// - Returns:      the coerced value
    ///
    func bound(_ value1: Int, _ value2: Int) -> Int {
        let newValue = self < value1 ? value1 : self
        return newValue > value2 ? value2 : newValue
    }
}

// ----------------------------------------------------------------------------
// MARK: - CGFloat

public extension CGFloat {

    /// Force a CGFloat to be within a min / max value range
    ///
    /// - Parameters:
    ///   - min:        min CGFloat value
    ///   - max:        max CGFloat value
    /// - Returns:      adjusted value
    ///
    func bracket(_ min: CGFloat, _ max: CGFloat) -> CGFloat {
        
        var value = self
        if self < min { value = min }
        if self > max { value = max }
        return value
    }
    /// Create a CGFloat from a String
    ///
    /// - Parameters:
    ///   - string:     a String
    ///
    /// - Returns:      CGFloat value of String or 0
    ///
    init(_ string: String) {
        
        self = CGFloat(Float(string) ?? 0)
    }
    /// Format a String with the value of a CGFloat
    ///
    /// - Parameters:
    ///   - width:      number of digits before the decimal point
    ///   - precision:  number of digits after the decimal point
    ///   - divisor:    divisor
    /// - Returns:      a String representation of the CGFloat
    ///
    private func floatToString(width: Int, precision: Int, divisor: CGFloat) -> String {
        
        return String(format: "%\(width).\(precision)f", self / divisor)
    }
}
