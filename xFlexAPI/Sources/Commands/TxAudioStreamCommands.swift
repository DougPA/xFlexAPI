//
//  TxAudioStreamCommands.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 7/19/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - TxAudioStream Class extensions
//              - Dynamic public properties that send commands to the Radio
//              - TxAudioStream message enum
// --------------------------------------------------------------------------------

extension TxAudioStream {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (with message sent to Radio)
    
    // listed in alphabetical order
    @objc dynamic public var transmit: Bool {
        get { return _transmit  }
        set { if _transmit != newValue { _transmit = newValue ; _radio?.send(kDaxCmd + "tx" + " \(_transmit.asNumber())") } } }
    
    // ----------------------------------------------------------------------------
    // MARK: - Tokens for TxAudioStream messages 
    
    internal enum TxAudioStreamToken: String {
        case daxTx = "dax_tx"
        case inUse = "in_use"
        case ip
        case port
    }

}
