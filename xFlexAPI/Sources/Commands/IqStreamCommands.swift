//
//  IqStreamCommands.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 7/20/17.
//  Copyright © 2017 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - IqStream Class extensions
//              - Dynamic public properties that send commands to the Radio
//              - IqStream message enum
// --------------------------------------------------------------------------------

extension IqStream {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (with message sent to Radio)
    
    @objc dynamic public var rate: Int {
        get { return _rate }
        set {
            if _rate != newValue {
                if newValue == 24000 || newValue == 48000 || newValue == 96000 || newValue == 192000 {
                    _rate = newValue
                    _radio?.send(kIqStreamCmd + "\(_daxIqChannel) " + IqStreamToken.rate.rawValue + "=\(_rate)")
                }
            }
        }
    }

    // ----------------------------------------------------------------------------
    // Mark: - Tokens for IqStream messages
    
    internal enum IqStreamToken: String {
        case available
        case capacity
        case daxIqChannel = "daxiq"
        case inUse = "in_use"
        case ip
        case pan
        case port
        case rate
        case streaming
    }
}
