//
//  AudioStreamCommands.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 7/20/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - AudioStream Class extensions
//              - Dynamic public properties that send commands to the Radio
//              - AudioStream message enum
// --------------------------------------------------------------------------------

extension AudioStream {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (with message sent to Radio)
    
    // listed in alphabetical order
    @objc dynamic public var rxGain: Int {
        get { return _rxGain  }
        set {
            if _rxGain != newValue {
                let value = newValue.bound(0, 100)
                if _rxGain != value {
                    _rxGain = value
                    if _slice != nil {          // DL3LSM
                        _radio?.send(kAudioStreamCmd + "0x\(id) " + AudioStreamToken.slice.rawValue + " \(_slice!.id) " + "gain" + " \(value)")
                    }
                }
            }
        }
    }
    
    // ----------------------------------------------------------------------------
    // Mark: - Tokens for AudioStream messages
    
    internal enum AudioStreamToken: String {
        case daxChannel = "dax"
        case daxClients = "dax_clients"
        case inUse = "in_use"
        case ip
        case port
        case slice
    }

}
