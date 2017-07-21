//
//  MicAudioStreamCommands.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 7/19/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - MicAudioStream Class extensions
//              - Dynamic public properties that send commands to the Radio
//              - MicAudioStream message enum
// --------------------------------------------------------------------------------

extension MicAudioStream {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (with message sent to Radio)
    
        // ----- NONE -----
    
    // ----------------------------------------------------------------------------
    // MARK: - Tokens for MicAudioStream messages
    
    internal enum MicAudioStreamToken: String {
        case inUse = "in_use"
        case ip
        case port
    }
    
}