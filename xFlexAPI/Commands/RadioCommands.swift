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
    
    // MARK: --- Antenna List ---
    
    /// Request a list of antenns
    ///
    public func antennaListRequest() {
        send(kAntListCmd, replyTo: replyHandler)
    }
    
    // MARK: --- ATU ---
    
    /// Clear the ATU
    ///
    public func atuClear() {
        send(kAtuCmd + "clear")
    }
    /// Start the ATU
    ///
    public func atuStart() {
        send(kAtuCmd + "start")
    }
    /// Bypass the ATU
    ///
    public func atuBypass() {
        send(kAtuCmd + "bypass")
    }
    
    // MARK: --- Audio Stream ---
    
    /// Create an Audio Stream
    ///
    /// - Parameters:
    ///   - channel:        DAX channel number
    ///   - callback:       ReplyHandler (optional)
    /// - Returns:          Success / Failure
    ///
    public func audioStreamCreate(_ channel: String, callback: ReplyHandler? = nil) -> Bool {
        return sendWithCheck(kStreamCreateCmd + "dax" + "=\(channel)", replyTo: callback)
    }
    /// Remove an Audio Stream
    ///
    /// - Parameter id:     Audio Stream Id
    /// - Returns:          Success / Failure
    ///
    public func audioStreamRemove(_ id: String) -> Bool {
        return sendWithCheck(kStreamRemoveCmd + "0x\(id)")
    }
    
    // MARK: --- Iq Stream ---
    
    /// Create an IQ Stream
    ///
    /// - Parameters:
    ///   - channel:        DAX channel number
    ///   - callback:       ReplyHandler (optional)
    /// - Returns:          Success / Failure
    ///
    public func iqStreamCreate(_ channel: String, callback: ReplyHandler? = nil) -> Bool {
        return sendWithCheck(kStreamCreateCmd + "daxiq" + "=\(channel)", replyTo: callback)
    }
    /// Create an IQ Stream
    ///
    /// - Parameters:
    ///   - channel:        DAX channel number
    ///   - ip:             ip address
    ///   - port:           port number
    ///   - callback:       ReplyHandler (optional)
    /// - Returns:          Success / Failure
    ///
    public func iqStreamCreate(_ channel: String, ip: String, port: Int, callback: ReplyHandler? = nil) -> Bool {
        return sendWithCheck(kStreamCreateCmd + "daxiq" + "=\(channel) " + "ip" + "=\(ip) " + "port" + "=\(port)", replyTo: callback)
    }
    /// Remove an IQ Stream
    ///
    /// - Parameter id:     IQ Stream Id
    ///
    public func iqStreamRemove(_ id: String) {
        send(kStreamRemoveCmd + "0x\(id)")
    }
    
    // MARK: --- Memory ---
    
    /// Create a Memory
    ///
    public func memoryCreate() {
        send(kMemoryCreateCmd)
    }
    /// Remove a Memory
    ///
    /// - Parameter id:     Memory Id
    ///
    public func memoryRemove(_ id: MemoryId) {
        send(kMemoryRemoveCmd + "\(id)")
    }
    
    // MARK: --- Meter ---
    
    /// Request a list of Meters
    ///
    public func meterListRequest() {
        send(kMeterListCmd, replyTo: replyHandler)
    }
    
    // MARK: --- Mic Audio Stream ---
    
    /// Create a Mic Audio Stream
    ///
    /// - Parameter callback:   ReplyHandler (optional)
    /// - Returns:              Success / Failure
    ///
    public func micAudioStreamCreate(callback: ReplyHandler? = nil) -> Bool {
        return sendWithCheck(kMicStreamCreateCmd)
    }
    /// Remove a Mic Audio Stream
    ///
    /// - Parameter id:         Mic Audio Stream Id
    ///
    public func micAudioStreamRemove(id: String) {
        send(kStreamRemoveCmd + "0x\(id)")
    }
    
    // MARK: --- Mic List ---
    
    /// Request a List of Mic sources
    ///
    public func micListRequest() {
        send(kMicListCmd, replyTo: replyHandler)
    }
    
    // MARK: --- Panafall ---
    
    /// Create a Panafall
    ///
    /// - Parameter dimensions:     Panafall dimensions
    ///
    public func panafallCreate(_ dimensions: CGSize) {
        if availablePanadapters > 0 {
            send(kDisplayPanCmd + "create x=\(dimensions.width) y=\(dimensions.height)", replyTo: replyHandler)
        }
    }
    /// Create a Panafall
    ///
    /// - Parameters:
    ///   - frequency:          selected frequency (Hz)
    ///   - antenna:            selected antenna
    ///   - dimensions:         Panafall dimensions
    ///
    public func panafallCreate(frequency: Int, antenna: String? = nil, dimensions: CGSize? = nil) {
        if availablePanadapters > 0 {
            
            var cmd = kDisplayPanCmd + "create freq" + "=\(frequency.hzToMhz())"
            if antenna != nil { cmd += " ant=" + "\(antenna!)" }
            if dimensions != nil { cmd += " x" + "=\(dimensions!.width)" + " y" + "=\(dimensions!.height)" }
            send(cmd, replyTo: replyHandler)
        }
    }
    /// Remove a Panafall
    ///
    /// - Parameter id:         Panafall Id
    ///
    public func panafallRemove(_ id: PanadapterId) {
        send(kDisplayPanCmd + " remove 0x\(id)")
    }
    
    // MARK: --- Profiles ---
    
    /// Delete a Global profile
    ///
    /// - Parameter name:       profile name
    ///
    public func profileGlobalDelete(_ name: String) {
        send(kProfileCmd + ProfileToken.global.rawValue + " delete \"" + name + "\"")
    }
    /// Save a Global profile
    ///
    /// - Parameter name:       profile name
    ///
    public func profileGlobalSave(_ name: String) {
        send(kProfileCmd + ProfileToken.global.rawValue + " save \"" + name + "\"")
    }
    /// Delete a Mic profile
    ///
    /// - Parameter name:       profile name
    ///
    public func profileMicDelete(_ name: String) {
        send(kProfileCmd + ProfileToken.mic.rawValue + " delete \"" + name + "\"")
    }
    /// Save a Mic profile
    ///
    /// - Parameter name:       profile name
    ///
    public func profileMicSave(_ name: String) {
        send(kProfileCmd + ProfileToken.mic.rawValue + " save \"" + name + "\"")
    }
    /// Delete a Transmit profile
    ///
    /// - Parameter name:       profile name
    ///
    public func profileTransmitDelete(_ name: String) {
        send(kProfileCmd + "transmit" + " save \"" + name + "\"")
    }
    /// Save a Transmit profile
    ///
    /// - Parameter name:       profile name
    ///
    public func profileTransmitSave(_ name: String) {
        send(kProfileCmd + "transmit" + " save \"" + name + "\"")
    }
    
    // MARK: --- Remote Audio (Opus) ---
    
    /// Turn Opus Rx On/Off
    ///
    /// - Parameter value:      On/Off
    ///
    public func remoteRxAudioRequest(_ value: Bool) {
        send(kRemoteAudioCmd + Opus.OpusToken.remoteRxOn.rawValue + " \(value.asNumber())")
    }
    public func remoteTxAudioRequest(_ value: Bool) {
        send(kRemoteAudioCmd + Opus.OpusToken.remoteTxOn.rawValue + "\(value.asNumber())")
    }
    // MARK: --- Reboot ---
    
    /// Reboot the Radio
    ///
    public func rebootRequest() {
        send(kRadioCmd + " reboot")
    }
    
    // MARK: --- Slice ---
    
    /// Create a new Slice
    ///
    /// - Parameters:
    ///   - frequency:          frequenct (Hz)
    ///   - antenna:            selected antenna
    ///   - mode:               selected mode
    ///
    public func sliceCreate(frequency: Int, antenna: String, mode: String) { if availableSlices > 0 {
        send(kSliceCmd + "create \(frequency.hzToMhz()) \(antenna) \(mode)") } }
    /// Create a new Slice
    ///
    /// - Parameters:
    ///   - panadapter:         selected panadapter
    ///   - frequency:          frequency (Hz)
    ///
    public func sliceCreate(panadapter: Panadapter, frequency: Int = 0) { if availableSlices > 0 {
        send(kSliceCmd + "create pan" + "=0x\(panadapter.id) \(frequency == 0 ? "" : "freq" + "=\(frequency.hzToMhz())")") } }
    /// Remove a Slice
    ///
    /// - Parameter id: Slice Id
    ///
    public func sliceRemove(_ id: SliceId) {
        send(kSliceCmd + "remove" + " \(id)")
    }
    /// <#Description#>
    ///
    /// - Parameter id: <#id description#>
    public func sliceErrorRequest(_ id: SliceId) {
        send(kSliceCmd + "get_error" + " \(id)", replyTo: replyHandler)
    }
    /// Request a list of slice Stream Id's
    ///
    public func sliceListRequest() {
        send(kSliceCmd + "list", replyTo: replyHandler)
    }
    
    // MARK: --- Tnf ---
    
    /// Create a Tnf
    ///
    /// - Parameters:
    ///   - frequency:          frequency (Hz)
    ///   - panadapter:         Panadapter Id
    ///
    public func tnfCreate(frequency: Int, panadapter: Panadapter) {
        send(kTnfCreateCmd + "freq" + "=\(calcTnfFreq(frequency, panadapter).hzToMhz())")
    }
    /// Remove a Tnf
    ///
    /// - Parameter tnf:        Tnf Id
    ///
    public func tnfRemove(tnf: Tnf) {
        
        send(kTnfRemoveCmd + " \(tnf.id)")
        NC.post(.tnfWillBeRemoved, object: tnf as Any?)
        removeObject(tnf)
    }
    
    // MARK: --- Transmit ---
    
    /// Turn MOX On/Off
    ///
    /// - Parameter value:      On/Off
    ///
    public func transmitSet(_ value: Bool) {
        send(kXmitCmd + " \(value.asNumber())")
    }
    
    // MARK: --- Tx Audio Stream ---
    
    /// Create a Tx Audio Stream
    ///
    /// - Parameter callback:   ReplyHandler (optional)
    /// - Returns:              Success / Failure
    ///
    public func txAudioStreamCreate(callback: ReplyHandler? = nil) -> Bool {
        return sendWithCheck(kStreamCreateCmd + "daxtx", replyTo: callback)
    }
    /// Remove a Tx Audio Stream
    ///
    /// - Parameter id:         TxAudioStream Id
    ///
    public func txAudioStreamRemove(_ id: String) {
        send(kStreamRemoveCmd + "0x\(id)")
    }
    
    // MARK: --- Uptime ---
    
    /// Request the elapsed uptime
    ///
    public func uptimeRequest() {
        send(kRadioUptimeCmd, replyTo: replyHandler)
    }
    
    // MARK: --- Xvtr ---
    
    /// Create an Xvtr
    ///
    /// - Parameter callback:   ReplyHandler (optional)
    /// - Returns:              Success / Failure
    ///
    public func xvtrCreate(callback: ReplyHandler? = nil) -> Bool {
        return sendWithCheck(kXvtrCmd + "create", replyTo: callback)
    }
    /// Remove an Xvtr
    ///
    /// - Parameter id:         Xvtr Id
    ///
    public func xvtrRemove(_ id: String) {
        send(kXvtrCmd + "remove" + " \(id)")
    }
}
