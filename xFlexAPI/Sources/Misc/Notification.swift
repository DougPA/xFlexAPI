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
    
    case memoryHasBeenAdded
//    case memoryInitialized
    case memoryShouldBeRemoved
    
//    case meterAdded
    case meterHasBeenAdded
    case meterShouldBeRemoved
    case meterUpdated
    
    case micAudioStreamInitialized
    case micAudioStreamWillBeRemoved

    case opusHasBeenAdded
    case opusShouldBeRemoved
    
    case panadapterHasBeenAdded
    case panadapterShouldBeRemoved
    
    case radioInitialized
    
    case radiosAvailable
    
    case replyHandlerWillBeRemoved
    
    case sliceHasBeenAdded
    case sliceShouldBeRemoved
    
    case tcpDidConnect
    case tcpDidDisconnect
    case tcpPingStarted
    case tcpPingTimeout
    case tcpWillDisconnect
    
    case tnfHasBeenAdded
    case tnfShouldBeRemoved
    
    case txAudioStreamInitialized
    case txAudioStreamWillBeRemoved

    case txProfileChanged
    case txProfileCreated
    case txProfileRemoved
    case txProfileUpdated
    
    case udpDidBind
    
    case waterfallHasBeenAdded
    case waterfallShouldBeRemoved
}

