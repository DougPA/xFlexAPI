//
//  MicAudioStreamCommands.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 7/19/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

extension MicAudioStream {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (with message sent to Radio) - checked


    // ----------------------------------------------------------------------------
    // MARK: - Tokens for MicAudioStream messages
    
    internal enum MicAudioStreamToken: String {
        case inUse = "in_use"
        case ip
        case port
    }
    
}
