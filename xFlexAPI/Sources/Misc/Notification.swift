//
//  Notification.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 1/4/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// ----------------------------------------------------------------------------
// MARK: - Notifications

public typealias NC = NotificationCenter

//
// Defined NotificationTypes
//      in alphabetical order
//
public enum NotificationType : String {
    
    case audioStreamHasBeenAdded
    case audioStreamWillBeRemoved
    
    case clientDidConnect
    case clientDidDisconnect
    
    case globalProfileChanged
    case globalProfileCreated
    case globalProfileRemoved
    case globalProfileUpdated
    
    case guiConnectionEstablished
    
    case iqStreamInitialized
    case iqStreamWillBeRemoved
    
    case memoryHasBeenAdded
    case memoryWillBeRemoved
    
    case meterHasBeenAdded
    case meterWillBeRemoved
    case meterUpdated
    
    case micAudioStreamHasBeenAdded
    case micAudioStreamWillBeRemoved

    case opusHasBeenAdded
    case opusWillBeRemoved
    
    case panadapterHasBeenAdded
    case panadapterWillBeRemoved
    
    case radioInitialized
    
    case radiosAvailable
    
    case sliceHasBeenAdded
    case sliceWillBeRemoved
    
    case tcpDidConnect
    case tcpDidDisconnect
    case tcpPingStarted
    case tcpPingTimeout
    case tcpWillDisconnect
    
    case tnfHasBeenAdded
    case tnfWillBeRemoved
    
    case txAudioStreamHasBeenAdded
    case txAudioStreamWillBeRemoved

    case txProfileChanged
    case txProfileCreated
    case txProfileRemoved
    case txProfileUpdated
    
    case udpDidBind
    
    case usbCableHasBeenAdded
    case usbCableWillBeRemoved
    
    case waterfallHasBeenAdded
    case waterfallWillBeRemoved
    
    case xvtrHasBeenAdded
    case xvtrWillBeRemoved
}

