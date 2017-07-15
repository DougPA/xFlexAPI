//
//  RadioCommands.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 7/14/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

extension Radio {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods that send commands to the Radio (hardware)
    
    // listed in alphabetical order
    
    // Antenna List
    public func antennaListRequest() {
        send(kAntListCmd, replyTo: replyHandler)
    }
    // ATU
    public func atuClear() {
        send(kAtuCmd + "clear")
    }
    public func atuStart() {
        send(kAtuCmd + "start")
    }
    public func atuBypass() {
        send(kAtuCmd + "bypass")
    }
    // Audio Stream
    public func audioStreamCreate(_ channel: String, callback: ReplyHandler? = nil) -> Bool {
        return sendWithCheck(kStreamCreateCmd + "dax" + "=\(channel)", replyTo: callback)
    }
    public func audioStreamRemove(_ id: String) -> Bool {
        return sendWithCheck(kStreamRemoveCmd + "0x\(id)")
    }
    // Iq Stream
    public func iqStreamCreate(_ channel: String, callback: ReplyHandler? = nil) -> Bool {
        return sendWithCheck(kStreamCreateCmd + "daxiq" + "=\(channel)", replyTo: callback)
    }
    public func iqStreamCreate(_ channel: String, ip: String, port: Int, callback: ReplyHandler? = nil) -> Bool {
        return sendWithCheck(kStreamCreateCmd + "daxiq" + "=\(channel) " + "ip" + "=\(ip) " + "port" + "=\(port)", replyTo: callback)
    }
    public func iqStreamRemove(_ id: String) {
        send(kStreamRemoveCmd + "0x\(id)")
    }
    // Memory
    public func memoryCreate() {
        send(kMemoryCreateCmd)
    }
    public func memoryRemove(_ id: MemoryId) {
        send(kMemoryRemoveCmd + "\(id)")
    }
    // Meter
    public func meterListRequest() {
        send(kMeterListCmd, replyTo: replyHandler)
    }
    // Mic Audio Stream
    public func micAudioStreamCreate(callback: ReplyHandler? = nil) -> Bool {
        return sendWithCheck(kMicStreamCreateCmd)
    }
    public func micAudioStreamRemove(id: String) {
        send(kStreamRemoveCmd + "0x\(id)")
    }
    // Mic List
    public func micListRequest() {
        send(kMicListCmd, replyTo: replyHandler)
    }
    /// Panafall
    public func panafallCreate(_ dimensions: CGSize) {
        if availablePanadapters > 0 {
            send(kDisplayPanCmd + "create x=\(dimensions.width) y=\(dimensions.height)", replyTo: replyHandler)
        }
    }
    public func panafallCreate(frequency: Int, antenna: String? = nil, dimensions: CGSize? = nil) {
        if availablePanadapters > 0 {
            
            var cmd = kDisplayPanCmd + "create freq" + "=\(frequency.hzToMhz())"
            if antenna != nil { cmd += " ant=" + "\(antenna!)" }
            if dimensions != nil { cmd += " x" + "=\(dimensions!.width)" + " y" + "=\(dimensions!.height)" }
            send(cmd, replyTo: replyHandler)
        }
    }
    public func panafallRemove(_ id: PanadapterId) {
        send(kDisplayPanCmd + " remove 0x\(id)")
    }
    // Profiles
    public func profileGlobalDelete(_ name: String) {
        send(kProfileCmd + ProfileToken.global.rawValue + " delete \"" + name + "\"")
    }
    public func profileGlobalSave(_ name: String) {
        send(kProfileCmd + ProfileToken.global.rawValue + " save \"" + name + "\"")
    }
    public func profileMicDelete(_ name: String) {
        send(kProfileCmd + ProfileToken.mic.rawValue + " delete \"" + name + "\"")
    }
    public func profileMicSave(_ name: String) {
        send(kProfileCmd + ProfileToken.mic.rawValue + " save \"" + name + "\"")
    }
    public func profileTransmitDelete(_ name: String) {
        send(kProfileCmd + "transmit" + " save \"" + name + "\"")
    }
    public func profileTransmitSave(_ name: String) {
        send(kProfileCmd + "transmit" + " save \"" + name + "\"")
    }
    // Remote Audio (Opus)
    public func remoteRxAudioRemove(_ value: Bool) {
        send(kRemoteAudioCmd + Opus.OpusToken.remoteRxOn.rawValue + " \(value.asNumber())")
    }
    public func remoteTxAudioRequest(_ value: Bool) {
        send(kRemoteAudioCmd + Opus.OpusToken.remoteTxOn.rawValue + "\(value.asNumber())")
    }
    // Reboot
    public func rebootRequest() {
        send(kRadioCmd + " reboot")
    }
    // Slice
    public func sliceCreate(frequency: Int, antenna: String, mode: String) { if availableSlices > 0 {
        send(kSliceCmd + "create \(frequency.hzToMhz()) \(antenna) \(mode)") } }
    public func sliceCreate(panadapter: Panadapter, frequency: Int = 0) { if availableSlices > 0 {
        send(kSliceCmd + "create pan" + "=0x\(panadapter.id) \(frequency == 0 ? "" : "freq" + "=\(frequency.hzToMhz())")") } }
    public func sliceRemove(_ id: SliceId) {
        send(kSliceCmd + "remove" + " \(id)")
    }
    public func sliceErrorRequest(_ id: SliceId) {
        send(kSliceCmd + "get_error" + " \(id)", replyTo: replyHandler)
    }
    public func sliceListRequest() {
        send(kSliceCmd + "list", replyTo: replyHandler)
    }
    // Tnf
    public func tnfCreate(frequency: Int, panadapter: Panadapter) {
        send(kTnfCreateCmd + "freq" + "=\(calcTnfFreq(frequency, panadapter).hzToMhz())")
    }
    public func tnfRemove(tnf: Tnf) {
        
        send(kTnfRemoveCmd + " \(tnf.id)")
        NC.post(.tnfWillBeRemoved, object: tnf as Any?)
        removeObject(tnf)
    }
    // Transmit
    public func transmitSet(_ value: Bool) {
        send(kXmitCmd + " \(value.asNumber())")
    }
    // Tx Audio Stream
    public func txAudioStreamCreate(callback: ReplyHandler? = nil) -> Bool {
        return sendWithCheck(kStreamCreateCmd + "daxtx", replyTo: callback)
    }
    public func txAudioStreamRemove(_ id: String) {
        send(kStreamRemoveCmd + "0x\(id)")
    }
    // Uptime
    public func uptimeRequest() {
        send(kRadioUptimeCmd, replyTo: replyHandler)
    }
    // Xvtr
    public func xvtrCreate(callback: ReplyHandler? = nil) -> Bool {
        return sendWithCheck(kXvtrCmd + "create", replyTo: callback)
    }
    public func xvtrRemove(_ id: String) {
        send(kXvtrCmd + "remove" + " \(id)")
    }
}
