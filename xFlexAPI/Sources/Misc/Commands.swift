//
//  Commands.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 7/10/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

final public class Commands {
    
    private let _radio: Radio!
    
    private let kAntListCmd = Commands.antList.rawValue              // Text of command messages
    private let kAtuCmd = "atu "
    private let kClientCmd = Commands.clientProgram.rawValue
    private let kCwCmd = "cw "
    private let kDisplayPanCmd = "display pan "
    private let kInfoCmd = Commands.info.rawValue
    private let kInterlockCmd = "interlock "
    private let kMeterListCmd = Commands.meterList.rawValue
    private let kMicCmd = "mic "
    private let kMicListCmd = Commands.micList.rawValue
    private let kMicStreamCreateCmd = "stream create daxmic"
    private let kMixerCmd = "mixer "
    private let kPingCmd = "ping"
    private let kProfileCmd = "profile "
    private let kRadioCmd = "radio "
    private let kRadioUptimeCmd = "radio uptime"
    private let kRemoteAudioCmd = "remote_audio "
    private let kSliceCmd = "slice "
    private let kSliceListCmd = "slice list"
    private let kStreamCreateCmd = "stream create "
    private let kStreamRemoveCmd = "stream remove "
    private let kTnfCommand = "tnf "
    private let kTransmitCmd = "transmit "
    private let kTransmitSetCmd = "transmit set "
    private let kVersionCmd = Commands.version.rawValue
    private let kXmitCmd = "xmit "
    private let kXvtrCmd = "xvtr "

    init(radio: Radio) {
        self._radio = radio
    }
    
    public func atuStart() { _radio.send(kAtuCmd + "start") }
    public func atuBypass() { _radio.send(kAtuCmd + "bypass") }
    public func createAudioStream(_ channel: String, callback: ReplyHandler? = nil) -> Bool {
        return _radio.sendWithCheck(kStreamCreateCmd + "dax=\(channel)", replyTo: callback)
    }
    
}
