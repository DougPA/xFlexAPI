//
//  IqStreamCommands.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 7/20/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
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
    
        // ----- NONE -----
        
    // ----------------------------------------------------------------------------
    // Mark: - Tokens for IqStream messages
    
    internal enum IqStreamToken: String {
        case available
        case capacity
        case daxIqChannel = "daxiq"
        case ip
        case pan
        case port
        case rate
        case streaming
    }

}
