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
    // MARK: - Public properties
    
    public var lastSeen: Date               // data/time last broadcast from Radio
    
    public var callsign: String?            // user assigned call sign
    public var firmwareVersion: String?     // Radio firmware version (e.g. 2.0.1.17)
    public var inUseHost: String?           //
    public var inUseIp: String?             //
    public var ipAddress: String            // IP Address (dotted decimal)
    public var maxLicensedVersion: String?  // Highest licensed version
    public var model: String                // Radio model (e.g. FLEX-6500)
    public var name: String?                //
    public var nickname: String?            // user assigned Radio name
    public var port: Int                    // port # broadcast received on
    public var protocolVersion: String?     // e.g. 2.0.0.1
    public var radioLicenseId: String?      // The current License of the Radio
    public var requiresAdditionalLicense: String? // License needed?
    public var serialNumber: String         // serial number
    public var status: String?              // available, in_use, connected, update, etc.
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate let _log = Log.sharedInstance           // shared Log

    fileprivate let kLastSeen = "lastSeen"
    fileprivate let kCallsign = "callsign"
    fileprivate let kFirmwareVersion = "firmwareVersion"
    fileprivate let kInUseHost = "inUseHost"
    fileprivate let kIpAddress = "ipAddress"
    fileprivate let kMaxLicensedVersion = "maxLicensedVersion"
    fileprivate let kModel = "model"
    fileprivate let kName = "name"
    fileprivate let kNickname = "nickname"
    fileprivate let kPort = "port"
    fileprivate let kProtocolVersion = "protocolVersion"
    fileprivate let kRadioLicenseId = "radioLicenseId"
    fileprivate let kRequiresAdditionalLicense = "requiresAdditionalLicense"
    fileprivate let kSerialNumber = "serialNumber"
    fileprivate let kStatus = "status"
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    /// Initialize an empty RadioParameters struct
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
    /// Initialize a RadioParameters instance from a dictionary
    ///
    /// - Parameters:
    ///   - dict:           a Dictionary of Values
    ///
    public init(_ dict: [String : Any]) {
        
        // lastSeen will be "Now"
        self.lastSeen = Date()
        
        self.callsign = dict[kCallsign] as? String ?? ""
        self.firmwareVersion = dict[kFirmwareVersion] as? String ?? ""
        self.inUseHost = dict[kInUseHost] as? String ?? ""
        self.inUseIp = dict[kInUseHost] as? String ?? ""
        self.ipAddress = dict[kIpAddress] as? String ?? ""
        self.maxLicensedVersion = dict[kMaxLicensedVersion] as? String ?? ""
        self.model = dict[kModel] as? String ?? ""
        self.name = dict[kName] as? String ?? ""
        self.nickname = dict[kNickname] as? String ?? ""
        self.port = dict[kPort] as? Int ?? 0
        self.protocolVersion = dict[kProtocolVersion] as? String ?? ""
        self.radioLicenseId = dict[kRadioLicenseId] as? String ?? ""
        self.requiresAdditionalLicense = dict[kRequiresAdditionalLicense] as? String ?? ""
        self.serialNumber = dict[kSerialNumber] as? String ?? ""
        self.status = dict[kStatus] as? String ?? ""
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Static methods
    
    /// Returns a Boolean value indicating whether two RadioParameter instances are equal.
    ///         Equality is defined as equal serialNumbers
    ///
    /// - Parameters:
    ///   - lhs:            A value to compare.
    ///   - rhs:            Another value to compare.
    ///
    public static func ==(lhs: RadioParameters, rhs: RadioParameters) -> Bool {
        return lhs.serialNumber == rhs.serialNumber
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    public func dictFromParams() -> [String : Any ] {

        var dict = [String : Any]()
        
        dict[kCallsign] = self.callsign
        dict[kFirmwareVersion] = self.firmwareVersion
        dict[kInUseHost] = self.inUseHost
        dict[kInUseHost] = self.inUseIp
        dict[kIpAddress] = self.ipAddress
        dict[kMaxLicensedVersion] = self.maxLicensedVersion
        dict[kModel] = self.model
        dict[kName] = self.name
        dict[kNickname] = self.nickname
        dict[kPort] = self.port
        dict[kProtocolVersion] = self.protocolVersion
        dict[kRadioLicenseId] = self.radioLicenseId
        dict[kRequiresAdditionalLicense] = self.requiresAdditionalLicense
        dict[kSerialNumber] = self.serialNumber
        dict[kStatus] = self.status
        
        return dict
    }
    ///  Return a String value given a property name
    ///
    /// - Parameters:
    ///   - id:         a Property Name
    /// - Returns:      String value of the Property
    ///
    public func valueForName(_ propertyName: String) -> String? {
        
        switch propertyName {
            
        case kCallsign:
            return callsign
            
        case kFirmwareVersion:
            return firmwareVersion
            
        case kInUseHost:
            return inUseHost
            
        case kInUseHost:
            return inUseIp
            
        case kIpAddress:
            return ipAddress
            
        case kLastSeen:
            return lastSeen.description
            
        case kMaxLicensedVersion:
            return maxLicensedVersion
            
        case kModel:
            return model
            
        case kName:
            return name
            
        case kNickname:
            return nickname
            
        case kPort:
            return port.description
            
        case kProtocolVersion:
            return protocolVersion
            
        case kRadioLicenseId:
            return radioLicenseId
            
        case kRequiresAdditionalLicense:
            return requiresAdditionalLicense
            
        case kSerialNumber:
            return serialNumber
            
        case kStatus:
            return status
            
        default:
            return "Unknown"
        }
    }
}
