//
//  RadioParameters.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 12/19/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - RadioParameters implementation
//
//      structure used internally to represent a Radio (hardware) instance
//
// --------------------------------------------------------------------------------

public final class RadioParameters : Equatable {
    
    // ----------------------------------------------------------------------------
    // MARK: - Static methods
    
    /// Create a RadioParameters instance from a valuesArray
    ///
    /// - Parameter valuesArray: an array of Values
    /// - Returns: a RadioParameters instance
    ///
    public static func parametersFromArray(valuesArray: [String]) -> RadioParameters {
        
        // lastSeen will be "Now"
        let params = RadioParameters(lastSeen: Date())
        
        // other values are derived from the array
        params.ipAddress = valuesArray[0]
        params.port = Int(valuesArray[1]) ?? 0
        params.model = valuesArray[2]
        params.serialNumber = valuesArray[3]
        params.name = valuesArray[4]
        params.callsign = valuesArray[5]
        params.protocolVersion = valuesArray[6]
        params.firmwareVersion = valuesArray[7]
        params.status = valuesArray[8]
        params.nickname = valuesArray[9]
        params.inUseIp = valuesArray[10]
        params.inUseHost = valuesArray[11]
        
        return params
    }
    /// Returns a Boolean value indicating whether two RadioParameter instances are equal.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    ///
    public static func ==(lhs: RadioParameters, rhs: RadioParameters) -> Bool {
        return lhs.serialNumber == rhs.serialNumber && lhs.ipAddress == rhs.ipAddress
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties

    public var lastSeen: Date               // data/time last udp from Radio
    public var ipAddress: String            // IP Address (dotted decimal)
    public var port: Int                    // port # broadcast received on
    public var model: String                // Radio model (e.g. FLEX-6500)
    public var serialNumber: String         // Radio Serial #
    public var name: String?                // ??
    public var callsign: String?            // user assigned call sign
    public var protocolVersion: String?     // currently (2016) 2.0.0.0
    public var firmwareVersion: String?     // Radio firmware version (e.g. 1.9.13.89)
    public var status: String?              // available, connected, update, etc.
    public var nickname: String?            // user assigned Radio name
    public var inUseIp: String?             // ??
    public var inUseHost: String?           // ??

    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    /// Initialize a RadioParameters struct
    ///
    /// - parameter lastSeen: the DateTime
    ///
    public init(lastSeen: Date = Date(), ipAddress: String = "", port: Int = 0, model: String = "", serialNumber: String = "") {
        
        self.lastSeen = lastSeen
        self.ipAddress = ipAddress
        self.port = port
        self.model = model
        self.serialNumber = serialNumber
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    ///  Return a String value given a property name
    ///
    /// - parameter id: a Property Name
    ///
    /// - returns: String value of the Property
    ///
    public func valueForName(_ name: String) -> String? {
        
        switch name {
            
        case "ipAddress":
            return ipAddress
            
        case "port":
            return port.description
            
        case "model":
            return model
            
        case "serialNumber":
            return serialNumber
            
        case "name":
            return name
            
        case "callsign":
            return callsign
            
        case "protocolVersion":
            return protocolVersion
            
        case "firmwareVersion":
            return firmwareVersion
            
        case "status":
            return status
            
        case "lastSeen":
            return lastSeen.description
            
        case "nickname":
            return nickname
            
        case "inUseIp":
            return inUseIp
            
        case "inUseHost":
            return inUseHost
            
        default:
            return "Unknown"
        }
    }
    /// Return an array containing the Radio Parameters
    ///
    /// - Returns: an array of values
    ///
    public func valuesArray() -> [String] {
        
        var values = [String]()
        
        // all values except "lastSeen"
        values.append(ipAddress)
        values.append(port.description)
        values.append(model)
        values.append(serialNumber)
        values.append(name ?? "")
        values.append(callsign ?? "")
        values.append(protocolVersion ?? "")
        values.append(firmwareVersion ?? "")
        values.append(status ?? "")
        values.append(nickname ?? "")
        values.append(inUseIp ?? "")
        values.append(inUseHost ?? "")
        
        return values
    }
}
