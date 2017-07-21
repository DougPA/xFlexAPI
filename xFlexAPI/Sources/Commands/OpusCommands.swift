//
//  OpusCommands.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 7/19/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Opus Class extensions
//              - Dynamic public properties that send commands to the Radio
//              - Opus message enum
// --------------------------------------------------------------------------------

extension Opus {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant with Radio update
    
    // listed in alphabetical order
    @objc dynamic public var remoteRxOn: Bool {
        get { return _remoteRxOn }
        set { if _remoteRxOn != newValue { _remoteRxOn = newValue ; _radio!.send(kRemoteAudioCmd + OpusToken.remoteRxOn.rawValue + " \(newValue.asNumber())") } } }
    
    @objc dynamic public var remoteTxOn: Bool {
        get { return _remoteTxOn }
        set { if _remoteTxOn != newValue { _remoteTxOn = newValue ; _radio!.send(kRemoteAudioCmd + OpusToken.remoteTxOn.rawValue + " \(newValue.asNumber())") } } }
        
    // ----------------------------------------------------------------------------
    // MARK: - Tokens for Opus messages 
    
    internal enum OpusToken : String {
        case ipAddress = "ip"
        case port
        case remoteRxOn = "rx_on"
        case remoteTxOn = "tx_on"
        case rxStreamStopped = "opus_rx_stream_stopped"
    }

}
