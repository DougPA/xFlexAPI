//
//  RadioCommands.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 7/14/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Radio Class extensions
//              - Public methods for sending data to the Radio
//              - Public enum for Primary, Secondary & Subscription Command lists
//              - Public methods that send commands to the Radio
//              - Dynamic public properties that send commands to the Radio
//              - Radio message enums
// --------------------------------------------------------------------------------

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
    /// Send a command to the Radio (hardware), first check that a Radio is connected
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
        tnfs[tnf.id] = nil
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
    
    // MARK: --- UsbCable ---
    
    /// Remove a UsbCable
    ///
    /// - Parameters:
    ///   - id:             UsbCable serial number
    ///   - callback:       ReplyHandler (optional)
    /// - Returns:          Success / Failure
    ///
    public func usbCableRemove(_ id: String, callback: ReplyHandler? = nil) -> Bool {
        return sendWithCheck(kUsbCableCmd + "remove" + " \(id)")
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

    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (with message sent to Radio)
    
    // listed in alphabetical order
    @objc dynamic public var accTxEnabled: Bool {
        get { return _accTxEnabled }
        set { if _accTxEnabled != newValue { _accTxEnabled = newValue ; send(kInterlockCmd + "acc_tx_enabled" + "=\(newValue.asLetter())") } } }
    
    @objc dynamic public var accTxDelay: Int {
        get { return _accTxDelay }
        set { if _accTxDelay != newValue { _accTxDelay = newValue ; send(kInterlockCmd + "acc_tx_delay" + "=\(newValue)") } } }
    
    @objc dynamic public var accTxReqEnabled: Bool {
        get {  return _accTxReqEnabled }
        set { if _accTxReqEnabled != newValue { _accTxReqEnabled = newValue ; send(kInterlockCmd + InterlockToken.accTxReqEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var accTxReqPolarity: Bool {
        get {  return _accTxReqPolarity }
        set { if _accTxReqPolarity != newValue { _accTxReqPolarity = newValue ; send(kInterlockCmd + InterlockToken.accTxReqPolarity.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var apfEnabled: Bool {
        get {  return _apfEnabled }
        set { if _apfEnabled != newValue { _apfEnabled = newValue ; send(kApfCmd + EqApfToken.mode.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var apfQFactor: Int {
        get {  return _apfQFactor }
        set { if _apfQFactor != newValue { _apfQFactor = newValue.bound(kMinApfQ, kMaxApfQ) ; send(kApfCmd + EqApfToken.qFactor.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var apfGain: Int {
        get {  return _apfGain }
        set { if _apfGain != newValue { _apfGain = newValue.bound(kMinLevel, kMaxLevel) ; send(kApfCmd + EqApfToken.gain.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var atuMemoriesEnabled: Bool {
        get {  return _atuMemoriesEnabled }
        set { if _atuMemoriesEnabled != newValue { _atuMemoriesEnabled = newValue ; send(kAtuSetCmd + AtuToken.memoriesEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var bandPersistenceEnabled: Bool {
        get {  return _bandPersistenceEnabled }
        set { if _bandPersistenceEnabled != newValue { _bandPersistenceEnabled = newValue ; send(kRadioSetCmd + RadioToken.bandPersistenceEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var binauralRxEnabled: Bool {
        get {  return _binauralRxEnabled }
        set { if _binauralRxEnabled != newValue { _binauralRxEnabled = newValue ; send(kRadioSetCmd + RadioToken.binauralRxEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var calFreq: Int {
        get {  return _calFreq }
        set { if _calFreq != newValue { _calFreq = newValue ; send(kRadioSetCmd + RadioToken.calFreq.rawValue + "=\(newValue.hzToMhz())") } } }
    
    @objc dynamic public var callsign: String {
        get {  return _callsign }
        set { if _callsign != newValue { _callsign = newValue ; send(kRadioCmd + RadioToken.callsign.rawValue + " \(newValue)") } } }
    
    @objc dynamic public var carrierLevel: Int {
        get {  return _carrierLevel }
        set { if _carrierLevel != newValue { _carrierLevel = newValue.bound(kMinLevel, kMaxLevel) ; send(kTransmitSetCmd + "am_carrier" + "=\(newValue)") } } }
    
    @objc dynamic public var companderEnabled: Bool {
        get {  return _companderEnabled }
        set { if _companderEnabled != newValue { _companderEnabled = newValue ; send(kTransmitSetCmd + TransmitToken.companderEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var companderLevel: Int {
        get {  return _companderLevel }
        set { if _companderLevel != newValue { _companderLevel = newValue.bound(kMinLevel, kMaxLevel) ; send(kTransmitSetCmd + TransmitToken.companderLevel.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var currentGlobalProfile: String {
        get {  return _currentGlobalProfile }
        set { if _currentGlobalProfile != newValue { _currentGlobalProfile = newValue ; send(kProfileCmd + ProfileToken.global.rawValue + " load \"\(newValue)\"") } } }
    
    @objc dynamic public var currentMicProfile: String {
        get {  return _currentMicProfile }
        set { if _currentMicProfile != newValue { _currentMicProfile = newValue ; send(kProfileCmd + ProfileToken.mic.rawValue + " load \"\(newValue)\"") } } }
    
    @objc dynamic public var currentTxProfile: String {
        get {  return _currentTxProfile }
        set { if _currentTxProfile != newValue { _currentTxProfile = newValue  ; send(kProfileCmd + ProfileToken.tx.rawValue + " load \"\(newValue)\"") } } }
    
    @objc dynamic public var cwAutoSpaceEnabled: Bool {
        get {  return _cwAutoSpaceEnabled }
        set { if _cwAutoSpaceEnabled != newValue { _cwAutoSpaceEnabled = newValue ; send(kCwCmd + "auto_space" + " \(newValue.asNumber())") } } }
    
    @objc dynamic public var cwBreakInDelay: Int {
        get {  return _cwBreakInDelay }
        set { if _cwBreakInDelay != newValue { _cwBreakInDelay = newValue.bound(kMinDelay, kMaxDelay) ; send(kCwCmd + TransmitToken.cwBreakInDelay.rawValue + " \(newValue)") } } }
    
    @objc dynamic public var cwBreakInEnabled: Bool {
        get {  return _cwBreakInEnabled }
        set { if _cwBreakInEnabled != newValue { _cwBreakInEnabled = newValue ; send(kCwCmd + TransmitToken.cwBreakInEnabled.rawValue + " \(newValue.asNumber())") } } }
    
    @objc dynamic public var cwIambicEnabled: Bool {
        get {  return _cwIambicEnabled }
        set { if _cwIambicEnabled != newValue { _cwIambicEnabled = newValue ; send(kCwCmd + TransmitToken.cwIambicEnabled.rawValue + " \(newValue.asNumber())")} } }
    
    @objc dynamic public var cwIambicMode: Int {
        get {  return _cwIambicMode }
        set { if _cwIambicMode != newValue { _cwIambicMode = newValue ; send(kCwCmd + TransmitToken.cwIambicMode.rawValue + " \(newValue)") } } }
    
    @objc dynamic public var cwlEnabled: Bool {
        get {  return _cwlEnabled }
        set { if _cwlEnabled != newValue { _cwlEnabled = newValue ; send(kCwCmd + TransmitToken.cwlEnabled.rawValue + " \(newValue.asNumber())") } } }
    
    @objc dynamic public var cwPitch: Int {
        get {  return _cwPitch }
        set { if _cwPitch != newValue { _cwPitch = newValue.bound(kMinPitch, kMaxPitch) ; send(kCwCmd + TransmitToken.cwPitch.rawValue + " \(newValue)") } } }
    
    @objc dynamic public var cwSidetoneEnabled: Bool {
        get {  return _cwSidetoneEnabled }
        set { if _cwSidetoneEnabled != newValue { _cwSidetoneEnabled = newValue ; send(kCwCmd + TransmitToken.cwSidetoneEnabled.rawValue + " \(newValue.asNumber())") } } }
    
    @objc dynamic public var cwSpeed: Int {
        get {  return _cwSpeed }
        set { if _cwSpeed != newValue { _cwSpeed = newValue.bound(kMinWpm, kMaxWpm) ; send(kCwCmd + TransmitToken.cwSpeed.rawValue + " \(newValue)") } } }
    
    @objc dynamic public var cwSwapPaddles: Bool {
        get {  return _cwSwapPaddles }
        set { if _cwSwapPaddles != newValue { _cwSwapPaddles = newValue ; send(kCwCmd + TransmitToken.cwSwapPaddles.rawValue + " \(newValue.asNumber())") } } }
    
    @objc dynamic public var cwSyncCwxEnabled: Bool {
        get {  return _cwSyncCwxEnabled }
        set { if _cwSyncCwxEnabled != newValue { _cwSyncCwxEnabled = newValue ; send (kCwCmd + TransmitToken.cwSyncCwxEnabled.rawValue + " \(newValue.asNumber())") } } }
    
    @objc dynamic public var cwWeight: Int {
        get {  return _cwWeight }
        set { if _cwWeight != newValue { _cwWeight = newValue ; send(kCwCmd + "weight" + " \(newValue)") } } }
    
    @objc dynamic public var daxEnabled: Bool {
        get {  return _daxEnabled }
        set { if _daxEnabled != newValue { _daxEnabled = newValue ; send(kTransmitSetCmd + TransmitToken.daxEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var enforcePrivateIpEnabled: Bool {
        get {  return _enforcePrivateIpEnabled }
        set { if _enforcePrivateIpEnabled != newValue { _enforcePrivateIpEnabled = newValue ; send(kRadioCmd + RadioToken.enforcePrivateIpEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var filterCwAutoLevel: Int {
        get {  return _filterCwAutoLevel }
        set { if _filterCwAutoLevel != newValue { _filterCwAutoLevel = newValue ; send(kRadioCmd + RadioToken.filterSharpness.rawValue + " " + RadioToken.cw.rawValue + " " + RadioToken.autoLevel.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var filterDigitalAutoLevel: Int {
        get {  return _filterDigitalAutoLevel }
        set { if _filterDigitalAutoLevel != newValue { _filterDigitalAutoLevel = newValue ; send(kRadioCmd + RadioToken.filterSharpness.rawValue + " " + RadioToken.digital.rawValue + " " + RadioToken.autoLevel.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var filterVoiceAutoLevel: Int {
        get {  return _filterVoiceAutoLevel }
        set { if _filterVoiceAutoLevel != newValue { _filterVoiceAutoLevel = newValue ; send(kRadioCmd + RadioToken.filterSharpness.rawValue + " " + RadioToken.voice.rawValue + " " + RadioToken.autoLevel.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var filterCwLevel: Int {
        get {  return _filterCwLevel }
        set { if _filterCwLevel != newValue { _filterCwLevel = newValue ; send(kRadioCmd + RadioToken.filterSharpness.rawValue + " " + RadioToken.cw.rawValue + " " + RadioToken.level.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var filterDigitalLevel: Int {
        get {  return _filterDigitalLevel }
        set { if _filterDigitalLevel != newValue { _filterDigitalLevel = newValue ; send(kRadioCmd + RadioToken.filterSharpness.rawValue + " " + RadioToken.digital.rawValue + " " + RadioToken.level.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var filterVoiceLevel: Int {
        get {  return _filterVoiceLevel }
        set { if _filterVoiceLevel != newValue { _filterVoiceLevel = newValue ; send(kRadioCmd + RadioToken.filterSharpness.rawValue + " " + RadioToken.voice.rawValue + " " + RadioToken.level.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var freqErrorPpb: Int {
        get {  return _freqErrorPpb }
        set { if _freqErrorPpb != newValue { _freqErrorPpb = newValue ; send(kRadioSetCmd + RadioToken.freqErrorPpb.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var fullDuplexEnabled: Bool {
        get {  return _fullDuplexEnabled }
        set { if _fullDuplexEnabled != newValue { _fullDuplexEnabled = newValue ; send(kRadioSetCmd + RadioToken.fullDuplexEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var headphoneGain: Int {
        get {  return _headphoneGain }
        set { if _headphoneGain != newValue { _headphoneGain = newValue.bound(kMinLevel, kMaxLevel) ; send(kMixerCmd + "headphone gain" + " \(newValue)") } } }
    
    @objc dynamic public var headphoneMute: Bool {
        get {  return _headphoneMute }
        set { if _headphoneMute != newValue { _headphoneMute = newValue; send(kMixerCmd + "headphone mute" + " \(newValue.asNumber())") } } }
    
    @objc dynamic public var hwAlcEnabled: Bool {
        get {  return _hwAlcEnabled }
        set { if _hwAlcEnabled != newValue { _hwAlcEnabled = newValue ; send(kTransmitSetCmd + TransmitToken.hwAlcEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var inhibit: Bool {
        get {  return _inhibit }
        set { if _inhibit != newValue { _inhibit = newValue ; send(kTransmitSetCmd + TransmitToken.inhibit.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var lineoutGain: Int {
        get {  return _lineoutGain }
        set { if _lineoutGain != newValue { _lineoutGain = newValue.bound(kMinLevel, kMaxLevel) ; send(kMixerCmd + "lineout gain" + " \(newValue)") } } }
    
    @objc dynamic public var lineoutMute: Bool {
        get {  return _lineoutMute }
        set { if _lineoutMute != newValue { _lineoutMute = newValue ; send(kMixerCmd + "lineout mute" + " \(newValue.asNumber())") } } }
    
    @objc dynamic public var maxPowerLevel: Int {
        get {  return _maxPowerLevel }
        set { if _maxPowerLevel != newValue { _maxPowerLevel = newValue.bound(kMinLevel, kMaxLevel) ; send(kTransmitSetCmd + TransmitToken.maxPowerLevel.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var metInRxEnabled: Bool {
        get {  return _metInRxEnabled }
        set { if _metInRxEnabled != newValue { _metInRxEnabled = newValue ; send(kTransmitSetCmd + TransmitToken.metInRxEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var micAccEnabled: Bool {
        get {  return _micAccEnabled }
        set { if _micAccEnabled != newValue { _micAccEnabled = newValue ; send(kMicCmd + "acc" + " \(newValue.asNumber())") } } }
    
    @objc dynamic public var micBiasEnabled: Bool {
        get {  return _micBiasEnabled }
        set { if _micBiasEnabled != newValue { _micBiasEnabled = newValue ; send(kMicCmd + "bias" + " \(newValue.asNumber())") } } }
    
    @objc dynamic public var micBoostEnabled: Bool {
        get {  return _micBoostEnabled }
        set { if _micBoostEnabled != newValue { _micBoostEnabled = newValue ; send(kMicCmd + "boost" + " \(newValue.asNumber())") } } }
    
    @objc dynamic public var micLevel: Int {
        get {  return _micLevel }
        set { if _micLevel != newValue { _micLevel = newValue.bound(kMinLevel, kMaxLevel) ; send(kTransmitSetCmd + "miclevel" + "=\(newValue)") } } }
    
    @objc dynamic public var micSelection: String {
        get {  return _micSelection }
        set { if _micSelection != newValue { _micSelection = newValue ; send(kMicCmd + "input" + " \(newValue)") } } }
    
    @objc dynamic public var nickname: String {
        get {  return _nickname }
        set { if _nickname != newValue { _nickname = newValue ; send(kRadioCmd + "name" + " \(newValue)") } } }
    
    @objc dynamic public var radioScreenSaver: String {
        get {  return _radioScreenSaver }
        set { if _radioScreenSaver != newValue { _radioScreenSaver = newValue ; send(kRadioCmd + "screensaver" + " \(newValue)") } } }
    
    @objc dynamic public var rcaTxReqEnabled: Bool {
        get {  return _rcaTxReqEnabled}
        set { if _rcaTxReqEnabled != newValue { _rcaTxReqEnabled = newValue ; send(kInterlockCmd + InterlockToken.rcaTxReqEnabled.rawValue + "=\(newValue.asLetter())") } } }
    
    @objc dynamic public var rcaTxReqPolarity: Bool {
        get {  return _rcaTxReqPolarity }
        set { if _rcaTxReqPolarity != newValue { _rcaTxReqPolarity = newValue ; send(kInterlockCmd + InterlockToken.rcaTxReqPolarity.rawValue + "=\(newValue.asLetter())") } } }
    
    @objc dynamic public var remoteOnEnabled: Bool {
        get {  return _remoteOnEnabled }
        set { if _remoteOnEnabled != newValue { _remoteOnEnabled = newValue ; send(kRadioSetCmd + RadioToken.remoteOnEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var rfPower: Int {
        get {  return _rfPower }
        set { if _rfPower != newValue { _rfPower = newValue.bound(kMinLevel, kMaxLevel) ; send(kTransmitSetCmd + TransmitToken.rfPower.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var rttyMark: Int {
        get {  return _rttyMark }
        set { if _rttyMark != newValue { _rttyMark = newValue ; send(kRadioSetCmd + RadioToken.rttyMark.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var snapTuneEnabled: Bool {
        get {  return _snapTuneEnabled }
        set { if _snapTuneEnabled != newValue { _snapTuneEnabled = newValue ; send(kRadioCmd + RadioToken.snapTuneEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var speechProcessorEnabled: Bool {
        get {  return _speechProcessorEnabled }
        set { if _speechProcessorEnabled != newValue { _speechProcessorEnabled = newValue ; send(kTransmitSetCmd + TransmitToken.speechProcessorEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var speechProcessorLevel: Int {
        get {  return _speechProcessorLevel }
        set { if _speechProcessorLevel != newValue { _speechProcessorLevel = newValue ; send(kTransmitSetCmd + TransmitToken.speechProcessorLevel.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var ssbPeakControlEnabled: Bool {
        get {  return _ssbPeakControlEnabled }
        set { if _ssbPeakControlEnabled != newValue { _ssbPeakControlEnabled = newValue ; send(kTransmitSetCmd + "ssb_peak_control" + "=\(newValue.asNumber())")} } }
    
    @objc dynamic public var startOffset: Bool {
        get { return _startOffset }
        set { if _startOffset != newValue { _startOffset = newValue ; if !_startOffset { send(kRadioCmd + "pll_start") } } } }
    
    @objc dynamic public var staticGateway: String {
        get {  return _staticGateway }
        set { if _staticGateway != newValue { _staticGateway = newValue ; send(kRadioCmd + RadioToken.staticNetParams.rawValue + " " + RadioToken.ip.rawValue + "=\(staticIp) " + RadioToken.gateway.rawValue + "=\(newValue) " + RadioToken.netmask.rawValue + "=\(staticNetmask)") } } }
    
    @objc dynamic public var staticIp: String {
        get {  return _staticIp }
        set { if _staticIp != newValue { _staticIp = newValue ; send(kRadioCmd + RadioToken.staticNetParams.rawValue + " " + RadioToken.ip.rawValue + "=\(staticIp) " + RadioToken.gateway.rawValue + "=\(newValue) " + RadioToken.netmask.rawValue + "=\(staticNetmask)") } } }
    
    @objc dynamic public var staticNetmask: String {
        get {  return _staticNetmask }
        set { if _staticNetmask != newValue { _staticNetmask = newValue ; send(kRadioCmd + RadioToken.staticNetParams.rawValue + " " + RadioToken.ip.rawValue + "=\(staticIp) " + RadioToken.gateway.rawValue + "=\(newValue) " + RadioToken.netmask.rawValue + "=\(staticNetmask)") } } }
    
    @objc dynamic public var timeout: Int {
        get {  return _timeout }
        set { if _timeout != newValue { _timeout = newValue ; send(kInterlockCmd + InterlockToken.timeout.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var tnfEnabled: Bool {
        get {  return _tnfEnabled }
        set { if _tnfEnabled != newValue { _tnfEnabled = newValue ; send(kRadioSetCmd + RadioToken.tnfEnabled.rawValue + "=\(newValue.asString())") } } }
    
    @objc dynamic public var tune: Bool {
        get {  return _tune }
        set { if _tune != newValue { _tune = newValue ; send(kTransmitCmd + TransmitToken.tune.rawValue + " \(newValue.asNumber())") } } }
    
    @objc dynamic public var tunePower: Int {
        get {  return _tunePower }
        set { if _tunePower != newValue { _tunePower = newValue.bound(kMinLevel, kMaxLevel) ; send(kTransmitSetCmd + TransmitToken.tunePower.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var txFilterHigh: Int {
        get { return _txFilterHigh }
        set { if _txFilterHigh != newValue { let value = txFilterHighLimits(txFilterLow, newValue) ; _txFilterHigh = value ; send(kTransmitSetCmd + "filter_high" + "=\(value)") } } }
    
    @objc dynamic public var txFilterLow: Int {
        get { return _txFilterLow }
        set { if _txFilterLow != newValue { let value = txFilterLowLimits(newValue, txFilterHigh) ; _txFilterLow = value ; send(kTransmitSetCmd + "filter_low" + "=\(value)") } } }
    
    @objc dynamic public var txInWaterfallEnabled: Bool {
        get { return _txInWaterfallEnabled }
        set { if _txInWaterfallEnabled != newValue { _txInWaterfallEnabled = newValue ; send(kTransmitSetCmd + TransmitToken.txInWaterfallEnabled.rawValue + "=\(newValue.asNumber())")} } }
    
    @objc dynamic public var txMonitorEnabled: Bool {
        get {  return _txMonitorEnabled }
        set { if _txMonitorEnabled != newValue { _txMonitorEnabled = newValue ; send(kTransmitSetCmd + "mon" + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var txMonitorGainCw: Int {
        get {  return _txMonitorGainCw }
        set { if _txMonitorGainCw != newValue { _txMonitorGainCw = newValue.bound(kMinLevel, kMaxLevel) ; send(kTransmitSetCmd + TransmitToken.txMonitorGainCw.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var txMonitorGainSb: Int {
        get {  return _txMonitorGainSb }
        set { if _txMonitorGainSb != newValue { _txMonitorGainSb = newValue.bound(kMinLevel, kMaxLevel) ; send(kTransmitSetCmd + TransmitToken.txMonitorGainSb.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var txMonitorPanCw: Int {
        get {  return _txMonitorPanCw }
        set { if _txMonitorPanCw != newValue { _txMonitorPanCw = newValue.bound(kMinLevel, kMaxLevel) ; send(kTransmitSetCmd + TransmitToken.txMonitorPanCw.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var txMonitorPanSb: Int {
        get {  return _txMonitorPanSb }
        set { if _txMonitorPanSb != newValue { _txMonitorPanSb = newValue.bound(kMinLevel, kMaxLevel) ; send(kTransmitSetCmd + TransmitToken.txMonitorPanSb.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var tx1Enabled: Bool {
        get { return _tx1Enabled }
        set { if _tx1Enabled != newValue { _tx1Enabled = newValue ; send(kInterlockCmd + InterlockToken.tx1Enabled.rawValue + "=\(newValue.asLetter())") } } }
    
    @objc dynamic public var tx1Delay: Int {
        get { return _tx1Delay }
        set { if _tx1Delay != newValue { _tx1Delay = newValue  ; send(kInterlockCmd + InterlockToken.tx1Delay.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var tx2Enabled: Bool {
        get { return _tx2Enabled }
        set { if _tx2Enabled != newValue { _tx2Enabled = newValue ; send(kInterlockCmd + InterlockToken.tx2Enabled.rawValue + "=\(newValue.asLetter())") } } }
    
    @objc dynamic public var tx2Delay: Int {
        get { return _tx2Delay }
        set { if _tx2Delay != newValue { _tx2Delay = newValue ; send(kInterlockCmd + InterlockToken.tx2Delay.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var tx3Enabled: Bool {
        get { return _tx3Enabled }
        set { if _tx3Enabled != newValue { _tx3Enabled = newValue ; send(kInterlockCmd + InterlockToken.tx3Enabled.rawValue + "=\(newValue.asLetter())")} } }
    
    @objc dynamic public var tx3Delay: Int {
        get { return _tx3Delay }
        set { if _tx3Delay != newValue { _tx3Delay = newValue ; send(kInterlockCmd + InterlockToken.tx3Delay.rawValue + "=\(newValue)")} } }
    
    @objc dynamic public var voxEnabled: Bool {
        get { return _voxEnabled }
        set { if _voxEnabled != newValue { _voxEnabled = newValue ; send(kTransmitSetCmd + TransmitToken.voxEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var voxDelay: Int {
        get { return _voxDelay }
        set { if _voxDelay != newValue { _voxDelay = newValue.bound(kMinLevel, kMaxLevel) ; send(kTransmitSetCmd + TransmitToken.voxDelay.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var voxLevel: Int {
        get { return _voxLevel }
        set { if _voxLevel != newValue { _voxLevel = newValue.bound(kMinLevel, kMaxLevel) ; send(kTransmitSetCmd + TransmitToken.voxLevel.rawValue + "=\(newValue)") } } }

    
    // ----------------------------------------------------------------------------
    // MARK: - Token enums in alphabetical order.
    // ----------------------------------------------------------------------------
    
    // ----------------------------------------------------------------------------
    // MARK: - Atu
    
    internal enum AtuToken: String {
        case status
        case atuEnabled = "atu_enabled"
        case memoriesEnabled = "memories_enabled"
        case usingMemories = "using_mem"
    }
    // ----------------------------------------------------------------------------
    // MARK: - Display
    
    internal enum DisplayToken: String {
        case panadapter = "pan"
        case waterfall
    }
    // ----------------------------------------------------------------------------
    // MARK: - Equalizer Apf
    
    internal enum EqApfToken: String {
        case gain
        case mode
        case qFactor
    }
    // ----------------------------------------------------------------------------
    // MARK: - Gps
    
    internal enum GpsToken: String {
        case altitude
        case frequencyError = "freq_error"
        case grid
        case latitude = "lat"
        case longitude = "lon"
        case speed
        case status
        case time
        case track
        case tracked
        case visible
    }
    // ----------------------------------------------------------------------------
    // MARK: - Info replies
    
    internal enum InfoToken: String {
        case atuPresent = "atu_present"
        case callsign
        case chassisSerial = "chassis_serial"
        case gateway
        case gps
        case ipAddress = "ip"
        case location
        case macAddress = "mac"
        case model
        case netmask
        case name
        case numberOfScus = "num_scu"
        case numberOfSlices = "num_slice"
        case numberOfTx = "num_tx"
        case options
        case region
        case screensaver
        case softwareVersion = "software_ver"
    }
    // ----------------------------------------------------------------------------
    // MARK: - Interlock
    
    internal enum InterlockToken: String {
        case accTxEnabled = "acc_tx_enabled"
        case accTxDelay = "acc_tx_delay"
        case accTxReqEnabled = "acc_txreq_enable"
        case accTxReqPolarity = "acc_txreq_polarity"
        case rcaTxReqEnabled = "rca_txreq_enable"
        case rcaTxReqPolarity = "rca_txreq_polarity"
        case reason
        case source
        case state
        case timeout
        case txAllowed = "tx_allowed"
        case txDelay = "tx_delay"
        case tx1Enabled = "tx1_enabled"
        case tx1Delay = "tx1_delay"
        case tx2Enabled = "tx2_enabled"
        case tx2Delay = "tx2_delay"
        case tx3Enabled = "tx3_enabled"
        case tx3Delay = "tx3_delay"
    }
    // ----------------------------------------------------------------------------
    // MARK: - Profile
    
    public enum ProfileToken: String {
        case global
        case mic
        case tx
    }
    internal enum ProfileSubType: String {
        case current
        case list
    }
    // ----------------------------------------------------------------------------
    // MARK: - Radio
    
    internal enum RadioToken: String {
        case autoLevel = "auto_level"
        case bandPersistenceEnabled = "band_persistence_enabled"
        case binauralRxEnabled = "binaural_rx"
        case calFreq = "cal_freq"
        case callsign
        case cw = "cw"
        case digital = "digital"
        case enforcePrivateIpEnabled = "enforce_private_ip_connections"
        case filterSharpness = "filter_sharpness"
        case freqErrorPpb = "freq_error_ppb"
        case fullDuplexEnabled = "full_duplex_enabled"
        case gateway
        case headphoneGain = "headphone_gain"
        case headphoneMute = "headphone_mute"
        case ip
        case level
        case lineoutGain = "lineout_gain"
        case lineoutMute = "lineout_mute"
        case netmask
        case nickname
        case panadapters
        case pllDone = "pll_done"
        case remoteOnEnabled = "remote_on_enabled"
        case rttyMark = "rtty_mark_default"
        case slices
        case snapTuneEnabled = "snap_tune_enabled"
        case staticNetParams = "static_net_params"
        case tnfEnabled = "tnf_enabled"
        case txInWaterfallEnabled = "show_tx_in_waterfall"
        case voice = "voice"
    }
    // ----------------------------------------------------------------------------
    // MARK: - Status
    
    internal enum StatusToken : String {
        case audioStream = "audio_stream"
        case atu
        case client
        case cwx
        case daxiq      // obsolete token, included to prevent log messages
        case display
        case eq
        case file
        case gps
        case interlock
        case memory
        case meter
        case micAudioStream = "mic_audio_stream"
        case mixer
        case opusStream = "opus_stream"
        case profile
        case radio
        case slice
        case stream
        case tnf
        case transmit
        case turf
        case txAudioStream = "tx_audio_stream"
        case usbCable = "usb_cable"
        case wan
        case waveform
        case xvtr
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Transmit
    
    internal enum TransmitToken: String {
        case amCarrierLevel = "am_carrier_level"
        case companderEnabled = "compander"
        case companderLevel = "compander_level"
        case cwBreakInDelay = "break_in_delay"
        case cwBreakInEnabled = "break_in"
        case cwIambicEnabled = "iambic"
        case cwIambicMode = "iambic_mode"
        case cwlEnabled = "cwl_enabled"
        case cwPitch = "pitch"
        case cwSidetoneEnabled = "sidetone"
        case cwSpeed = "speed"
        case cwSwapPaddles = "swap_paddles"
        case cwSyncCwxEnabled = "synccwx"
        case daxEnabled = "dax"
        case frequency = "freq"
        case hwAlcEnabled = "hwalc_enabled"
        case inhibit
        case maxPowerLevel = "max_power_level"
        case metInRxEnabled = "met_in_rx"
        case micAccEnabled = "mic_acc"
        case micBoostEnabled = "mic_boost"
        case micBiasEnabled = "mic_bias"
        case micLevel = "mic_level"
        case micSelection = "mic_selection"
        case rawIqEnabled = "raw_iq_enable"
        case rfPower = "rfpower"
        case speechProcessorEnabled = "speech_processor_enable"
        case speechProcessorLevel = "speech_processor_level"
        case txFilterChanges = "tx_filter_changes_allowed"
        case txFilterHigh = "hi"
        case txFilterLow = "lo"
        case txInWaterfallEnabled = "show_tx_in_waterfall"
        case txMonitorAvailable = "mon_available"
        case txMonitorEnabled = "sb_monitor"
        case txMonitorGainCw = "mon_gain_cw"
        case txMonitorGainSb = "mon_gain_sb"
        case txMonitorPanCw = "mon_pan_cw"
        case txMonitorPanSb = "mon_pan_sb"
        case txRfPowerChanges = "tx_rf_power_changes_allowed"
        case tune
        case tunePower = "tunepower"
        case voxEnabled = "vox_enable"
        case voxDelay = "vox_delay"
        case voxLevel = "vox_level"
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - UsbCable
    
    internal enum UsbCableToken: String {
        case none
        // FIXME: add cases
    }
    // ----------------------------------------------------------------------------
    // MARK: - Version replies
    
    internal enum VersionToken: String {
        case fpgaMb = "fpga-mb"
        case psocMbPa100 = "psoc-mbpa100"
        case psocMbTrx = "psoc-mbtrx"
        case smartSdrMB = "smartsdr-mb"
    }
    // ----------------------------------------------------------------------------
    // MARK: - Wan
    
    internal enum WanToken: String {
        case serverConnected = "server_connected"
        case radioAuthenticated = "radio_authenticated"
    }
    // ----------------------------------------------------------------------------
    // MARK: - Waveform
    
    internal enum WaveformToken: String {
        case waveformList = "installed_list"
    }
}
