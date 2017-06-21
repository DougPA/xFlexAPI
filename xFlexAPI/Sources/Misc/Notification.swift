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
    
    case audioStreamInitialized
    case audioStreamWillBeRemoved
    
    case clientDidConnect
    case clientDidDisconnect
    
    case commandEntryWasAdded
    
    case globalProfileChanged
    case globalProfileCreated
    case globalProfileRemoved
    case globalProfileUpdated
    
    case guiConnectionEstablished
    
    case iqStreamInitialized
    case iqStreamShouldBeRemoved
    
    case logEntryWasAdded
    
    case memoryAdded
    case memoryInitialized
    case memoryWillBeRemoved
    
    case meterAdded
    case meterInitialized
    case meterUpdated
    case meterWillBeRemoved
    
    case micAudioStreamInitialized
    case micAudioStreamWillBeRemoved

    case opusAdded
    case opusInitialized
    case opusWillBeRemoved
    
    case panadapterInitialized
    case panadapterWillBeRemoved
    
    case radioInitialized
    
    case radiosAvailable
    
    case replyHandlerWillBeRemoved
    
    case sliceInitialized
    case sliceShouldBeRemoved
    
    case tcpDidConnect
    case tcpDidDisconnect
    case tcpPingStarted
    case tcpPingTimeout
    case tcpWillDisconnect
    
    case tnfInitialized
    case tnfShouldBeRemoved
    
    case txAudioStreamInitialized
    case txAudioStreamWillBeRemoved

    case txProfileChanged
    case txProfileCreated
    case txProfileRemoved
    case txProfileUpdated
    
    case udpDidBind
    
    case waterfallInitialized
    case waterfallWillBeRemoved
}

