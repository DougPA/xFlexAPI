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
    /// - Parameters:
    ///   - valuesArray:    an array of Values
    /// - Returns:          a RadioParameters instance
    ///
    public static func parametersFromArray(valuesArray: [String]) -> RadioParameters {
        
        // lastSeen will be "Now"
        let params = RadioParameters(lastSeen: Date())
        
        // other values are derived from the array
        params.callsign = valuesArray[0]
        params.firmwareVersion = valuesArray[1]
        params.inUseHost = valuesArray[2]
        params.inUseIp = valuesArray[3]
        params.ipAddress = valuesArray[4]
        params.maxLicensedVersion = valuesArray[5]
        params.model = valuesArray[6]
        params.name = valuesArray[7]
        params.nickname = valuesArray[8]
        params.port = Int(valuesArray[9]) ?? 0
        params.protocolVersion = valuesArray[10]
        params.radioLicenseId = valuesArray[11]
        params.requiresAdditionalLicense = valuesArray[12]
        params.serialNumber = valuesArray[13]
        params.status = valuesArray[14]
        
        return params
    }
    /// Returns a Boolean value indicating whether two RadioParameter instances are equal.
    ///
    /// - Parameters:
    ///   - lhs:            A value to compare.
    ///   - rhs:            Another value to compare.
    ///
    public static func ==(lhs: RadioParameters, rhs: RadioParameters) -> Bool {
        return lhs.serialNumber == rhs.serialNumber && lhs.ipAddress == rhs.ipAddress
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties

    public var lastSeen: Date               // data/time last udp from Radio

    public var callsign: String?            // user assigned call sign
    public var firmwareVersion: String?     // Radio firmware version (e.g. 1.9.13.89)
    public var inUseHost: String?           // ??
    public var inUseIp: String?             // ??
    public var ipAddress: String            // IP Address (dotted decimal)
    public var maxLicensedVersion: String?  // Highest licensed version
    public var model: String                // Radio model (e.g. FLEX-6500)
    public var name: String?                // ??
    public var nickname: String?            // user assigned Radio name
    public var port: Int                    // port # broadcast received on
    public var protocolVersion: String?     // currently (2016) 2.0.0.0
    public var radioLicenseId: String?      // The current License of the Radio
    public var requiresAdditionalLicense: String? // License needed, 1=true, 0= false
    public var serialNumber: String         //
    public var status: String?              // available, connected, update, etc.

    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    /// Initialize a RadioParameters struct
    ///
    /// - Parameters:
    ///   - lastSeen:       the DateTime
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
    /// - Parameters:
    ///   - id:         a Property Name
    /// - Returns:      String value of the Property
    ///
    public func valueForName(_ propertyName: String) -> String? {
        
        switch propertyName {
            
        case "callsign":
            return callsign
            
        case "firmwareVersion":
            return firmwareVersion
            
        case "inUseHost":
            return inUseHost
            
        case "inUseIp":
            return inUseIp
            
        case "ipAddress":
            return ipAddress
            
        case "lastSeen":
            return lastSeen.description
            
        case "maxLicensedVersion":
            return maxLicensedVersion
            
        case "model":
            return model
            
        case "name":
            return name
            
        case "nickname":
            return nickname
            
        case "port":
            return port.description
            
        case "protocolVersion":
            return protocolVersion
            
        case "radioLicenseId":
            return radioLicenseId
            
        case "requiresAdditionalLicense":
            return requiresAdditionalLicense
            
        case "serialNumber":
            return serialNumber
            
        case "status":
            return status
            
        default:
            return "Unknown"
        }
    }
    /// Return an array containing the Radio Parameters
    ///
    /// - Returns:      an array of values
    ///
    public func valuesArray() -> [String] {
        
        var values = [String]()
        
        // all values except "lastSeen"
        values.append(callsign ?? "")
        values.append(firmwareVersion ?? "")
        values.append(inUseHost ?? "")
        values.append(inUseIp ?? "")
        values.append(ipAddress)
        values.append(maxLicensedVersion ?? "")
        values.append(model)
        values.append(name ?? "")
        values.append(nickname ?? "")
        values.append(port.description)
        values.append(protocolVersion ?? "")
        values.append(radioLicenseId ?? "")
        values.append(requiresAdditionalLicense ?? "")
        values.append(serialNumber)
        values.append(status ?? "")
        
        return values
    }
}
