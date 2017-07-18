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
    // MARK: - Public methods to send data / commands to the Radio (hardware)
    
    /// Send a command to the Radio (hardware)
    ///
    /// - Parameters:
    ///   - command:        a Command String
    ///   - flag:           use "D"iagnostic form
    ///   - callback:       a callback function (if any)
    ///
    public func send(_ command: String, diagnostic flag: Bool = false, replyTo callback: ReplyHandler? = nil) {
        
        // tell the TcpManager to send the command (and optionally setup a callback)
        let _ = _tcp.send(command, diagnostic: flag, replyTo: callback)
    }
    /// Send a command to the Radio (hardware), check for isConnected
    ///
    /// - Parameters:
    ///   - command:        a Command String
    ///   - flag:           use "D"iagnostic form
    ///   - callback:       a callback function (if any)
    /// - Returns:          Success / Failure
    ///
    public func sendWithCheck(_ command: String, diagnostic flag: Bool = false, replyTo callback: ReplyHandler? = nil) -> Bool {
        
        guard _tcp.isConnected else { return false }
        
        // tell the TcpManager to send the command (and optionally setup a callback)
        send(command, diagnostic: flag, replyTo: callback)
        
        return true
    }
    /// Send a Vita packet to the Radio
    ///
    /// - Parameters:
    ///   - data:       a Vita-49 packet as Data
    ///
    public func sendVitaData(_ data: Data?) {
        
        if let dataToSend = data {
            
            _udp.sendData(dataToSend)
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public Enum for Command Lists
    
    ///
    ///     Note: The "clientUdpPort" command must be sent AFTER the actual Udp port number has been determined.
    ///           The default port number may already be in use by another application.
    ///
    public enum Command: String {
        
        // GROUP A: none of this group should be included in one of the command sets
        case none
        case clientUdpPort = "client udpport "
        case allPrimary
        case allSecondary
        case allSubscription
        
        // GROUP B: members of this group can be included in the command sets
        case antList = "ant list"
        case clientProgram = "client program "
        case clientGui = "client gui"
        case eqRx = "eq rxsc info"
        case eqTx = "eq txsc info"
        case info
        case meterList = "meter list"
        case micList = "mic list"
        case profileGlobal = "profile global info"
        case profileTx = "profile tx info"
        case profileMic = "profile mic info"
        case subAmplifier = "sub amplifier all"
        case subAudioStream = "sub audio_stream all"
        case subAtu = "sub atu all"
        case subCwx = "sub cwx all"
        case subDax = "sub dax all"
        case subDaxIq = "sub daxiq all"
        case subFoundation = "sub foundation all"
        case subGps = "sub gps all"
        case subMemories = "sub memories all"
        case subMeter = "sub meter all"
        case subPan = "sub pan all"
        case subRadio = "sub radio all"
        case subScu = "sub scu all"
        case subSlice = "sub slice all"
        case subTx = "sub tx all"
        case subUsbCable = "sub usb_cable all"
        case subXvtr = "sub xvtr all"
        case version
        
        // Note: Do not include GROUP A values in these return vales
        
        static func allPrimaryCommands() -> [Command] {
            // in the same order as in the FlexAPI C# code
            return [.clientProgram, .clientGui]
        }
        static func allSecondaryCommands() -> [Command] {
            // in the same order as in the FlexAPI C# code
            return [.info, .version, .antList, .micList, .meterList,
                    .profileGlobal, .profileTx, .profileMic, .eqRx, .eqTx]
        }
        static func allSubscriptionCommands() -> [Command] {
            // in the same order as in the FlexAPI C# code
            return [.subRadio, .subTx, .subAtu, .subMeter, .subPan, .subSlice, .subGps,
                    .subAudioStream, .subCwx, .subXvtr, .subMemories, .subDaxIq, .subDax,
                    .subUsbCable, .subAmplifier, .subFoundation, .subScu]
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods that send commands to the Radio (hardware)
    
    // listed in alphabetical order
    
    // MARK: --- Antenna List ---
    
    /// Request a list of antenns
    ///
    public func antennaListRequest(callback: ReplyHandler? = nil) {
        send(kAntListCmd, replyTo: callback == nil ? replyHandler : callback)
    }
    
    // MARK: --- ATU ---
    
    /// Clear the ATU
    ///
    public func atuClear(callback: ReplyHandler? = nil) {
        send(kAtuCmd + "clear", replyTo: callback)
    }
    /// Start the ATU
    ///
    public func atuStart(callback: ReplyHandler? = nil) {
        send(kAtuCmd + "start", replyTo: callback)
    }
    /// Bypass the ATU
    ///
    public func atuBypass(callback: ReplyHandler? = nil) {
        send(kAtuCmd + "bypass", replyTo: callback)
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
    public func audioStreamRemove(_ id: String, callback: ReplyHandler? = nil) -> Bool {
        return sendWithCheck(kStreamRemoveCmd + "0x\(id)", replyTo: callback)
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
    public func iqStreamRemove(_ id: String, callback: ReplyHandler? = nil) {
        send(kStreamRemoveCmd + "0x\(id)", replyTo: callback)
    }
    
    // MARK: --- Memory ---
    
    /// Create a Memory
    ///
    public func memoryCreate(callback: ReplyHandler? = nil) {
        send(kMemoryCreateCmd, replyTo: callback)
    }
    /// Remove a Memory
    ///
    /// - Parameter id:     Memory Id
    ///
    public func memoryRemove(_ id: MemoryId, callback: ReplyHandler? = nil) {
        send(kMemoryRemoveCmd + "\(id)", replyTo: callback)
    }
    
    // MARK: --- Meter ---
    
    /// Request a list of Meters
    ///
    public func meterListRequest(callback: ReplyHandler? = nil) {
        send(kMeterListCmd, replyTo: callback == nil ? replyHandler : callback)
    }
    
    // MARK: --- Mic Audio Stream ---
    
    /// Create a Mic Audio Stream
    ///
    /// - Parameter callback:   ReplyHandler (optional)
    /// - Returns:              Success / Failure
    ///
    public func micAudioStreamCreate(callback: ReplyHandler? = nil) -> Bool {
        return sendWithCheck(kMicStreamCreateCmd, replyTo: callback)
    }
    /// Remove a Mic Audio Stream
    ///
    /// - Parameter id:         Mic Audio Stream Id
    ///
    public func micAudioStreamRemove(id: String, callback: ReplyHandler? = nil) {
        send(kStreamRemoveCmd + "0x\(id)", replyTo: callback)
    }
    
    // MARK: --- Mic List ---
    
    /// Request a List of Mic sources
    ///
    public func micListRequest(callback: ReplyHandler? = nil) {
        send(kMicListCmd, replyTo: callback == nil ? replyHandler : callback)
    }
    
    // MARK: --- Panafall ---
    
    /// Create a Panafall
    ///
    /// - Parameter dimensions:     Panafall dimensions
    ///
    public func panafallCreate(_ dimensions: CGSize, callback: ReplyHandler? = nil) {
        if availablePanadapters > 0 {
            send(kDisplayPanCmd + "create x=\(dimensions.width) y=\(dimensions.height)", replyTo: callback == nil ? replyHandler : callback)
        }
    }
    /// Create a Panafall
    ///
    /// - Parameters:
    ///   - frequency:          selected frequency (Hz)
    ///   - antenna:            selected antenna
    ///   - dimensions:         Panafall dimensions
    ///
    public func panafallCreate(frequency: Int, antenna: String? = nil, dimensions: CGSize? = nil, callback: ReplyHandler? = nil) {
        if availablePanadapters > 0 {
            
            var cmd = kDisplayPanCmd + "create freq" + "=\(frequency.hzToMhz())"
            if antenna != nil { cmd += " ant=" + "\(antenna!)" }
            if dimensions != nil { cmd += " x" + "=\(dimensions!.width)" + " y" + "=\(dimensions!.height)" }
            send(cmd, replyTo: callback == nil ? replyHandler : callback)
        }
    }
    /// Remove a Panafall
    ///
    /// - Parameter id:         Panafall Id
    ///
    public func panafallRemove(_ id: PanadapterId, callback: ReplyHandler? = nil) {
        send(kDisplayPanCmd + " remove 0x\(id)", replyTo: callback)
    }
    
    // MARK: --- Profiles ---
    
    /// Delete a Global profile
    ///
    /// - Parameter name:       profile name
    ///
    public func profileGlobalDelete(_ name: String, callback: ReplyHandler? = nil) {
        send(kProfileCmd + ProfileToken.global.rawValue + " delete \"" + name + "\"", replyTo: callback)
    }
    /// Save a Global profile
    ///
    /// - Parameter name:       profile name
    ///
    public func profileGlobalSave(_ name: String, callback: ReplyHandler? = nil) {
        send(kProfileCmd + ProfileToken.global.rawValue + " save \"" + name + "\"", replyTo: callback)
    }
    /// Delete a Mic profile
    ///
    /// - Parameter name:       profile name
    ///
    public func profileMicDelete(_ name: String, callback: ReplyHandler? = nil) {
        send(kProfileCmd + ProfileToken.mic.rawValue + " delete \"" + name + "\"", replyTo: callback)
    }
    /// Save a Mic profile
    ///
    /// - Parameter name:       profile name
    ///
    public func profileMicSave(_ name: String, callback: ReplyHandler? = nil) {
        send(kProfileCmd + ProfileToken.mic.rawValue + " save \"" + name + "\"", replyTo: callback)
    }
    /// Delete a Transmit profile
    ///
    /// - Parameter name:       profile name
    ///
    public func profileTransmitDelete(_ name: String, callback: ReplyHandler? = nil) {
        send(kProfileCmd + "transmit" + " save \"" + name + "\"", replyTo: callback)
    }
    /// Save a Transmit profile
    ///
    /// - Parameter name:       profile name
    ///
    public func profileTransmitSave(_ name: String, callback: ReplyHandler? = nil) {
        send(kProfileCmd + "transmit" + " save \"" + name + "\"", replyTo: callback)
    }
    
    // MARK: --- Remote Audio (Opus) ---
    
    /// Turn Opus Rx On/Off
    ///
    /// - Parameter value:      On/Off
    ///
    public func remoteRxAudioRequest(_ value: Bool, callback: ReplyHandler? = nil) {
        send(kRemoteAudioCmd + Opus.OpusToken.remoteRxOn.rawValue + " \(value.asNumber())", replyTo: callback)
    }
    public func remoteTxAudioRequest(_ value: Bool, callback: ReplyHandler? = nil) {
        send(kRemoteAudioCmd + Opus.OpusToken.remoteTxOn.rawValue + "\(value.asNumber())", replyTo: callback)
    }
    // MARK: --- Reboot ---
    
    /// Reboot the Radio
    ///
    public func rebootRequest(callback: ReplyHandler? = nil) {
        send(kRadioCmd + " reboot", replyTo: callback)
    }
    
    // MARK: --- Slice ---
    
    /// Create a new Slice
    ///
    /// - Parameters:
    ///   - frequency:          frequenct (Hz)
    ///   - antenna:            selected antenna
    ///   - mode:               selected mode
    ///
    public func sliceCreate(frequency: Int, antenna: String, mode: String, callback: ReplyHandler? = nil) { if availableSlices > 0 {
        send(kSliceCmd + "create \(frequency.hzToMhz()) \(antenna) \(mode)", replyTo: callback) } }
    /// Create a new Slice
    ///
    /// - Parameters:
    ///   - panadapter:         selected panadapter
    ///   - frequency:          frequency (Hz)
    ///
    public func sliceCreate(panadapter: Panadapter, frequency: Int = 0, callback: ReplyHandler? = nil) { if availableSlices > 0 {
        send(kSliceCmd + "create pan" + "=0x\(panadapter.id) \(frequency == 0 ? "" : "freq" + "=\(frequency.hzToMhz())")", replyTo: callback) } }
    /// Remove a Slice
    ///
    /// - Parameter id: Slice Id
    ///
    public func sliceRemove(_ id: SliceId, callback: ReplyHandler? = nil) {
        send(kSliceCmd + "remove" + " \(id)", replyTo: callback)
    }
    /// <#Description#>
    ///
    /// - Parameter id: <#id description#>
    public func sliceErrorRequest(_ id: SliceId, callback: ReplyHandler? = nil) {
        send(kSliceCmd + "get_error" + " \(id)", replyTo: callback == nil ? replyHandler : callback)
    }
    /// Request a list of slice Stream Id's
    ///
    public func sliceListRequest(callback: ReplyHandler? = nil) {
        send(kSliceCmd + "list", replyTo: callback == nil ? replyHandler : callback)
    }
    
    // MARK: --- Tnf ---
    
    /// Create a Tnf
    ///
    /// - Parameters:
    ///   - frequency:          frequency (Hz)
    ///   - panadapter:         Panadapter Id
    ///
    public func tnfCreate(frequency: Int, panadapter: Panadapter, callback: ReplyHandler? = nil) {
        send(kTnfCreateCmd + "freq" + "=\(calcTnfFreq(frequency, panadapter).hzToMhz())", replyTo: callback)
    }
    /// Remove a Tnf
    ///
    /// - Parameter tnf:        Tnf Id
    ///
    public func tnfRemove(tnf: Tnf, callback: ReplyHandler? = nil) {
        
        send(kTnfRemoveCmd + " \(tnf.id)", replyTo: callback)
        NC.post(.tnfWillBeRemoved, object: tnf as Any?)
        removeObject(tnf)
    }
    
    // MARK: --- Transmit ---
    
    /// Turn MOX On/Off
    ///
    /// - Parameter value:      On/Off
    ///
    public func transmitSet(_ value: Bool, callback: ReplyHandler? = nil) {
        send(kXmitCmd + " \(value.asNumber())", replyTo: callback)
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
    public func txAudioStreamRemove(_ id: String, callback: ReplyHandler? = nil) {
        send(kStreamRemoveCmd + "0x\(id)", replyTo: callback)
    }
    
    // MARK: --- Uptime ---
    
    /// Request the elapsed uptime
    ///
    public func uptimeRequest(callback: ReplyHandler? = nil) {
        send(kRadioUptimeCmd, replyTo: callback == nil ? replyHandler : callback)
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
    public func xvtrRemove(_ id: String, callback: ReplyHandler? = nil) {
        send(kXvtrCmd + "remove" + " \(id)", replyTo: callback)
    }
}
