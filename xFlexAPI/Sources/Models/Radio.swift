//
//  Radio.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 8/15/15.
//  Copyright © 2015 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation

let kApiId = "xFlexAPI"
let kDomainId = "net.k3tzr"

// --------------------------------------------------------------------------------
// MARK: - Protocols

protocol KeyValueParser {
    
    func parseKeyValues(_ keyValues: Radio.KeyValuesArray) -> Void
}

// --------------------------------------------------------------------------------
// MARK: - Radio Class implementation
//
//      as the object analog to the Radio (hardware) manages the connections (Tcp
//      and Udp) to the radio hardware and coordinates the use of all of the other
//      model objects
//
// --------------------------------------------------------------------------------

public final class Radio : NSObject, TcpManagerDelegate, UdpManagerDelegate {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    public var pingerEnabled = true
    public private(set) var uptime = 0
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties (Read Only)
    
    @objc dynamic public var radioVersion: String { return selectedRadio?.firmwareVersion ?? "" }
    
    public private(set) var selectedRadio: RadioParameters?             // Radio we are connected to
    
    public private(set) var cwx: Cwx!                                   // CWX class
    
    public private(set) var primaryCommandsArray = [CommandTuple]()     // Primary commands to be sent
    public private(set) var secondaryCommandsArray = [CommandTuple]()   // Secondary commands to be sent
    public private(set) var subscriptionCommandsArray = [CommandTuple]()// Subscription commands to be sent
    
    public private(set) var antennaList = [AntennaPort]()               // Array of available Antenna ports
    public private(set) var micList = [MicrophonePort]()                // Array of Microphone ports
    public private(set) var rfGainList = [RfGainValue]()                // Array of RfGain parameters
    public private(set) var sliceList = [SliceId]()                     // Array of available Slice id's
    
    public private(set) var sliceErrors = [String]()                    // frequency error of a Slice (milliHz)
    
    public private(set) var filters: [FilterMode: [FilterSpec]]!        // Dictionary of Filters
    
    public let kApiFirmwareSupport = "1.10.16.x"                        // The Radio Firmware version supported by this API
    
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    fileprivate var _tcp: TcpManager!                                   // TCP connection class (commands)
    fileprivate var _udp: UdpManager!                                   // UDP connection class (streams)
    fileprivate var _pinger: Pinger?                                    // Pinger class
    fileprivate var _isGui = false                                      // true = client is a Gui
    fileprivate var _clientName = ""
    fileprivate var _connectSimple = false
    fileprivate var _radioInitialized = false
    
    // GCD Serial Queues
    fileprivate let _opusQ =            DispatchQueue(label: kApiId + ".opusQ")
    fileprivate let _parseQ =           DispatchQueue(label: kApiId + ".parseQ")
    fileprivate let _tcpQ =             DispatchQueue(label: kApiId + ".tcpQ")
    fileprivate let _udpReceiveQ =      DispatchQueue(label: kApiId + ".udpReceiveQ")
    fileprivate let _udpSendQ =         DispatchQueue(label: kApiId + ".udpSendQ")
    fileprivate let _pingQ =            DispatchQueue(label: kApiId + ".pingQ")
    
    // GCD Concurrent Queues
    fileprivate let _audioStreamQ =     DispatchQueue(label: kApiId + ".audioStreamQ", attributes: [.concurrent])
    fileprivate let _cwxQ =             DispatchQueue(label: kApiId + ".cwxQ", attributes: [.concurrent])
    fileprivate let _equalizerQ =       DispatchQueue(label: kApiId + ".equalizerQ", attributes: [.concurrent])
    fileprivate let _iqStreamQ =        DispatchQueue(label: kApiId + ".iqStreamQ", attributes: [.concurrent])
    fileprivate let _memoryQ =          DispatchQueue(label: kApiId + ".memoryQ", attributes: [.concurrent])
    fileprivate let _meterQ =           DispatchQueue(label: kApiId + ".meterQ", attributes: [.concurrent])
    fileprivate let _micAudioStreamQ =  DispatchQueue(label: kApiId + ".micAudioStreamQ", attributes: [.concurrent])
    fileprivate let _objectQ =          DispatchQueue(label: kApiId + ".objectQ", attributes: [.concurrent])
    fileprivate let _panadapterQ =      DispatchQueue(label: kApiId + ".panadapterQ", attributes: [.concurrent])
    fileprivate let _radioQ =           DispatchQueue(label: kApiId + ".radioQ", attributes: [.concurrent])
    fileprivate let _sliceQ =           DispatchQueue(label: kApiId + ".sliceQ", attributes: [.concurrent])
    fileprivate let _tnfQ =             DispatchQueue(label: kApiId + ".tnfQ", attributes: [.concurrent])
    fileprivate let _txAudioStreamQ =   DispatchQueue(label: kApiId + ".txAudioStreamQ", attributes: [.concurrent])
    fileprivate let _usbCableQ =        DispatchQueue(label: kApiId + ".usbCableQ", attributes: [.concurrent])
    fileprivate let _waterfallQ =       DispatchQueue(label: kApiId + ".waterfallQ", attributes: [.concurrent])
    fileprivate let _xvtrQ =            DispatchQueue(label: kApiId + ".xvtrQ", attributes: [.concurrent])
    
    fileprivate var _connectionHandle: String?                           // API conversation ID
    fileprivate var _hardwareVersion: String?                            // ???
    
    // constants
    fileprivate let _log = Log.sharedInstance                            // shared log
    fileprivate let kBundleIdentifier = kDomainId + "." + kApiId
    fileprivate let kTnfClickBandwidth: CGFloat = 0.01                   // * bandwidth = minimum Tnf click width
    fileprivate let kSliceClickBandwidth: CGFloat = 0.01                 // * bandwidth = minimum Slice click width
    
    internal let kApfCmd = "eq apf "                                    // Text of command messages
    internal let kAntListCmd = Command.antList.rawValue
    internal let kAtuCmd = "atu "
    internal let kAtuSetCmd = "atu set "
    internal let kClientCmd = Command.clientProgram.rawValue
    internal let kCwCmd = "cw "
    internal let kDisplayPanCmd = "display pan "
    internal let kInfoCmd = Command.info.rawValue
    internal let kInterlockCmd = "interlock "
    internal let kMemoryCreateCmd = "memory create"
    internal let kMemoryRemoveCmd = "memory remove "
    internal let kMeterListCmd = Command.meterList.rawValue
    internal let kMicCmd = "mic "
    internal let kMicListCmd = Command.micList.rawValue
    internal let kMicStreamCreateCmd = "stream create daxmic"
    internal let kMixerCmd = "mixer "
    internal let kPingCmd = "ping"
    internal let kProfileCmd = "profile "
    internal let kRadioCmd = "radio "
    internal let kRadioSetCmd = "radio set "
    internal let kRadioUptimeCmd = "radio uptime"
    internal let kRemoteAudioCmd = "remote_audio "
    internal let kSliceCmd = "slice "
    internal let kSliceListCmd = "slice list"
    internal let kStreamCreateCmd = "stream create "
    internal let kStreamRemoveCmd = "stream remove "
    internal let kTnfCreateCmd = "tnf create "
    internal let kTnfRemoveCmd = "tnf remove "
    internal let kTransmitCmd = "transmit "
    internal let kTransmitSetCmd = "transmit set "
    internal let kVersionCmd = Command.version.rawValue
    internal let kXmitCmd = "xmit "
    internal let kXvtrCmd = "xvtr "
    
    fileprivate let kMinLevel = 0                                        // control range
    fileprivate let kMaxLevel = 100
    fileprivate let kMinPitch = 100
    fileprivate let kMaxPitch = 6_000
    fileprivate let kMinApfQ = 0
    fileprivate let kMaxApfQ = 33
    fileprivate let kMinWpm = 5
    fileprivate let kMaxWpm = 100
    fileprivate let kMinDelay = 0
    fileprivate let kMaxDelay = 2_000
    fileprivate let kNoError = "0"                                       // response without error
    
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
    //
    fileprivate var _connectionState = ConnectionState.disconnected(reason: .closed)  //
    // object collections
    fileprivate var _audioStreams = [DaxStreamId: AudioStream]()         // Dictionary of Audio streams
    fileprivate var _equalizers = [EqualizerType: Equalizer]()           // Dictionary of Equalizers
    fileprivate var _iqStreams = [DaxStreamId: IqStream]()               // Dictionary of Dax Iq streams
    fileprivate var _memories = [MemoryId: Memory]()                     // Dictionary of Memories
    fileprivate var _meters = [MeterId: Meter]()                         // Dictionary of Meters
    fileprivate var _micAudioStreams = [DaxStreamId: MicAudioStream]()   // Dictionary of MicAudio streams
    fileprivate var _opusStreams = [OpusId: Opus]()                      // Dictionary of Opus Streams
    fileprivate var _panadapters = [PanadapterId: Panadapter]()          // Dictionary of Panadapters
    fileprivate var _profiles = [ProfileToken: [ProfileString]]()        // Dictionary of Profiles
    fileprivate var _replyHandlers = [SequenceId: ReplyTuple]()          // Dictionary of pending replies
    fileprivate var _slices = [SliceId: Slice]()                         // Dictionary of Slices
    fileprivate var _tnfs = [TnfId: Tnf]()                               // Dictionary of Tnfs
    fileprivate var _txAudioStreams = [DaxStreamId: TxAudioStream]()     // Dictionary of Tx Audio streams
    fileprivate var _usbCables = [UsbCableId: UsbCable]()                // Dictionary of UsbCables
    fileprivate var _waterfalls = [WaterfallId: Waterfall]()             // Dictionary of Waterfalls
    fileprivate var _xvtrs = [XvtrId: Xvtr]()                            // Dictionary of Xvtrs

    
    // individual values
    // A
    fileprivate var __accTxEnabled = false                               //
    fileprivate var __accTxDelay = 0                                     //
    fileprivate var __accTxReqEnabled = false                            //
    fileprivate var __accTxReqPolarity = false                           //
    fileprivate var __apfEnabled = false                                 // auto-peaking filter enable
    fileprivate var __apfGain = 0                                        // auto-peaking gain (0 - 100)
    fileprivate var __apfQFactor = 0                                     // auto-peaking filter Q factor (0 - 33)
    fileprivate var __atuEnabled = false                                 // ATU enabled
    fileprivate var __atuPresent = false                                 //
    fileprivate var __atuStatus = ""                                     //
    fileprivate var __atuMemoriesEnabled = false                         //
    fileprivate var __atuUsingMemories = false                           //
    fileprivate var __availablePanadapters = 0                           // (read only)
    fileprivate var __availableSlices = 0                                // (read only)
    // B
    fileprivate var __binauralRxEnabled = false                          // Binaural enable
    // C
    fileprivate var __calFreq = 0                                        // Calibration frequency
    fileprivate var __callsign = ""                                      // Callsign
    fileprivate var __carrierLevel = 0                                   //
    fileprivate var __chassisSerial: String = ""                         // Radio serial number (read only)
    fileprivate var __companderEnabled = false                           //
    fileprivate var __companderLevel = 0                                 //
    fileprivate var __currentGlobalProfile = ""                          // Global profile name
    fileprivate var __currentMicProfile = ""                             // Mic profile name
    fileprivate var __currentTxProfile = ""                              // TX profile name
    fileprivate var __cwAutoSpaceEnabled = false                         //
    fileprivate var __cwBreakInDelay = 0                                 //
    fileprivate var __cwBreakInEnabled = false                           //
    fileprivate var __cwIambicEnabled = false                            //
    fileprivate var __cwIambicMode = 0                                   //
    fileprivate var __cwlEnabled = false                                 //
    fileprivate var __cwPitch = 0                                        // CW pitch frequency (Hz)
    fileprivate var __cwSidetoneEnabled = false                          //
    fileprivate var __cwSwapPaddles = false                              //
    fileprivate var __cwSyncCwxEnabled = false                           //
    fileprivate var __cwWeight = 0                                       // CW weight (0 - 100)
    fileprivate var __cwSpeed = 5                                        // CW speed (wpm, 5 - 100)
    // D
    fileprivate var __daxEnabled = false                                 // Dax enabled
    fileprivate var __daxIqAvailable = 0                                 //
    fileprivate var __daxIqCapacity = 0                                  //
    // E
    fileprivate var __enforcePrivateIpEnabled = false                    //
    // F
    fileprivate var __filterCwAutoLevel = 0                              //
    fileprivate var __filterCwLevel = 0                                  //
    fileprivate var __filterDigitalAutoLevel = 0                         //
    fileprivate var __filterDigitalLevel = 0                             //
    fileprivate var __filterVoiceAutoLevel = 0                           //
    fileprivate var __filterVoiceLevel = 0                               //
    fileprivate var __fpgaMbVersion = ""                                 // FPGA version (read only)
    fileprivate var __freqErrorPpb = 0                                   // Calibration error (Hz)
    fileprivate var __frequency = 0                                      //
    fileprivate var __fullDuplexEnabled = false                          // Full duplex enable
    // G
    fileprivate var __gateway: String = ""                               // (read only)
    fileprivate var __gpsAltitude = ""                                   //
    fileprivate var __gpsFrequencyError = 0.0                            //
    fileprivate var __gpsGrid = ""                                       //
    fileprivate var __gpsLatitude = ""                                   //
    fileprivate var __gpsLongitude = ""                                  //
    fileprivate var __gpsPresent = false                                 //
    fileprivate var __gpsSpeed = ""                                      //
    fileprivate var __gpsStatus = ""                                     //
    fileprivate var __gpsTime = ""                                       //
    fileprivate var __gpsTrack = 0.0                                     //
    fileprivate var __gpsTracked = false                                 //
    fileprivate var __gpsVisible = false                                 //
    // H
    fileprivate var __headphoneGain = 0                                  // Headset gain (1-100)
    fileprivate var __headphoneMute = false                              // Headset muted
    fileprivate var __hwAlcEnabled = false                               //
    // I
    fileprivate var __inhibit = false                                    //
    fileprivate var __ipAddress: String = ""                             // IP Address (dotted decimal) (read only)
    // L
    fileprivate var __lineoutGain = 0                                    // Speaker gain (1-100)
    fileprivate var __lineoutMute = false                                // Speaker muted
    fileprivate var __location: String = ""                              // (read only)
    // M
    fileprivate var __macAddress: String = ""                            // Radio Mac Address (read only)
    fileprivate var __maxPowerLevel = 0                                  //
    fileprivate var __metInRxEnabled = false                             //
    fileprivate var __micAccEnabled = false                              //
    fileprivate var __micBiasEnabled = false                             //
    fileprivate var __micBoostEnabled = false                            //
    fileprivate var __micLevel = 0                                       //
    fileprivate var __micSelection = ""                                  //
    // N
    fileprivate var __netmask: String = ""                               //
    fileprivate var __nickname = ""                                      // User assigned name
    fileprivate var __numberOfScus = 0                                   // NUmber of SCU's (read only)
    fileprivate var __numberOfSlices = 0                                 // Number of Slices (read only)
    fileprivate var __numberOfTx = 0                                     // Number of TX (read only)
    // P
    fileprivate var __psocMbPa100Version = ""                            // Power amplifier software version
    fileprivate var __psocMbtrxVersion = ""                              // System supervisor software version
    // R
    fileprivate var __radioModel = ""                                    // Radio Model (e.g. FLEX-6500) (read only)
    fileprivate var __radioOptions = ""                                  // (read only)
    fileprivate var __radioScreenSaver = ""                              // (read only)
    fileprivate var __rcaTxReqEnabled = false                            //
    fileprivate var __rcaTxReqPolarity = false                           //
    fileprivate var __rawIqEnabled = false                               //
    fileprivate var __reason = ""                                        //
    fileprivate var __region: String = ""                                // (read only)
    fileprivate var __remoteOnEnabled = false                            // Remote Power On enable
    fileprivate var __rfPower = 0                                        // Power level (0 - 100)
    fileprivate var __rttyMark = 0                                       // RTTY mark default
    // S
    fileprivate var __sbMonitorEnabled = false                           //
    fileprivate var __smartSdrMB = ""                                    // Microburst main CPU software version
    fileprivate var __snapTuneEnabled = false                            // Snap tune enable
    fileprivate var __softwareVersion: String = ""                       // (read only)
    fileprivate var __source = ""                                        //
    fileprivate var __speechProcessorEnabled = false                     //
    fileprivate var __speechProcessorLevel = 0                           //
    fileprivate var __ssbPeakControlEnabled = false                      //
    fileprivate var __startOffset = true                                 //
    fileprivate var __state = ""                                         //
    fileprivate var __staticGateway: String = ""                         // Static Gateway address
    fileprivate var __staticIp: String = ""                              // Static IpAddress
    fileprivate var __staticNetmask: String = ""                         // Static Netmask
    // T
    fileprivate var __timeout = 0                                        //
    fileprivate var __tnfEnabled = false                                 // TNF's enable
    fileprivate var __tune = false                                       //
    fileprivate var __tunePower = 0                                      //
    fileprivate var __txAllowed = false                                  //
    fileprivate var __txDelay = 0                                        //
    fileprivate var __txFilterChanges = false                            //
    fileprivate var __txFilterHigh = 0                                   //
    fileprivate var __txFilterLow = 0                                    //
    fileprivate var __txMonitorAvailable = false                         //
    fileprivate var __txMonitorEnabled = false                           //
    fileprivate var __txMonitorGainCw = 0                                //
    fileprivate var __txMonitorGainSb = 0                                //
    fileprivate var __txMonitorPanCw = 0                                 //
    fileprivate var __txMonitorPanSb = 0                                 //
    fileprivate var __txRfPowerChanges = false                           //
    fileprivate var __tx1Delay = 0                                       //
    fileprivate var __tx1Enabled = false                                 //
    fileprivate var __tx2Delay = 0                                       //
    fileprivate var __tx2Enabled = false                                 //
    fileprivate var __tx3Delay = 0                                       //
    fileprivate var __tx3Enabled = false                                 //
    fileprivate var __txInWaterfallEnabled = false                       // Tx in Waterfall enable
    // U
    fileprivate var __udpPort: UInt16 = 0                                // UDP port in use
    // V
    fileprivate var __voxDelay = 0                                       // VOX delay (seconds?)
    fileprivate var __voxEnabled = false                                 // VOX enabled
    fileprivate var __voxLevel = 0                                       // VOX level ( ?? - ??)
    // W
    fileprivate var __waveformList = ""                                  //
    //
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION -----
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    /// Initialize a Radio Class
    ///
    /// - Parameters:
    ///   - radioInstance:      a RadioParameters struct
    ///
    public init(radioParameters: RadioParameters, clientName: String, isGui: Bool = true) {
        
        self._clientName = clientName
        self.selectedRadio = radioParameters
        self._isGui = isGui
        
        super.init()
        
        _log.msg("xFlexAPI initialized, isGui = \(_isGui)", level: .debug, function: #function, file: #file, line: #line)
        
        // check the version
        checkFirmwareVersion(radioParameters)
        
        // initialize filters
        filters = loadFilters(filterPath: appFolder().path + "/Filters.plist")
        
        // initialize Cwx
        cwx = Cwx(radio: self, queue: _cwxQ)
        
        // initialize a Manager for the TCP Command stream
        _tcp = TcpManager(tcpQ: _tcpQ, delegate: self)
        
        // initialize a Manager for the UDP Data Streams
        _udp = UdpManager(radioParameters: radioParameters, udpReceiveQ: _udpReceiveQ, udpSendQ: _udpSendQ, delegate: self)
        
        // subscribe to Pinger notifications
        addNotifications()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - public methods
    
    /// Remove an object from its collection
    ///
    /// - Parameters:
    ///   - object:         an object
    ///
    public func removeObject<T>(_ object: T) {
        
        // cases are in alphabetical order
        switch object {
            
        case is AudioStream:
            audioStreams[(object as! AudioStream).id] = nil
            
        case is Memory:
            memories[(object as! Memory).id] = nil
            
        case is Meter:
            meters[(object as! Meter).id] = nil
            
        case is MicAudioStream:
            micAudioStreams[(object as! MicAudioStream).id] = nil
            
        case is Panadapter:
            panadapters[(object as! Panadapter).id] = nil
            
        case is xFlexAPI.Slice:
            slices[(object as! xFlexAPI.Slice).id] = nil
            
        case is Tnf:
            tnfs[(object as! Tnf).id] = nil
            
        case is TxAudioStream:
            txAudioStreams[(object as! TxAudioStream).id] = nil
            
        case is Waterfall:
            waterfalls[(object as! Waterfall).id] = nil
            
        default:
            _log.msg("Attempt to remove an unknown object type, \(object)", level: .error, function: #function, file: #file, line: #line)
        }
        
    }
    /// Establish a basic connection to Radio
    ///
    /// - Parameters:
    ///   - selectedRadio:          the Radio to connect to
    /// - Returns:                  success/failure
    ///
    public func connectSimple(selectedRadio: RadioParameters ) -> Bool {
        
        // inhibit the sending of Initial & secondary commands
        _connectSimple = true
        
        // initialize Equalizers (use the newer "sc" type)
        equalizers[.rxsc] = Equalizer(radio: self, eqType: .rxsc, queue: _equalizerQ)
        equalizers[.txsc] = Equalizer(radio: self, eqType: .txsc, queue: _equalizerQ)
        
        return _tcp.connect(radioParameters: selectedRadio)
    }
    /// Establish a connection to Radio
    ///
    /// - Parameters:
    ///   - selectedRadio:          the Radio to connect tog
    ///   - initial:                selected Initial command options (defaults to .all)
    ///   - secondary:              selected Secondary command options (defaults to .all)
    ///   - subscription:           selected Subscription command options (defaults to .all)
    /// - Returns:                  success/failure
    ///
    public func connect(selectedRadio: RadioParameters, primaryCommands: [Command] = [.allPrimary], secondaryCommands: [Command] = [.allSecondary], subscriptionCommands: [Command] = [.allSubscription] ) -> Bool {
        
        // enable the sending of Initial & secondary commands
        _connectSimple = false
        
        // initialize Equalizers (use the newer "sc" type)
        equalizers[.rxsc] = Equalizer(radio: self, eqType: .rxsc, queue: _equalizerQ)
        equalizers[.txsc] = Equalizer(radio: self, eqType: .txsc, queue: _equalizerQ)
        
        // setup default commands to be used at connect time (secondary commands are setup after the UDP port # is known)
        primaryCommandsArray = setupCommands(primaryCommands)
        subscriptionCommandsArray = setupCommands(subscriptionCommands)
        secondaryCommandsArray = setupCommands(secondaryCommands)
        
        return _tcp.connect(radioParameters: selectedRadio)
    }
    /// Send a command to the Radio (hardware)
    ///
    /// - Parameters:
    ///   - command:        a Command String
    ///   - callback:       a callback function (if any)
    ///
    public func sendWithCheck(_ command: String, diagnostic flag: Bool = false, replyTo callback: ReplyHandler? = nil) -> Bool {
        
        guard _tcp.isConnected else { return false }
        
        // tell the TcpManager to send the command (and optionally setup a callback)
        send(command, diagnostic: flag, replyTo: callback)
        
        return true
    }
    /// Send a command to the Radio (hardware)
    ///
    /// - Parameters:
    ///   - command:        a Command String
    ///   - callback:       a callback function (if any)
    ///
    public func send(_ command: String, diagnostic flag: Bool = false, replyTo callback: ReplyHandler? = nil) {
        
        // tell the TcpManager to send the command (and optionally setup a callback)
        let _ = _tcp.send(command, diagnostic: flag, replyTo: callback)
    }
    /// Send Vita packet to radio
    ///
    /// - Parameters:
    ///   - data:       a Vita-49 packet as Data
    ///
    public func sendVitaData(_ data: Data?) {
        
        if let dataToSend = data {
            
            _udp.sendData(dataToSend)
        }
    }
    /// Disconnect the Radio
    ///
    public func disconnect() {
        
        
        // FIXME: Add missing components
        
        
        NC.post(.tcpWillDisconnect, object: selectedRadio as Any?)
        
        _log.msg("Radio @ \(String(describing: selectedRadio?.ipAddress)) will disconnect", level: .info, function: #function, file: #file, line: #line)
        
        // if active, stop pinging
        if _pinger != nil { _pinger = nil }
        
        // disconnect TCP
        _tcp.disconnect()
        
        // unbind and close udp
        _udp.unbind()
        
        // ----- remove all objects -----
        
        // remove all xvtrs
        
        // clear all collections
        audioStreams.removeAll()
        equalizers.removeAll()
        iqStreams.removeAll()
        meters.removeAll()
        micAudioStreams.removeAll()
        opusStreams.removeAll()
        panadapters.removeAll()
        profiles.removeAll()
        slices.removeAll()
        tnfs.removeAll()
        txAudioStreams.removeAll()
        waterfalls.removeAll()
        
        replyHandlers.removeAll()
        
        nickname = ""
        _smartSdrMB = ""
        _psocMbtrxVersion = ""
        _psocMbPa100Version = ""
        _fpgaMbVersion = ""
        
        // clear lists
        antennaList.removeAll()
        rfGainList.removeAll()
        
    }
    /// Add a ReplyHandler object to the Reply List (to be invoked when the Command reply is received)
    ///
    /// - Parameters:
    ///   - sequenceId:     Sequence Number of the command
    ///   - replyTuple:     a ReplyTuple (replyTo:, command)
    ///
    public func addReplyHandler(_ sequenceId: SequenceId, replyTuple: ReplyTuple) {
        
        replyHandlers[sequenceId] = replyTuple
    }
//    
//    // ----------------------------------------------------------------------------
//    // MARK: - Public methods that send commands to the Radio (hardware)
//    
//    // ***** A *****
//    public func requestAntennaList() { send(kAntListCmd, replyTo: replyHandler) }       // Antenna List
//    public func atuClear() { send(kAtuCmd + "clear") }
//    public func atuStart() { send(kAtuCmd + "start") }
//    public func atuBypass() { send(kAtuCmd + "bypass") }
//    public func createAudioStream(_ channel: String, callback: ReplyHandler? = nil) -> Bool {
//        return sendWithCheck(kStreamCreateCmd + "dax" + "=\(channel)", replyTo: callback)
//    }
//    public func removeAudioStream(_ id: String) -> Bool {
//        return sendWithCheck(kStreamRemoveCmd + "0x\(id)")
//    }
//    // ***** I *****
//    public func createIqStream(_ channel: String, callback: ReplyHandler? = nil) -> Bool {
//        return sendWithCheck(kStreamCreateCmd + "daxiq" + "=\(channel)", replyTo: callback)
//    }
//    public func requestIqStream(_ channel: String, ip: String, port: Int, callback: ReplyHandler? = nil) -> Bool {
//        return sendWithCheck(kStreamCreateCmd + "daxiq" + "=\(channel) " + "ip" + "=\(ip) " + "port" + "=\(port)", replyTo: callback)
//    }
//    public func removeIqStream(_ id: String) { send(kStreamRemoveCmd + "0x\(id)") }
//    // ***** M *****
//    public func createMemory() { send(kMemoryCreateCmd) }
//    public func removeMemory(_ id: MemoryId) { send(kMemoryRemoveCmd + "\(id)") }
//    public func requestMeterList() { send(kMeterListCmd, replyTo: replyHandler) }
//    public func createMicAudioStream(callback: ReplyHandler? = nil) -> Bool {
//        return sendWithCheck(kMicStreamCreateCmd)
//    }
//    public func removeMicAudioStream(id: String) { send(kStreamRemoveCmd + "0x\(id)") }
//    public func requestMicList() { send(kMicListCmd, replyTo: replyHandler) }
//    // ***** O *****
//    public func startOffset(_ value: Bool) { _startOffset = value ; if value == false { send(kRadioCmd + "pll_start") } }
//    // ***** P *****
//    public func createPanafall(_ dimensions: CGSize) { if availablePanadapters > 0 {
//        send(kDisplayPanCmd + "create x=\(dimensions.width) y=\(dimensions.height)", replyTo: replyHandler) } }
//    public func createPanafall(frequency: Int, antenna: String? = nil, dimensions: CGSize? = nil) {
//        if availablePanadapters > 0 {
//            
//            var cmd = kDisplayPanCmd + "create freq" + "=\(frequency.hzToMhz())"
//            if antenna != nil { cmd += " ant=" + "\(antenna!)" }
//            if dimensions != nil { cmd += " x" + "=\(dimensions!.width)" + " y" + "=\(dimensions!.height)" }
//            send(cmd, replyTo: replyHandler)
//        }
//    }
//    public func removePanafall(_ id: PanadapterId) { send(kDisplayPanCmd + " remove 0x\(id)") }
//    public func profileGlobalDelete(_ name: String) { send(kProfileCmd + ProfileToken.global.rawValue + " delete \"" + name + "\"") }
//    public func profileGlobalSave(_ name: String) { send(kProfileCmd + ProfileToken.global.rawValue + " save \"" + name + "\"") }
//    public func profileMicDelete(_ name: String) { send(kProfileCmd + ProfileToken.mic.rawValue + " delete \"" + name + "\"") }
//    public func profileMicSave(_ name: String) { send(kProfileCmd + ProfileToken.mic.rawValue + " save \"" + name + "\"") }
//    public func profileTransmitDelete(_ name: String) { send(kProfileCmd + "transmit" + " save \"" + name + "\"") }
//    public func profileTransmitSave(_ name: String) { send(kProfileCmd + "transmit" + " save \"" + name + "\"") }
//    // ***** R *****
//    public func requestRemoteRxAudio(_ value: Bool) { send(kRemoteAudioCmd + Opus.OpusToken.remoteRxOn.rawValue + " \(value.asNumber())") }
//    public func requestRemoteTxAudio(_ value: Bool) { send(kRemoteAudioCmd + Opus.OpusToken.remoteTxOn.rawValue + "\(value.asNumber())") }
//    public func requestReboot() { send(kRadioCmd + " reboot") }
//    // ***** S *****
//    public func createSlice(frequency: Int, antenna: String, mode: String) { if availableSlices > 0 {
//        send(kSliceCmd + "create \(frequency.hzToMhz()) \(antenna) \(mode)") } }
//    public func createSlice(panadapter: Panadapter, frequency: Int = 0) { if availableSlices > 0 {
//        send(kSliceCmd + "create pan" + "=0x\(panadapter.id) \(frequency == 0 ? "" : "freq" + "=\(frequency.hzToMhz())")") } }
//    public func removeSlice(_ id: SliceId) { send(kSliceCmd + "remove" + " \(id)") }
//    public func requestSliceError(_ id: SliceId) { send(kSliceCmd + "get_error" + " \(id)", replyTo: replyHandler) }
//    public func requestSliceList() { send(kSliceCmd + "list", replyTo: replyHandler) }
//    // ***** T *****
//    public func createTnf(frequency: Int, panadapter: Panadapter) { send(kTnfCreateCmd + "freq" + "=\(calcTnfFreq(frequency, panadapter).hzToMhz())") }
//    public func removeTnf(tnf: Tnf) {
//        
//        send(kTnfRemoveCmd + " \(tnf.id)")
//        
//        NC.post(.tnfWillBeRemoved, object: tnf as Any?)
//        
//        removeObject(tnf)
//    }
//    public func setTransmit(_ value: Bool) { send(kXmitCmd + " \(value.asNumber())") }
//    public func createTxAudioStream(callback: ReplyHandler? = nil) -> Bool {
//        return sendWithCheck(kStreamCreateCmd + "daxtx", replyTo: callback)
//    }
//    public func removeTxAudioStream(_ id: String) { send(kStreamRemoveCmd + "0x\(id)") }
//    // ***** U *****
//    public func requestUptime() { send(kRadioUptimeCmd, replyTo: replyHandler) }
//    // ***** X ****
//    public func createXvtr(callback: ReplyHandler? = nil) -> Bool {
//        return sendWithCheck(kXvtrCmd + "create", replyTo: callback)
//    }
//    public func removeXvtr(_ id: String) { send(kXvtrCmd + "remove" + " \(id)") }
//    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods that send commands to the Radio (hardware)
    
//    // ***** A *****
//    public func requestAntennaList() { send(kAntListCmd, replyTo: replyHandler) }       // Antenna List
//    public func atuStart() { send(kAtuCmd + "start") }
//    public func atuBypass() { send(kAtuCmd + "bypass") }
//    public func createAudioStream(_ channel: String, callback: ReplyHandler? = nil) -> Bool {
//        return sendWithCheck(kStreamCreateCmd + "dax=\(channel)", replyTo: callback)
//    }
//    public func removeAudioStream(_ id: String) -> Bool {
//        return sendWithCheck(kStreamRemoveCmd + "0x\(id)")
//    }
//    // ***** I *****
//    public func createIqStream(_ channel: String, callback: ReplyHandler? = nil) -> Bool {
//        return sendWithCheck(kStreamCreateCmd + "daxiq=\(channel)", replyTo: callback)
//    }
//    public func requestIqStream(_ channel: String, ip: String, port: Int, callback: ReplyHandler? = nil) -> Bool {
//        return sendWithCheck(kStreamCreateCmd + "daxiq=\(channel) ip=\(ip) port=\(port)", replyTo: callback)
//    }
//    public func removeIqStream(_ id: String) { send("stream remove 0x\(id)") }
//    // ***** M *****
//    public func createMemory() { send("memory create") }
//    public func requestMeterList() { send(kMeterListCmd, replyTo: replyHandler) }
//    public func createMicAudioStream(callback: ReplyHandler? = nil) -> Bool {
//        return sendWithCheck(kMicStreamCreateCmd, replyTo: callback)
//    }
//    public func removeMicAudioStream(id: String) { send("stream remove 0x\(id)") }
//    public func requestMicList() { send(kMicListCmd, replyTo: replyHandler) }
//    // ***** O *****
//    public func startOffset(_ value: Bool) { startOffset = value ; if value == false { send("radio pll_start") } }
//    // ***** P *****
//    public func createPanafall(_ dimensions: CGSize) { if availablePanadapters > 0 {
//        send(kDisplayPanCmd + "create x=\(dimensions.width) y=\(dimensions.height)", replyTo: replyHandler) } }
//    public func createPanafall(frequency: Int, antenna: String? = nil, dimensions: CGSize? = nil) {
//        if availablePanadapters > 0 {
//            
//            var cmd = kDisplayPanCmd + "create freq=\(frequency.hzToMhz())"
//            if antenna != nil { cmd += " ant=\(antenna!)" }
//            if dimensions != nil { cmd += " x=\(dimensions!.width) y=\(dimensions!.height)" }
//            send(cmd, replyTo: replyHandler)
//        }
//    }
//    public func removePanafall(_ id: PanadapterId) { send(kDisplayPanCmd + " remove 0x\(id)") }
//    public func profileGlobalDelete(_ name: String) { send("profile global delete \"" + name + "\"") }
//    public func profileGlobalSave(_ name: String) { send("profile global save \"" + name + "\"") }
//    public func profileMicDelete(_ name: String) { send("profile mic delete \"" + name + "\"") }
//    public func profileMicSave(_ name: String) { send("profile mic save \"" + name + "\"") }
//    public func profileTransmitDelete(_ name: String) { send("profile transmit save \"" + name + "\"") }
//    public func profileTransmitSave(_ name: String) { send("profile tx save \"" + name + "\"") }
//    // ***** R *****
//    public func requestRemoteRxAudio(_ value: Bool) { send(kRemoteAudioCmd + "rx_on \(value.asNumber())") }
//    public func requestRemoteTxAudio(_ value: Bool) { send(kRemoteAudioCmd + "tx_on \(value.asNumber())") }
//    public func requestReboot() { send(kRadioCmd + " reboot") }
//    // ***** S *****
//    public func createSlice(frequency: Int, antenna: String, mode: String) { if availableSlices > 0 {
//        send(kSliceCmd + "create \(frequency.hzToMhz()) \(antenna) \(mode)") } }
//    public func createSlice(panadapter: Panadapter, frequency: Int = 0) { if availableSlices > 0 {
//        send(kSliceCmd + "create pan=0x\(panadapter.id) \(frequency == 0 ? "" : "freq=\(frequency.hzToMhz())")") } }
//    public func removeSlice(_ id: SliceId) { send(kSliceCmd + "remove \(id)") }
//    public func requestSliceError(_ id: SliceId) { send(kSliceCmd + "get_error \(id)", replyTo: replyHandler) }
//    public func requestSliceList() { send(kSliceCmd + "list", replyTo: replyHandler) }
//    // ***** T *****
//    public func createTnf(frequency: Int, panadapter: Panadapter) { send("tnf create freq=\(calcTnfFreq(frequency, panadapter).hzToMhz())") }
//    public func removeTnf(tnf: Tnf) {
//        
//        send(kTnfCommand + "remove \(tnf.id)")
//        
//        NC.post(.tnfWillBeRemoved, object: tnf as Any?)
//        
//        removeObject(tnf)
//    }
//    public func setTransmit(_ value: Bool) { send(kXmitCmd + " \(value.asNumber())") }
//    public func createTxAudioStream(callback: ReplyHandler? = nil) -> Bool {
//        return sendWithCheck(kStreamCreateCmd + "daxtx", replyTo: callback)
//    }
//    public func removeTxAudioStream(_ id: String) { send(kStreamRemoveCmd + "0x\(id)") }
//    // ***** U *****
//    public func requestUptime() { send(kRadioUptimeCmd, replyTo: replyHandler) }
//    // ***** X ****
//    public func createXvtr(callback: ReplyHandler? = nil) -> Bool {
//        return sendWithCheck(kXvtrCmd + "create", replyTo: callback)
//    }
//    public func removeXvtr(_ id: String) { send(kXvtrCmd + "remove " + id) }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    /// Determine a frequency for a Tnf
    ///
    /// - Parameters:
    ///   - frequency:      tnf frequency (may be 0)
    ///   - panadapter:     a Panadapter reference
    /// - Returns:          the calculated Tnf frequency
    ///
    func calcTnfFreq(_ frequency: Int, _ panadapter: Panadapter) -> Int {
        var freqDiff = 1_000_000_000
        var targetSlice: xFlexAPI.Slice?
        var tnfFreq = frequency
        
        // if frequency is 0, calculate a frequency
        if tnfFreq == 0 {
            
            // for each Slice on this Panadapter find the one within freqDiff and closesst to the center
            for slice in findSlicesOn(panadapter.id) {
                
                // how far is it from the center?
                let diff = abs(slice.frequency - panadapter.center)
                
                // if within freqDiff of center
                if diff < freqDiff {
                    
                    // update the freqDiff
                    freqDiff = diff
                    // save the slice
                    targetSlice = slice
                }
            }
            // do we have a Slice?
            if let slice = targetSlice {
                
                // YES, what mode?
                switch slice.mode {
                    
                case "LSB", "DIGL":
                    tnfFreq = slice.frequency + (( slice.filterLow - slice.filterHigh) / 2)
                    
                case "RTTY":
                    tnfFreq = slice.frequency - (slice.rttyShift / 2)
                    
                case "CW", "AM", "SAM":
                    tnfFreq = slice.frequency + ( slice.filterHigh / 2)
                    
                case "USB", "DIGU", "FDV":
                    tnfFreq = slice.frequency + (( slice.filterLow - slice.filterHigh) / 2)
                    
                default:
                    tnfFreq = slice.frequency + (( slice.filterHigh - slice.filterLow) / 2)
                }
                
            } else {
                
                // NO, put it in the panadapter center
                tnfFreq = panadapter.center
            }
        }
        return tnfFreq
    }
    
    /// Called by the Tcp & Udp Manager delegates when a connection state change occurs
    ///
    /// - Parameters:
    ///   - state:  the new State
    ///
    func setConnectionState(_ state: ConnectionState) {
        
        connectionState = state
        
        DispatchQueue.main.async { [unowned self] in
            
            // take appropriate action
            switch state {
                
            case .tcpConnected(let host, let port):
                
                // log it
                self._log.msg("TCP connected to Radio IP \(host), Port \(port)", level: .verbose, function: #function, file: #file, line: #line)
                
                // a tcp connection has been established
                NC.post(.tcpDidConnect, object: nil)
                
                self._tcp.readNext()
                
                // establish a UDP port for the Data Streams
                self._udp.bind()
                
            case .udpBound(let port):
                
                // UDP (streams) connection established, initialize the radio
                self._log.msg("UDP bound to Port \(port)", level: .verbose, function: #function, file: #file, line: #line)
                
                NC.post(.udpDidBind, object: nil)
                
                // a UDP bind has been established
                self._udp.beginReceiving()
                
            case .clientConnected():
                
                self._log.msg("Client connection established", level: .verbose, function: #function, file: #file, line: #line)
                
                // send the initial commands
                if !self._connectSimple { self.sendCommands(self.primaryCommandsArray) }
                
                // TCP & UDP connections established, inform observers
                NC.post(.clientDidConnect, object: self.selectedRadio as Any?)
                
                // send the subscription commands
                if !self._connectSimple { self.sendCommands(self.subscriptionCommandsArray) }
                
                // send the secondary commands
                if !self._connectSimple { self.sendCommands(self.secondaryCommandsArray) }
                
                // tell the radio which UDP port number was selected for incoming UDP streams
                self.send(Command.clientUdpPort.rawValue + "\(self._udp.port)")
                
                // start pinging
                if self.pingerEnabled { self._pinger = Pinger(tcpManager: self._tcp, pingQ: self._pingQ) }
                
            case .disconnected(let reason):
                
                // TCP connection disconnected
                self._log.msg("Disconnected, reason = \(reason)", level: .error, function: #function, file: #file, line: #line)
                
                NC.post(.tcpDidDisconnect, object: reason)
                
            case .update( _, _):
                
                // FIXME: need to handle Update State ???
                self._log.msg("Update in process", level: .info, function: #function, file: #file, line: #line)
            }
        }
    }
    // --------------------------------------------------------------------------------
    // MARK: - First level parser
    //      Note: Called on the tcpQ, executes on the parseQ
    // --------------------------------------------------------------------------------
    
    /// Parse inbound message types (commands). format: <prefix><suffix>
    ///
    /// - Parameters:
    ///   - message:    a Message String
    ///
    func parse(_ message: String) {
        
        // use the parse (sync, serial)
        _parseQ.sync {
            
            // get all except the first character
            let suffix = String(message.characters.dropFirst())
            
            // switch on the first character
            switch message[message.startIndex] {
                
            case "H":   // Handle type
                self._connectionHandle = suffix
                
            case "M":   // Message Type
                self.parseMessage(suffix)
                
            case "R":   // Reply Type
                self.parseReply(suffix)
                
            case "S":   // Status type
                self.parseStatus(suffix)
                
            case "V":   // Version Type
                self._hardwareVersion = suffix
                
            default:    // Unknown Type
                _log.msg("Unexpected message type from radio - " + message, level: .debug, function: #function, file: #file, line: #line)
            }
        }
    }
    
    // --------------------------------------------------------------------------------
    // MARK: - Second level parsers
    //      Note: All are executed on the parseQ
    // --------------------------------------------------------------------------------
    
    /// Parse a Message. format: <messageNumber>|<messageText>
    ///
    /// - Parameters:
    ///   - commandSuffix:      a Command Suffix
    ///
    private func parseMessage(_ commandSuffix: String) {
        
        // separate it into its components
        let components = commandSuffix.components(separatedBy: "|")
        
        // ignore incorrectly formatted messages
        if components.count < 2 {
            
            _log.msg("Incomplete message, c\(commandSuffix)", level: .debug, function: #function, file: #file, line: #line)
            return
        }        
        // bits 24-25 are the errorCode???
        let msgNumber = UInt32(components[0]) ?? 0
        let errorCode = Int((msgNumber & 0x03000000) >> 24)
        let msgText = components[1]
        
        // log it
        _log.msg(msgText, level: MessageLevel(rawValue: errorCode) ?? MessageLevel.error, function: #function, file: #file, line: #line)
        
        // FIXME: Take action on some/all errors?
    }
    /// Parse a Reply message. format: <sequenceNumber>|<hexResponse>|<message>[|<debugOutput>]
    ///
    /// - Parameters:
    ///   - commandSuffix:      a Reply Suffix
    ///
    private func parseReply(_ replySuffix: String) {
        
        // separate it into its components
        let components = replySuffix.components(separatedBy: "|")
        
        // ignore incorrectly formatted replies
        if components.count < 2 {
            
            _log.msg("Incomplete reply, r\(replySuffix)", level: .warning, function: #function, file: #file, line: #line)
            return
        }
        
        // is there an Object expecting to be notified?
        if let replyTuple = replyHandlers[ components[0] ] {
            
            // YES, an Object is waiting for this reply, send the Command to the Handler on that Object
            
            let command = replyTuple.command
            // was a Handler specified?
            if let handler = replyTuple.replyTo {
                
                // YES, call the Handler
                handler(command, components[0], components[1], (components.count == 3) ? components[2] : "")
                
            } else {
                
                // NO, log it if it is a non-zero Reply (i.e a possible error)
                if components[1] != kNoError {
                    _log.msg("Unhandled non-zero reply, c\(components[0])|\(command), r\(replySuffix)", level: .warning, function: #function, file: #file, line: #line)
                }
            }
            // Remove the object from the notification list
            replyHandlers[components[0]] = nil
            
            
        } else {
            
            // no Object is waiting for this reply, log it if it is a non-zero Reply (i.e a possible error)
            if components[1] != kNoError {
                _log.msg("Unhandled non-zero reply, r\(replySuffix)", level: .warning, function: #function, file: #file, line: #line)
            }
        }
    }
    /// Parse a Status message. format: <apiHandle>|<message>, where <message> is of the form: <msgType> <otherMessageComponents>
    ///
    /// - Parameters:
    ///   - commandSuffix:      a Command Suffix
    ///
    private func parseStatus(_ commandSuffix: String) {
        
        // separate it into its components ( [0] = <apiHandle>, [1] = <message> )
        var components = commandSuffix.components(separatedBy: "|")
        
        // ignore incorrectly formatted status
        guard components.count > 1 else {
            
            _log.msg("Incomplete status, c\(commandSuffix)", level: .warning, function: #function, file: #file, line: #line)
            return
        }
        
        // find the space & get the msgType
        let spaceRange = components[1].range(of: " ")
        let msgType = components[1].substring(with: Range<String.Index>(components[1].startIndex..<spaceRange!.lowerBound))
        
        // everything past the msgType is in the remainder
        let remainder = components[1].substring(with: Range<String.Index>(spaceRange!.upperBound..<components[1].endIndex))
        
        // Check for unknown Message Types
        guard let token = StatusToken(rawValue: msgType.lowercased())  else {
            
            // unknown Message Type, log it and ignore the message
            _log.msg("Unknown token - \(msgType)", level: .warning, function: #function, file: #file, line: #line)
            return
        }
        
        // FIXME: file, mixer, stream, turf, usbCable & xvtr Not currently implemented
        
        
        // Known Message Types, in alphabetical order
        switch token {
            
        case .audioStream:
            //      format: <AudioStreamId> <key=value> <key=value> ...<key=value>
            parseAudioStream( keyValuesArray(remainder), notInUse: remainder.contains("in_use=0"))
            
        case .atu:
            //      format: <key=value> <key=value> ...<key=value>
            parseAtu( keyValuesArray(remainder))
            
        case .client:
            //      kv                0         1            2
            //      format: client <handle> connected
            //      format: client <handle> disconnected <forced=1/0>
            
            var isMyHandle = false
            
            let keyValues = keyValuesArray(remainder)
            
            guard keyValues.count >= 2 else {
                
                _log.msg("Invalid client status", level: .warning, function: #function, file: #file, line: #line)
                return
            }
            
            // is there an API Handle?
            if let apiHandle = _connectionHandle {
                
                // YES, is the Status Command directed to this client?
                isMyHandle = (apiHandle == components[0] || components[0] == "0")
            }
            
            
            if isMyHandle {
                
                if keyValues[1].key == "connected" {
                    
                    setConnectionState(.clientConnected)
                    
                } else if (keyValues[1].key == "disconnected" && keyValues[2].key == "forced") {
                    
                    // FIXME: Handle the disconnect
                    
                    _log.msg("Disconnect, forced=\(keyValues[2].value)", level: .verbose, function: #function, file: #file, line: #line)
                    
                } else {
                    
                    _log.msg("Unprocessed \(msgType), \(remainder)", level: .warning, function: #function, file: #file, line: #line)
                }
            }
            
        case .cwx:
            // replace some characters to avoid parsing conflicts
            parseCwx( keyValuesArray(fixString(remainder )))
            
        case .daxiq:
            //      format: <daxChannel> <key=value> <key=value> ...<key=value>
            //            parseDaxiq( keyValuesArray(remainder))
            
            _log.msg("Unprocessed \(msgType), \(remainder)", level: .warning, function: #function, file: #file, line: #line)
            
        case .display:
            //     format: <displayType> <streamId> <key=value> <key=value> ...<key=value>
            parseDisplay( keyValuesArray(remainder), notInUse: remainder.contains("removed"))
            
        case .eq:
            //      format: txsc <key=value> <key=value> ...<key=value>
            //      format: rxsc <key=value> <key=value> ...<key=value>
            
            // ignore old formats ("tx" & "rx")
            if remainder.contains("txsc") || remainder.contains("rxsc") {
                
                parseEqualizer( keyValuesArray(remainder) )
            }
            
        case .file:
            
            _log.msg("Unprocessed \(msgType), \(remainder)", level: .warning, function: #function, file: #file, line: #line)
            
        case .gps:
            //     format: <key=value>#<key=value>#...<key=value>
            parseGps( keyValuesArray(remainder, delimiter: "#"))
            
        case .interlock:
            //      format: <key=value> <key=value> ...<key=value>
            parseInterlock( keyValuesArray(remainder))
            
        case .memory:
            //      format: <memoryId> <key=value>,<key=value>,...<key=value>
            parseMemory( keyValuesArray(remainder), notInUse: remainder.contains("removed"))
            
        case .meter:
            //     format: <meterNumber.key=value>#<meterNumber.key=value>#...<meterNumber.key=value>
            parseMeter( keyValuesArray(remainder, delimiter: "#"), notInUse: remainder.contains("removed"))
            
        case .micAudioStream:
            //      format: <MicAudioStreamId> <key=value> <key=value> ...<key=value>
            parseMicAudioStream( keyValuesArray(remainder), notInUse: remainder.contains("in_use=0"))
            
        case .mixer:
            
            _log.msg("Unprocessed \(msgType), \(remainder)", level: .warning, function: #function, file: #file, line: #line)
            
        case .opusStream:
            //     format: <opusId> <key=value> <key=value> ...<key=value>
            parseOpus( keyValuesArray(remainder))
            
        case .profile:
            //     format: global list=<value>^<value>^...<value>^
            //     format: global current=<value>
            //     format: tx list=<value>^<value>^...<value>^
            //     format: tx current=<value>
            //     format: mic list=<value>^<value>^...<value>^
            //     format: mic current=<value>
            parseProfile( keyValuesArray(remainder))
            
        case .radio:
            //     format: <key=value> <key=value> ...<key=value>
            parseRadio( keyValuesArray(remainder))
            
        case .slice:
            //     format: <sliceId> <key=value> <key=value> ...<key=value>
            parseSlice( keyValuesArray(remainder), notInUse: remainder.contains("in_use=0"))
            
        case .stream:
            //     format: <streamId> <key=value> <key=value> ...<key=value>
            parseStream( keyValuesArray(remainder))
            
        case .tnf:
            //     format: <tnfId> <key=value> <key=value> ...<key=value>
            parseTnf( keyValuesArray(remainder))
            
        case .transmit:
            //      format: <key=value> <key=value> ...<key=value>
            parseTransmit( keyValuesArray(remainder))
            
        case .turf:
            
            _log.msg("Unprocessed \(msgType), \(remainder)", level: .warning, function: #function, file: #file, line: #line)
            
        case .txAudioStream:
            //      format: <TxAudioStreamId> <key=value> <key=value> ...<key=value>
            parseTxAudioStream( keyValuesArray(remainder), notInUse: remainder.contains("in_use=0"))
            
        case .usbCable:
            //      format:
            parseUsbCable( keyValuesArray(remainder))
            
        case .waveform:
            //      format: <key=value> <key=value> ...<key=value>
            parseWaveform( keyValuesArray(remainder))
            
        case .xvtr:
            //      format: <name> <key=value> <key=value> ...<key=value>
            parseXvtr( keyValuesArray(remainder), notInUse: remainder.contains("in_use=0"))
        }
    }
    
    // --------------------------------------------------------------------------------
    // MARK: - Third level parsers
    //      Note: All are executed on the parseQ
    // --------------------------------------------------------------------------------
    
    // FIXME: Should parsers ignore Status message sent to other connection handles?
    
    /// Prepare to parse an AudioStream status message
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///   - notInUse:       true = "in_use=0", otherwise false
    ///
    private func parseAudioStream(_ keyValues: KeyValuesArray, notInUse: Bool) {
        // Format:  <streamId, > <"dax", channel> <"in_use", 1|0> <"slice", number> <"ip", ip> <"port", port>
        
        //get the AudioStreamId (remove the "0x" prefix)
        let streamId = String(keyValues[0].key.characters.dropFirst(2))
        
        // should the AudioStream be removed?
        if notInUse {
            
            // YES, notify all observers
            NC.post(.audioStreamWillBeRemoved, object: audioStreams[streamId] as Any?)
            
            removeObject(audioStreams[streamId])
            
        } else {
            
            // does the AudioStream exist?
            if audioStreams[streamId] == nil {
                
                // NO, create a new AudioStream & add it to the AudioStreams collection
                audioStreams[streamId] = AudioStream(radio: self, id: streamId, queue: _audioStreamQ)
            }
            // pass the remaining key values to the AudioStream for parsing
            audioStreams[streamId]!.parseKeyValues( Array(keyValues.dropFirst(1)) )
        }
    }
    /// Parse an Atu status message
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///
    private func parseAtu(_ keyValues: KeyValuesArray) {
        // Format: <"status", value> <"memories_enabled", 1|0> <"using_mem", 1|0>
        
        // process each key/value pair, <key=value>
        for kv in keyValues {
            
            // Check for Unknown token
            guard let token = AtuToken(rawValue: kv.key.lowercased())  else {
                
                // unknown Token, log it and ignore this token
                _log.msg("Unknown token - \(kv.key)", level: .debug, function: #function, file: #file, line: #line)
                continue
            }
            
            // get the Bool version of the value
            let bValue = (kv.value).bValue()
            
            // Known tokens, in alphabetical order
            switch token {
                
            case .status:
                willChangeValue(forKey: "atuStatus")
                _atuStatus = kv.value
                didChangeValue(forKey: "atuStatus")
                
            case .atuEnabled:
                willChangeValue(forKey: "atuEnabled")
                _atuEnabled = bValue
                didChangeValue(forKey: "atuEnabled")
                
            case .memoriesEnabled:
                willChangeValue(forKey: "atuMemoriesEnabled")
                _atuMemoriesEnabled = bValue
                didChangeValue(forKey: "atuMemoriesEnabled")
                
            case .usingMemories:
                willChangeValue(forKey: "atuUsingMemories")
                _atuUsingMemories = bValue
                didChangeValue(forKey: "atuUsingMemories")
                
            }
        }
    }
    /// Prepare to parse a Cwx status message
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///
    private func parseCwx(_ keyValues: KeyValuesArray) {
        
        // pass the key values to the Cwx for parsing
        cwx.parseKeyValues(keyValues)
    }
    
    // FIXME: How to integrate this with the Stream Status?
    
    //    /// Prepare to parse a DaxIq status message
    //    ///
    //    /// - Parameters:
    //    ///   - keyValues:      a KeyValuesArray
    //    ///
    //    private func parseDaxiq(_ keyValues: KeyValuesArray) {
    //        // Format: <channel, ""> <"pan", streamId> <"rate", value> <"capacity", value> <"available", value>
    //
    //        // get the Dax Channel
    //        let channel = Int(keyValues[0].key) ?? 0
    //
    //        // does the DaxIQ stream exist?
    //        var iqStream = findIqStreamBy(daxIqChannel: channel)
    //        if iqStream == nil {
    //
    //            // NO, create a new Stream
    //            iqStream = IqStream(radio: self, id: queue: _iqStreamQ)
    //        }
    //        // pass the key values to the IqStream for parsing
    //        iqStream!.parseKeyValues( Array(keyValues.dropFirst(1)) )
    //    }
    /// Prepare to parse a Display status message
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///   - notInUse:       true = "in_use=0", otherwise false
    ///
    private func parseDisplay(_ keyValues: KeyValuesArray, notInUse: Bool) {
        // ***** Panadapter Formats *****
        //
        // Format: <"pan", ""> <id, ""> <"wnb", 1|0> <"wnb_level", value> <"wnb_updating", 1|0> <"x_pixels", value> <"y_pixels", value>
        //          <"center", value>, <"bandwidth", value> <"min_dbm", value> <"max_dbm", value> <"fps", value> <"average", value>
        //          <"weighted_average", 1|0> <"rfgain", value> <"rxant", value> <"wide", 1|0> <"loopa", 1|0> <"loopb", 1|0>
        //          <"band", value> <"daxiq", 1|0> <"daxiq_rate", value> <"capacity", value> <"available", value> <"waterfall", streamId>
        //          <"min_bw", value> <"max_bw", value> <"xvtr", value> <"pre", value> <"ant_list", value>
        //      OR
        // Format: <"pan", ""> <id, ""> <"center", value> <"xvtr", value>
        //      OR
        // Format: <"pan", ""> <id, ""> <"rxant", value> <"loopa", 1|0> <"loopb", 1|0> <"ant_list", value>
        //      OR
        // Format: <"pan", ""> <id, ""> <"rfgain", value> <"pre", value>
        //
        // Format: <"pan", ""> <id, ""> <"wnb", 1|0> <"wnb_level", value> <"wnb_updating", 1|0>
        //      OR
        // Format: <"pan", ""> <id, ""> <"daxiq", value> <"daxiq_rate", value> <"capacity", value> <"available", value>
        
        // ***** Waterfall Formats *****
        //
        // Format: <"waterfall", ""> <id, ""> <"x_pixels", value> <"center", value> <"bandwidth", value> <"line_duration", value>
        //          <"rfgain", value> <"rxant", value> <"wide", 1|0> <"loopa", 1|0> <"loopb", 1|0> <"band", value> <"daxiq", value>
        //          <"daxiq_rate", value> <"capacity", value> <"available", value> <"panadapter", streamId>=40000000 <"color_gain", value>
        //          <"auto_black", 1|0> <"black_level", value> <"gradient_index", value> <"xvtr", value>
        //      OR
        // Format: <"waterfall", ""> <id, ""> <"rxant", value> <"loopa", 1|0> <"loopb", 1|0>
        //      OR
        // Format: <"waterfall", ""> <id, ""> <"rfgain", value>
        //      OR
        // Format: <"waterfall", ""> <id, ""> <"daxiq", value> <"daxiq_rate", value> <"capacity", value> <"available", value>
        
        // get the Type & remove it
        let displayType = keyValues[0].key
        
        //get the streamId (remove the "0x" prefix) & remove it
        let streamId = String(keyValues[1].key.characters.dropFirst(2))
        
        // Check for unknown Display Types
        guard let token = DisplayToken(rawValue: displayType.lowercased()) else {
            
            // unknown Display Type, log it and ignore the message
            _log.msg("Unknown Display - \(displayType)", level: .debug, function: #function, file: #file, line: #line)
            return
        }
        
        // should the object be removed?
        if notInUse {
            
            // YES, Which Display Type?
            switch token {
                
            case .panadapter:
                
                // notify all observers
                NC.post(.panadapterWillBeRemoved, object: panadapters[streamId] as Any?)
                
                removeObject(panadapters[streamId])
                
            case .waterfall:
                
                // notify all observers
                NC.post(.waterfallWillBeRemoved, object: waterfalls[streamId] as Any?)
                
                removeObject(waterfalls[streamId])
            }
            
        } else {
            
            // NO, Which Display Type?
            switch token {
                
            case .panadapter:
                
                // does it exist?
                if panadapters[streamId] == nil {
                    
                    // NO, Create a Panadapter & add it to the Panadapters collection
                    panadapters[streamId] = Panadapter(radio: self, id: streamId, queue: _panadapterQ)
                }
                // pass the key values to the Panadapter for parsing
                panadapters[streamId]!.parseKeyValues(Array(keyValues.dropFirst(2)))
                
            case .waterfall:
                
                // does it exist?
                if waterfalls[streamId] == nil {
                    
                    // NO, Create a Waterfall & add it to the Waterfalls collection
                    waterfalls[streamId] = Waterfall(streamId: streamId, radio: self, queue: _waterfallQ)
                }
                // pass the key values to the Waterfall for parsing
                waterfalls[streamId]!.parseKeyValues(Array(keyValues.dropFirst(2)))
            }
        }
    }
    /// Parse an Equalizer status message
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///
    private func parseEqualizer(_ keyValues: KeyValuesArray) {
        // Format: <type, ""> <"mode", 1|0>, <"63Hz", value> <"125Hz", value> <"250Hz", value> <"500Hz", value>
        //          <"1000Hz", value> <"2000Hz", value> <"4000Hz", value> <"8000Hz", value>
        
        var equalizer: Equalizer?
        
        // get the Type
        let type = keyValues[0].key
        
        // determine the type of Equalizer
        switch type {
            
        case EqualizerType.txsc.rawValue:
            // transmit equalizer
            equalizer = equalizers[.txsc]
            
        case EqualizerType.rxsc.rawValue:
            // receive equalizer
            equalizer = equalizers[.rxsc]
            
        case EqualizerType.rx.rawValue, EqualizerType.tx.rawValue:
            // obslete type, ignore it
            break
            
        default:
            // unknown type, log & ignore it
            _log.msg("Unknown EQ - \(type)", level: .debug, function: #function, file: #file, line: #line)
        }
        // if an equalizer was found
        if let equalizer = equalizer {
            
            // pass the key values to the Equalizer for parsing
            equalizer.parseKeyValues( Array(keyValues.dropFirst(1)) )
        }
    }
    /// Parse a Gps status message
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///
    private func parseGps(_ keyValues: KeyValuesArray) {
        // Format: <"lat", value> <"lon", value> <"grid", value> <"altitude", value> <"tracked", value> <"visible", value> <"speed", value>
        //          <"freq_error", value> <"status", "Not Present" | "Present"> <"time", value> <"track", value>
        
        // process each key/value pair, <key=value>
        for kv in keyValues {
            
            // Check for Unknown token
            guard let token = GpsToken(rawValue: kv.key.lowercased())  else {
                
                // unknown Token, log it and ignore this token
                _log.msg("Unknown token - \(kv.key)", level: .debug, function: #function, file: #file, line: #line)
                continue
            }
            
            // get the Bool and Double versions of the value
            let bValue = (kv.value).bValue()
            let dValue = (kv.value).dValue()
            
            // Known tokens, in alphabetical order
            switch token {
                
            case .altitude:
                willChangeValue(forKey: "gpsAltitude")
                _gpsAltitude = kv.value
                didChangeValue(forKey: "gpsAltitude")
                
            case .frequencyError:
                willChangeValue(forKey: "gpsFrequencyError")
                _gpsFrequencyError = dValue
                didChangeValue(forKey: "gpsFrequencyError")
                
            case .status:
                willChangeValue(forKey: "gpsStatus")
                _gpsStatus = kv.value
                didChangeValue(forKey: "gpsStatus")
                
            case .grid:
                willChangeValue(forKey: "gpsGrid")
                _gpsGrid = kv.value
                didChangeValue(forKey: "gpsGrid")
                
            case .latitude:
                willChangeValue(forKey: "gpsLatitude")
                _gpsLatitude = kv.value
                didChangeValue(forKey: "gpsLatitude")
                
            case .longitude:
                willChangeValue(forKey: "gpsLongitude")
                _gpsLongitude = kv.value
                didChangeValue(forKey: "gpsLongitude")
                
            case .speed:
                willChangeValue(forKey: "gpsSpeed")
                _gpsSpeed = kv.value
                didChangeValue(forKey: "gpsSpeed")
                
            case .time:
                willChangeValue(forKey: "gpsTime")
                _gpsTime = kv.value
                didChangeValue(forKey: "gpsTime")
                
            case .track:
                willChangeValue(forKey: "gpsTrack")
                _gpsTrack = dValue
                didChangeValue(forKey: "gpsTrack")
                
            case .tracked:
                willChangeValue(forKey: "gpsTracked")
                _gpsTracked = bValue
                didChangeValue(forKey: "gpsTracked")
                
            case .visible:
                willChangeValue(forKey: "gpsVisible")
                _gpsVisible = bValue
                didChangeValue(forKey: "gpsVisible")
            }
        }
        
    }
    /// Parse an Interlock status message
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///
    private func parseInterlock(_ keyValues: KeyValuesArray) {
        // Format: <"timeout", value> <"acc_txreq_enable", 1|0> <"rca_txreq_enable", 1|0> <"acc_txreq_polarity", 1|0> <"rca_txreq_polarity", 1|0>
        //              <"tx1_enabled", 1|0> <"tx1_delay", value> <"tx2_enabled", 1|0> <"tx2_delay", value> <"tx3_enabled", 1|0> <"tx3_delay", value>
        //              <"acc_tx_enabled", 1|0> <"acc_tx_delay", value> <"tx_delay", value>
        //      OR
        // Format: <"state", value> <"tx_allowed", 1|0>
        
        // process each key/value pair, <key=value>
        for kv in keyValues {
            
            // Check for Unknown token
            guard let token = InterlockToken(rawValue: kv.key.lowercased())  else {
                
                // unknown Token, log it and ignore this token
                _log.msg("Unknown token - \(kv.key)", level: .debug, function: #function, file: #file, line: #line)
                continue
            }
            
            // get the Integer and Bool versions of the value
            let iValue = (kv.value).iValue()
            let bValue = (kv.value).bValue()
            
            // Known tokens, in alphabetical order
            switch token {
                
            case .accTxEnabled:
                willChangeValue(forKey: "accTxEnabled")
                _accTxEnabled = bValue
                didChangeValue(forKey: "accTxEnabled")
                
            case .accTxDelay:
                willChangeValue(forKey: "accTxDelay")
                _accTxDelay = iValue
                didChangeValue(forKey: "accTxDelay")
                
            case .accTxReqEnabled:
                willChangeValue(forKey: "accTxReqEnabled")
                _accTxReqEnabled = bValue
                didChangeValue(forKey: "accTxReqEnabled")
                
            case .accTxReqPolarity:
                willChangeValue(forKey: "accTxReqPolarity")
                _accTxReqPolarity = bValue
                didChangeValue(forKey: "accTxReqPolarity")
                
            case .rcaTxReqEnabled:
                willChangeValue(forKey: "rcaTxReqEnabled")
                _rcaTxReqEnabled = bValue
                didChangeValue(forKey: "rcaTxReqEnabled")
                
            case .rcaTxReqPolarity:
                willChangeValue(forKey: "rcaTxReqPolarity")
                _rcaTxReqPolarity = bValue
                didChangeValue(forKey: "rcaTxReqPolarity")
                
            case .reason:
                willChangeValue(forKey: "reason")
                _reason = kv.value
                didChangeValue(forKey: "reason")
                
            case .source:
                willChangeValue(forKey: "source")
                _source = kv.value
                didChangeValue(forKey: "source")
                
            case .state:
                willChangeValue(forKey: "state")
                _state = kv.value
                didChangeValue(forKey: "state")
                
            case .timeout:
                willChangeValue(forKey: "timeout")
                _timeout = iValue
                didChangeValue(forKey: "timeout")
                
            case .txAllowed:
                willChangeValue(forKey: "txAllowed")
                _txAllowed = bValue
                didChangeValue(forKey: "txAllowed")
                
            case .txDelay:
                willChangeValue(forKey: "txDelay")
                _txDelay = iValue
                didChangeValue(forKey: "txDelay")
                
            case .tx1Enabled:
                willChangeValue(forKey: "key")
                _tx1Enabled = bValue
                didChangeValue(forKey: "key")
                
            case .tx1Delay:
                willChangeValue(forKey: "tx1Enabled")
                _tx1Delay = iValue
                didChangeValue(forKey: "tx1Enabled")
                
            case .tx2Enabled:
                willChangeValue(forKey: "tx2Enabled")
                _tx2Enabled = bValue
                didChangeValue(forKey: "tx2Enabled")
                
            case .tx2Delay:
                willChangeValue(forKey: "tx2Delay")
                _tx2Delay = iValue
                didChangeValue(forKey: "tx2Delay")
                
            case .tx3Enabled:
                willChangeValue(forKey: "tx3Enabled")
                _tx3Enabled = bValue
                didChangeValue(forKey: "tx3Enabled")
                
            case .tx3Delay:
                willChangeValue(forKey: "tx3Delay")
                _tx3Delay = iValue
                didChangeValue(forKey: "tx3Delay")
            }
        }
    }
    /// Prepare to parse a Memory status message
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///   - notInUse:       true = "in_use=0", otherwise false
    ///
    private func parseMemory(_ keyValues: KeyValuesArray, notInUse: Bool) {
        var memory: Memory?
        
        // get the Memory Id
        let memoryId = keyValues[0].key
        
        // is it marked for removal?
        if notInUse {
            
            // YES, notify all observers
            NC.post(.memoryWillBeRemoved, object: memories[memoryId] as Any?)
            
            // remove it from the its collection
            removeObject(memories[memoryId])
            
        } else {
            
            // does it exist?
            memory = memories[memoryId]
            if memory == nil {
                
                // NO, create a new Memory & add it to the Memories collection
                memory = Memory(radio: self, id: memoryId, queue: _memoryQ)
                memories[memoryId] = memory
            }
            // pass the key values to the Memory for parsing
            memory!.parseKeyValues( Array(keyValues.dropFirst(1)) )
        }
    }
    /// Prepare to parse a Meter status message
    ///
    /// - Parameters:
    ///   - remainder:      remainder of the command String
    ///   - keyValues:      a KeyValuesArray
    ///   - notInUse:       true = "in_use=0", otherwise false
    ///
    private func parseMeter(_ keyValues: KeyValuesArray, notInUse: Bool) {
        // Format: <number."src", src> <number."nam", name> <number."hi", highValue> <number."desc", description> <number."unit", unit> ,number."fps", fps>
        //      OR
        // Format: <number "removed", "">
        
        // is it marked for removal?
        if notInUse {
            
            // YES, extract the Meter Number
            let meterId = keyValues[0].key.components(separatedBy: " ")[0]
            
            // does it exist?
            if let meter = meters[meterId] {
                
                // is it a Slice meter?
                if meter.source == Meter.MeterSource.slice.rawValue {
                    
                    // YES, get the Slice
                    if let slice = slices[meter.number] {
                        
                        // remove the Meter from the Slice
                        slice.removeMeter(meterId)
                    }
                }
                // notify all observers
                NC.post(.meterWillBeRemoved, object: meters[meterId] as Any?)
                
                // remove it from the its collection
                removeObject(meters[meterId])
            }
            
        } else {
            
            // NO, extract the Meter Number from the first KeyValues entry
            let components = keyValues[0].key.components(separatedBy: ".")
            if components.count != 2 {return }
            
            // the Meter Id is the 0th item (MeterNumber)
            let meterId = components[0]
            
            // does the meter exist?
            if meters[meterId] == nil {
                
                // NO, create a new Meter & add it to the Meters collection
                meters[meterId] = Meter(radio: self, id: meterId, queue: _meterQ)
                
                // is it a Slice meter?
                if meters[meterId]!.source == Meter.MeterSource.slice.rawValue {
                    
                    // YES, get the Slice
                    if let slice = slices[meters[meterId]!.number] {
                        
                        // add the Meter to the Slice
                        slice.addMeter(meters[meterId]!)
                    }
                }
            }
            // pass the key values to the Meter for parsing
            meters[meterId]!.parseKeyValues( keyValues )
        }
    }
    /// Prepare to parse a MicAudioStream status message
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///   - notInUse:       true = "in_use=0", otherwise false
    ///
    private func parseMicAudioStream(_ keyValues: KeyValuesArray, notInUse: Bool) {
        // Format:  <streamId, > <"in_use", 1|0> <"ip", ip> <"port", port>
        
        //get the MicAudioStreamId (remove the "0x" prefix)
        let streamId = String(keyValues[0].key.characters.dropFirst(2))
        
        // is it marked for removal?
        if notInUse {
            
            // YES, notify all observers
            NC.post(.micAudioStreamWillBeRemoved, object: micAudioStreams[streamId] as Any?)
            
            // remove it from the its collection
            removeObject(micAudioStreams[streamId])
            
        } else {
            
            // NO, does the MicAudioStream exist?
            if micAudioStreams[streamId] == nil {
                
                // NO, create a new MicAudioStream & add it to the MicAudioStreams collection
                micAudioStreams[streamId] = MicAudioStream(radio: self, id: streamId, queue: _micAudioStreamQ)
            }
            // pass the remaining key values to the MicAudioStream for parsing
            micAudioStreams[streamId]!.parseKeyValues( Array(keyValues.dropFirst(1)) )
        }
    }
    /// Prepare to parse an Opus status message
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///
    private func parseOpus(_ keyValues: KeyValuesArray) {
        // Format:  <streamId, > <"ip", ip> <"port", port> <"opus_rx_stream_stopped", 1|0>  <"rx_on", 1|0> <"tx_on", 1|0>
        
        // get the Opus Id (without the "0x" prefix)
        let opusId = String(keyValues[0].key.characters.dropFirst(2))
        
        // does the Opus exist?
        if  opusStreams[opusId] == nil {
            
            // NO, create a new Opus & add it to the OpusStreams collection
            opusStreams[opusId] = Opus(radio: self, id: opusId, queue: _opusQ)
        }
        // pass the key values to Opus for parsing
        opusStreams[opusId]!.parseKeyValues( Array(keyValues.dropFirst(1)) )
    }
    /// Parse a Profile status message
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///
    fileprivate func parseProfile(_ keyValues: KeyValuesArray) {
        // Format:  <profileType, > <"list",value^value...^value>
        //      OR
        // Format:  <profileType, > <"current", value>
        
        let values = valuesArray(keyValues[1].value, delimiter: "^")
        
        // determine the type of Profile & save it
        if let profileType = ProfileToken(rawValue: keyValues[0].key.lowercased()), let subType = ProfileSubType(rawValue: keyValues[1].key.lowercased()) {
            
            switch profileType {
                
            case .global:
                switch subType {
                case .list:
                    // Global List
                    willChangeValue(forKey: "profiles")
                    _profiles[.global] = values
                    didChangeValue(forKey: "profiles")
                case .current:
                    // Global Current
                    willChangeValue(forKey: "currentGlobalProfile")
                    _currentGlobalProfile = values[0]
                    didChangeValue(forKey: "currentGlobalProfile")
                }
                
            case .mic:
                switch subType {
                case .list:
                    // Mic List
                    willChangeValue(forKey: "profiles")
                    _profiles[.mic] = values
                    didChangeValue(forKey: "profiles")
                case .current:
                    // Mic Current
                    willChangeValue(forKey: "currentMicProfile")
                    _currentMicProfile = values[0]
                    didChangeValue(forKey: "currentMicProfile")
                }
                
            case .tx:
                switch subType {
                case .list:
                    // Tx List
                    willChangeValue(forKey: "profiles")
                    _profiles[.tx] = values
                    didChangeValue(forKey: "profiles")
                case .current:
                    // Tx Current
                    willChangeValue(forKey: "currentTxProfile")
                    _currentTxProfile = values[0]
                    didChangeValue(forKey: "currentTxProfile")
                }
            }
        } else {
            // unknown type
            _log.msg("Unknown profile - \(keyValues[0].key.lowercased()), \(keyValues[1].key.lowercased())", level: .debug, function: #function, file: #file, line: #line)
        }
    }
    /// Parse a Radio status message
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///
    private func parseRadio(_ keyValues: KeyValuesArray) {
        var filterSharpness = false
        var cw = false
        var digital = false
        var voice = false
        var staticNetParams = false
        
        // FIXME: What about a 6700 with two scu's?
        
        // process each key/value pair, <key=value>
        for kv in keyValues {
            
            // Check for Unknown token
            guard let token = RadioToken(rawValue: kv.key.lowercased())  else {
                
                // unknown Display Type, log it and ignore this token
                _log.msg("Unknown token - \(kv.key)", level: .debug, function: #function, file: #file, line: #line)
                continue
            }
            
            // get the Integer and Bool versions of the value
            let iValue = (kv.value).iValue()
            let bValue = (kv.value).bValue()
            
            // Known tokens, in alphabetical order
            switch token {
                
            case .autoLevel:
                if filterSharpness && cw {
                    willChangeValue(forKey: "filterCwAutoLevel")
                    _filterCwAutoLevel = iValue ; cw = false
                    didChangeValue(forKey: "filterCwAutoLevel")
                }
                if filterSharpness && digital {
                    willChangeValue(forKey: "filterDigitalAutoLevel")
                    _filterDigitalAutoLevel = iValue ; digital = false
                    didChangeValue(forKey: "filterDigitalAutoLevel")
                }
                if filterSharpness && voice {
                    willChangeValue(forKey: "filterVoiceAutoLevel")
                    _filterVoiceAutoLevel = iValue ; voice = false
                    didChangeValue(forKey: "filterVoiceAutoLevel")
                }
                filterSharpness = false
                
            case .binauralRxEnabled:
                willChangeValue(forKey: "binauralRxEnabled")
                _binauralRxEnabled = bValue
                didChangeValue(forKey: "binauralRxEnabled")
                
            case .calFreq:
                willChangeValue(forKey: "calFreq")
                _calFreq = iValue
                didChangeValue(forKey: "calFreq")
                
            case .callsign:
                willChangeValue(forKey: "callsign")
                _callsign = kv.value
                didChangeValue(forKey: "callsign")
                
            case .cw:
                cw = true
                
            case .enforcePrivateIpEnabled:
                willChangeValue(forKey: "enforcePrivateIpEnabled")
                _enforcePrivateIpEnabled = bValue
                didChangeValue(forKey: "enforcePrivateIpEnabled")
                
            case .filterSharpness:
                filterSharpness = true
                
            case .digital:
                digital = true
                
            case .freqErrorPpb:
                willChangeValue(forKey: "freqErrorPpb")
                _freqErrorPpb = iValue
                didChangeValue(forKey: "freqErrorPpb")
                
            case .fullDuplexEnabled:
                willChangeValue(forKey: "fullDuplexEnabled")
                _fullDuplexEnabled = bValue
                didChangeValue(forKey: "fullDuplexEnabled")
                
            case .gateway:
                if staticNetParams {
                    willChangeValue(forKey: "staticGateway")
                    _staticGateway = kv.value
                    didChangeValue(forKey: "staticGateway")
                }
                
            case .headphoneGain:
                willChangeValue(forKey: "headphoneGain")
                _headphoneGain = iValue
                didChangeValue(forKey: "headphoneGain")
                
            case .headphoneMute:
                willChangeValue(forKey: "headphoneMute")
                _headphoneMute = bValue
                didChangeValue(forKey: "headphoneMute")
                
            case .ip:
                if staticNetParams {
                    willChangeValue(forKey: "staticIp")
                    _staticIp = kv.value
                    didChangeValue(forKey: "staticIp")
                }
                
            case .level:
                if filterSharpness && cw {
                    willChangeValue(forKey: "filterCwLevel")
                    _filterCwLevel = iValue ; cw = false
                    didChangeValue(forKey: "filterCwLevel")
                }
                if filterSharpness && digital {
                    willChangeValue(forKey: "filterDigitalLevel")
                    _filterDigitalLevel = iValue ; digital = false
                    didChangeValue(forKey: "filterDigitalLevel")
                }
                if filterSharpness && voice {
                    willChangeValue(forKey: "filterVoiceLevel")
                    _filterVoiceLevel = iValue ; voice = false
                    didChangeValue(forKey: "filterVoiceLevel")
                }
                filterSharpness = false
                
            case .lineoutGain:
                willChangeValue(forKey: "lineoutGain")
                _lineoutGain = iValue
                didChangeValue(forKey: "lineoutGain")
                
            case .lineoutMute:
                willChangeValue(forKey: "lineoutMute")
                _lineoutMute = bValue
                didChangeValue(forKey: "lineoutMute")
                
            case .netmask:
                if staticNetParams {
                    willChangeValue(forKey: "staticNetmask")
                    _staticNetmask = kv.value ; staticNetParams = false
                    didChangeValue(forKey: "staticNetmask")
                }
                
            case .nickname:
                willChangeValue(forKey: "nickname")
                _nickname = kv.value
                didChangeValue(forKey: "nickname")
                
            case .panadapters:
                willChangeValue(forKey: "availablePanadapters")
                _availablePanadapters = iValue
                didChangeValue(forKey: "availablePanadapters")
                
            case .pllDone:
                willChangeValue(forKey: "startOffset")
                _startOffset = bValue
                didChangeValue(forKey: "startOffset")
                
            case .remoteOnEnabled:
                willChangeValue(forKey: "remoteOnEnabled")
                _remoteOnEnabled = bValue
                didChangeValue(forKey: "remoteOnEnabled")
                
            case .rttyMark:
                willChangeValue(forKey: "rttyMark")
                _rttyMark = iValue
                didChangeValue(forKey: "rttyMark")
                
            case .slices:
                willChangeValue(forKey: "availableSlices")
                _availableSlices = iValue
                didChangeValue(forKey: "availableSlices")
                
            case .snapTuneEnabled:
                willChangeValue(forKey: "snapTuneEnabled")
                _snapTuneEnabled = bValue
                didChangeValue(forKey: "snapTuneEnabled")
                
            case .staticNetParams:
                staticNetParams = true
                
            case .tnfEnabled:
                willChangeValue(forKey: "tnfEnabled")
                _tnfEnabled = bValue
                didChangeValue(forKey: "tnfEnabled")
                
            case .txInWaterfallEnabled:
                willChangeValue(forKey: "txInWaterfallEnabled")
                _txInWaterfallEnabled = bValue
                didChangeValue(forKey: "txInWaterfallEnabled")
                
            case .voice:
                voice = true
                
            }
        }
        // is the Panadapter initialized?
        if !_radioInitialized {
            
            // YES, the Radio (hardware) has acknowledged this Panadapter
            _radioInitialized = true
            
            // notify all observers
            NC.post(.radioInitialized, object: self as Any?)
        }
    }
    /// Prepare to parse a Slice status message
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///   - notInUse:       true = "in_use=0", otherwise false
    ///
    private func parseSlice(_ keyValues: KeyValuesArray, notInUse: Bool) {
        
        // get the Slice Id
        let sliceId = keyValues[0].key
        
        // should the Slice be removed?
        if notInUse {
            
            // YES, notify all observers
            NC.post(.sliceWillBeRemoved, object: slices[sliceId] as Any?)
            
            // remove it from the its collection
            removeObject(slices[sliceId])
            
        } else {
            // does the Slice exist?
            if slices[sliceId] == nil {
                
                // NO, create a new Slice & add it to the Slices collection
                slices[sliceId] = xFlexAPI.Slice(radio: self, sliceId: sliceId, queue: _sliceQ)
                
                // scan the meters
                for (_, meter) in meters {
                    
                    // is this meter associated with this slice?
                    if meter.source.lowercased() == Meter.MeterSource.slice.rawValue && meter.number == sliceId {
                        
                        // YES, add it to this Slice's Meters collection
                        slices[sliceId]!.addMeter(meter)
                    }
                }
            }
            // pass the remaining key values to the Slice for parsing
            slices[sliceId]!.parseKeyValues( Array(keyValues.dropFirst(1)) )
        }
    }
    /// Parse a Stream status message
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///
    private func parseStream(_ keyValues: KeyValuesArray) {
        // Format: <streamId, > <"daxiq", value> <"pan", panStreamId> <"rate", value> <"ip", ip> <"port", port> <"streaming", 1|0> ,"capacity", value> <"available", value>
        
        //get the StreamId (remove the "0x" prefix)
        let streamId = String(keyValues[0].key.characters.dropFirst(2))
        
        // does the Stream exist?
        if iqStreams[streamId] == nil {
            
            // NO, create a new Stream & add it to the Streams collection
            iqStreams[streamId] = IqStream(radio: self, id: streamId, queue: _iqStreamQ)
        }
        // pass the remaining key values to the IqStream for parsing
        iqStreams[streamId]!.parseKeyValues( Array(keyValues.dropFirst(1)) )
    }
    /// Prepare to parse a Tnf status message
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///
    private func parseTnf(_ keyValues: KeyValuesArray) {
        
        // get the Tnf Id
        let tnfId = keyValues[0].key
        
        // does the TNF  exist?
        if tnfs[tnfId] == nil {
            
            // NO, create a new Tnf & add it to the Tnfs collection
            tnfs[tnfId] = Tnf(id: tnfId, radio: self, queue: _tnfQ)
        }
        // pass the remaining key values to the Tnf for parsing
        tnfs[tnfId]!.parseKeyValues( Array(keyValues.dropFirst(1)) )
    }
    
    /// Parse a Transmit status message
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///
    private func parseTransmit(_ keyValues: KeyValuesArray) {
        
        // process each key/value pair, <key=value>
        for kv in keyValues {
            
            // Check for Unknown token
            guard let token = TransmitToken(rawValue: kv.key.lowercased())  else {
                
                // unknown Token, log it and ignore this token
                _log.msg("Unknown token - \(kv.key)", level: .debug, function: #function, file: #file, line: #line)
                continue
            }
            
            // get the Integer and Bool versions of the value
            let iValue = (kv.value).iValue()
            let bValue = (kv.value).bValue()
            
            // Known tokens, in alphabetical order
            switch token {
                
            case .amCarrierLevel:
                willChangeValue(forKey: "carrierLevel")
                _carrierLevel = iValue
                didChangeValue(forKey: "carrierLevel")
                
            case .companderEnabled:
                willChangeValue(forKey: "companderEnabled")
                _companderEnabled = bValue
                didChangeValue(forKey: "companderEnabled")
                
            case .companderLevel:
                willChangeValue(forKey: "companderLevel")
                _companderLevel = iValue
                didChangeValue(forKey: "companderLevel")
                
            case .cwBreakInEnabled:
                willChangeValue(forKey: "cwBreakInEnabled")
                _cwBreakInEnabled = bValue
                didChangeValue(forKey: "cwBreakInEnabled")
                
            case .cwBreakInDelay:
                willChangeValue(forKey: "cwBreakInDelay")
                _cwBreakInDelay = iValue
                didChangeValue(forKey: "cwBreakInDelay")
                
            case .cwIambicEnabled:
                willChangeValue(forKey: "cwIambicEnabled")
                _cwIambicEnabled = bValue
                didChangeValue(forKey: "cwIambicEnabled")
                
            case .cwIambicMode:
                willChangeValue(forKey: "cwIambicMode")
                _cwIambicMode = iValue
                didChangeValue(forKey: "cwIambicMode")
                
            case .cwlEnabled:
                willChangeValue(forKey: "cwlEnabled")
                _cwlEnabled = bValue
                didChangeValue(forKey: "cwlEnabled")
                
            case .cwPitch:
                willChangeValue(forKey: "cwPtch")
                _cwPitch = iValue
                didChangeValue(forKey: "cwPtch")
                
            case .cwSidetoneEnabled:
                willChangeValue(forKey: "cwSidetoneEnabled")
                _cwSidetoneEnabled = bValue
                didChangeValue(forKey: "cwSidetoneEnabled")
                
            case .cwSpeed:
                willChangeValue(forKey: "cwSpeed")
                _cwSpeed = iValue
                didChangeValue(forKey: "cwSpeed")
                
            case .cwSwapPaddles:
                willChangeValue(forKey: "cwSwapPaddles")
                _cwSwapPaddles = bValue
                didChangeValue(forKey: "cwSwapPaddles")
                
            case .cwSyncCwxEnabled:
                willChangeValue(forKey: "cwSyncCwxEnabled")
                _cwSyncCwxEnabled = bValue
                didChangeValue(forKey: "cwSyncCwxEnabled")
                
            case .daxEnabled:
                willChangeValue(forKey: "daxEnabled")
                _daxEnabled = bValue
                didChangeValue(forKey: "daxEnabled")
                
            case .frequency:
                willChangeValue(forKey: "frequency")
                _frequency = kv.value.mhzToHz()
                didChangeValue(forKey: "frequency")
                
            case .hwAlcEnabled:
                willChangeValue(forKey: "hwAlcEnabled")
                _hwAlcEnabled = bValue
                didChangeValue(forKey: "hwAlcEnabled")
                
            case .inhibit:
                willChangeValue(forKey: "inhibit")
                _inhibit = bValue
                didChangeValue(forKey: "inhibit")
                
            case .maxPowerLevel:
                willChangeValue(forKey: "maxPowerLevel")
                _maxPowerLevel = iValue
                didChangeValue(forKey: "maxPowerLevel")
                
            case .metInRxEnabled:
                willChangeValue(forKey: "metInRxEnabled")
                _metInRxEnabled = bValue
                didChangeValue(forKey: "metInRxEnabled")
                
            case .micAccEnabled:
                willChangeValue(forKey: "micAccEnabled")
                _micAccEnabled = bValue
                didChangeValue(forKey: "micAccEnabled")
                
            case .micBoostEnabled:
                willChangeValue(forKey: "micBoostEnabled")
                _micBoostEnabled = bValue
                didChangeValue(forKey: "micBoostEnabled")
                
            case .micBiasEnabled:
                willChangeValue(forKey: "micBiasEnabled")
                _micBiasEnabled = bValue
                didChangeValue(forKey: "micBiasEnabled")
                
            case .micLevel:
                willChangeValue(forKey: "micLevel")
                _micLevel = iValue
                didChangeValue(forKey: "micLevel")
                
            case .micSelection:
                willChangeValue(forKey: "micSelection")
                _micSelection = kv.value
                didChangeValue(forKey: "micSelection")
                
            case .rawIqEnabled:
                willChangeValue(forKey: "rawIqEnabled")
                _rawIqEnabled = bValue
                didChangeValue(forKey: "rawIqEnabled")
                
            case .rfPower:
                willChangeValue(forKey: "rfPower")
                _rfPower = iValue
                didChangeValue(forKey: "rfPower")
                
            case .speechProcessorEnabled:
                willChangeValue(forKey: "speechProcessorEnabled")
                _speechProcessorEnabled = bValue
                didChangeValue(forKey: "speechProcessorEnabled")
                
            case .speechProcessorLevel:
                willChangeValue(forKey: "speechProcessorLevel")
                _speechProcessorLevel = iValue
                didChangeValue(forKey: "speechProcessorLevel")
                
            case .txFilterChanges:
                willChangeValue(forKey: "txFilterChanges")
                _txFilterChanges = bValue
                didChangeValue(forKey: "txFilterChanges")
                
            case .txFilterHigh:
                willChangeValue(forKey: "txFilterHigh")
                _txFilterHigh = iValue
                didChangeValue(forKey: "txFilterHigh")
                
            case .txFilterLow:
                willChangeValue(forKey: "txFilterLow")
                _txFilterLow = iValue
                didChangeValue(forKey: "txFilterLow")
                
            case .txInWaterfallEnabled:
                willChangeValue(forKey: "txInWaterfallEnabled")
                _txInWaterfallEnabled = bValue
                didChangeValue(forKey: "txInWaterfallEnabled")
                
            case .txMonitorAvailable:
                willChangeValue(forKey: "txMonitorAvailable")
                _txMonitorAvailable = bValue
                didChangeValue(forKey: "txMonitorAvailable")
                
            case .txMonitorEnabled:
                willChangeValue(forKey: "txMonitorEnabled")
                _txMonitorEnabled = bValue
                didChangeValue(forKey: "txMonitorEnabled")
                
            case .txMonitorGainCw:
                willChangeValue(forKey: "txMonitorGainCw")
                _txMonitorGainCw = iValue
                didChangeValue(forKey: "txMonitorGainCw")
                
            case .txMonitorGainSb:
                willChangeValue(forKey: "txMonitorGainSb")
                _txMonitorGainSb = iValue
                didChangeValue(forKey: "txMonitorGainSb")
                
            case .txMonitorPanCw:
                willChangeValue(forKey: "txMonitorPanCw")
                _txMonitorPanCw = iValue
                didChangeValue(forKey: "txMonitorPanCw")
                
            case .txMonitorPanSb:
                willChangeValue(forKey: "txMonitorPanSb")
                _txMonitorPanSb = iValue
                didChangeValue(forKey: "txMonitorPanSb")
                
            case .txRfPowerChanges:
                willChangeValue(forKey: "txRfPowerChanges")
                _txRfPowerChanges = bValue
                didChangeValue(forKey: "txRfPowerChanges")
                
            case .tune:
                willChangeValue(forKey: "tune")
                _tune = bValue
                didChangeValue(forKey: "tune")
                
            case .tunePower:
                willChangeValue(forKey: "tunePower")
                _tunePower = iValue
                didChangeValue(forKey: "tunePower")
                
            case .voxEnabled:
                willChangeValue(forKey: "voxEnabled")
                _voxEnabled = bValue
                didChangeValue(forKey: "voxEnabled")
                
            case .voxDelay:
                willChangeValue(forKey: "voxDelay")
                _voxDelay = iValue
                didChangeValue(forKey: "voxDelay")
                
            case .voxLevel:
                willChangeValue(forKey: "voxLevel")
                _voxLevel = iValue
                didChangeValue(forKey: "voxLevel")
            }
        }
    }
    /// Prepare to parse a TxAudioStream status message
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///   - notInUse:       true = "in_use=0", otherwise false
    ///
    private func parseTxAudioStream(_ keyValues: KeyValuesArray, notInUse: Bool) {
        // Format:  <streamId, > <"dax_tx", channel> <"in_use", 1|0> <"ip", ip> <"port", port>
        
        //get the AudioStreamId (remove the "0x" prefix)
        let streamId = String(keyValues[0].key.characters.dropFirst(2))
        
        // should the TX Audio Stream be removed?
        if notInUse {
            
            // YES, notify all observers
            NC.post(.txAudioStreamWillBeRemoved, object: txAudioStreams[streamId] as Any?)
            
            // remove it from the its collection
            removeObject(txAudioStreams[streamId])
            
        } else {
            
            // does the AudioStream exist?
            if txAudioStreams[streamId] == nil {
                
                // NO, create a new AudioStream & add it to the AudioStreams collection
                txAudioStreams[streamId] = TxAudioStream(radio: self, id: streamId, queue: _txAudioStreamQ)
            }
            // pass the remaining key values to the AudioStream for parsing
            txAudioStreams[streamId]!.parseKeyValues( Array(keyValues.dropFirst(1)) )
        }
    }
    /// Parse a USB Cable status message
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///
    private func parseUsbCable(_ keyValues: KeyValuesArray) {
        
        // TODO: add code
        
    }
    /// Parse a Waveform status message
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///
    private func parseWaveform(_ keyValues: KeyValuesArray) {
        
        // process each key/value pair, <key=value>
        for kv in keyValues {
            
            // Check for Unknown token
            guard let token = WaveformToken(rawValue: kv.key.lowercased())  else {
                
                // unknown Token, log it and ignore this token
                _log.msg("Unknown token - \(kv.key)", level: .debug, function: #function, file: #file, line: #line)
                continue
            }
            
            // Known tokens, in alphabetical order
            switch token {
                
            case .waveformList:
                _waveformList = kv.value
                
            }
        }
    }
    /// Parse an Xvtr status message
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///
    private func parseXvtr(_ keyValues: KeyValuesArray, notInUse: Bool) {
        // Format:  <name, > <"rf_freq", value> <"if_freq", value> <"lo_error", value> <"max_power", value>
        //              <"rx_gain",value> <"order", value> <"rx_only", 1|0> <"is_valid", 1|0> <"preferred", 1|0>
        //              <"two_meter_int", value>
        //      OR
        // Format: <index, > <"in_use", 0>
        
        //        // get the Name
        //        let name = String(keyValues[0].key)
        //
        //        // should the Xvtr be removed?
        //        if notInUse {
        //
        //            // YES, notify all observers
        //            NC.post(.xvtrWillBeRemoved, object: xvtrs[name] as Any?)
        //
        //            // remove it from the its collection
        //            removeObject(xvtrs[name])
        //
        //        } else {
        //
        //            // does the Xvtr exist?
        //            if xvtrs[name] == nil {
        //
        //                // NO, create a new Xvtr & add it to the Xvtrs collection
        //                xvtrs[name] = Xvtr(radio: self, name: name, queue: _xvtrQ)
        //            }
        //            // pass the remaining key values to the Xvtr for parsing
        //            xvtrs[name]!.parseKeyValues( Array(keyValues.dropFirst(1)) )
        //        }
        
    }
    
    // --------------------------------------------------------------------------------
    // MARK: - Internal Supporting methods
    // --------------------------------------------------------------------------------
    
    // MARK: ----- Panadapter -----
    
    /// Find the active Panadapter
    ///
    /// - Returns:      a reference to a Panadapter (or nil)
    ///
    public func findActivePanadapter() -> Panadapter? {
        var panadapter: Panadapter?
        
        // find the active Panadapter (if any)
        for (_, pan) in panadapters where findActiveSliceOn(pan.id) != nil {
            
            // return it
            panadapter = pan
        }
        
        return panadapter
    }
    /// Find the Panadapter for a DaxIqChannel
    ///
    /// - Parameters:
    ///   - daxIqChannel:   a Dax channel number
    /// - Returns:          a Panadapter reference (or nil)
    ///
    public func findPanadapterBy(daxIqChannel: DaxIqChannel) -> Panadapter? {
        var panadapter: Panadapter?
        
        // find the matching Panadapter (if any)
        for (_, pan) in panadapters where pan.daxIqChannel == daxIqChannel {
            
            // return it
            panadapter = pan
        }
        
        return panadapter
    }
    
    // MARK: ----- IqStream -----
    
    /// Find the IQ Stream for a DaxIqChannel
    ///
    /// - Parameters:
    ///   - daxIqChannel:   a Dax IQ channel number
    /// - Returns:          an IQ Stream reference (or nil)
    ///
    public func findIqStreamBy(daxIqChannel: DaxIqChannel) -> IqStream? {
        var iqStream: IqStream?
        
        // find the matching IqStream (if any)
        for (_, stream) in iqStreams where stream.daxIqChannel == daxIqChannel {
            iqStream = stream
        }
        return iqStream
    }
    
    // MARK: ----- Slice -----
    
    /// Disable all TxEnabled
    ///
    public func disableTx() {
        
        // for all Slices, turn off txEnabled
        for (_, slice) in slices {
            
            slice.txEnabled = false
        }
    }
    
    /// Return references to all Slices on the specified Panadapter
    ///
    /// - Parameters:
    ///   - pan:        a Panadapter Id
    /// - Returns:      an array of Slices (may be empty)
    ///
    public func findSlicesOn(_ id: PanadapterId) -> [Slice] {
        var sliceValues = [Slice]()
        
        // for all Slices on the specified Panadapter
        for (_, slice) in slices where slice.panadapterId == id {
            
            // append to the result
            sliceValues.append(slice)
        }
        return sliceValues
    }
    /// Given a Frequency, return the Slice on the specified Panadapter containing it (if any)
    ///
    /// - Parameters:
    ///   - pan:        a reference to A Panadapter
    ///   - freq:       a Frequency (in hz)
    /// - Returns:      a reference to a Slice (or nil)
    ///
    public func findSliceOn(_ id: PanadapterId, byFrequency freq: Int, panafallBandwidth: Int) -> Slice? {
        var slice: Slice?
        
        let minWidth = Int( CGFloat(panafallBandwidth) * kSliceClickBandwidth )
        
        // find the Panadapter containing the Slice (if any)
        for (_, s) in slices where s.panadapterId == id {
            
            //            let width = CGFloat(s.filterHigh) - CGFloat(s.filterLow)
            
            let widthDown = min(-minWidth/2, s.filterLow)
            let widthUp = max(minWidth/2, s.filterHigh)
            
            if freq >= s.frequency + widthDown && freq <= s.frequency + widthUp {
                
                // YES, return the Slice
                slice = s
                break
            }
        }
        return slice
    }
    /// Return the Active Slice on the specified Panadapter (if any)
    ///
    /// - Parameters:
    ///   - pan:        a Panadapter reference
    /// - Returns:      a Slice reference (or nil)
    ///
    public func findActiveSliceOn(_ id: PanadapterId) -> Slice? {
        var slice: Slice?
        
        // is the Slice on the Panadapter and Active?
        for (_, s) in self.slices where s.panadapterId == id && s.active {
            
            // YES, return the Slice
            slice = s
        }
        return slice
    }
    
    public func findSliceBy(daxChannel channel: DaxChannel) -> Slice? {
        var slice: Slice?
        
        // find the Slice for the Dax Channel (if any)
        for (_, s) in self.slices where s.daxChannel == channel {
            
            // YES, return the Slice
            slice = s
        }
        return slice
        
    }
    
    // MARK: ----- Tnf -----
    
    /// Given a Frequency, return a reference to the Tnf containing it (if any)
    ///
    /// - Parameters:
    ///   - freq:       a Frequency (in hz)
    /// - Returns:      a Tnf reference (or nil)
    ///
    public func findTnfBy(frequency freq: Int, panafallBandwidth: Int) -> Tnf? {
        var tnf: Tnf?
        
        let minWidth = Int( CGFloat(panafallBandwidth) * kTnfClickBandwidth )
        
        for (_, t) in tnfs {
            
            let halfwidth = max(minWidth, t.width/2)
            if freq >= (t.frequency - halfwidth) && freq <= (t.frequency + halfwidth) {
                tnf = t
                break
            }
        }
        return tnf
    }
    
    
    // MARK: ----- Meter -----
    
    /// Synchronously find a Meter by its ShortName
    ///
    /// - Parameters:
    ///   - name:       Short Name of a Meter
    /// - Returns:      a Meter reference
    ///
    public func findMeteryBy(shortName name: MeterName) -> Meter? {
        var meter: Meter?
        
        for (_, aMeter) in meters where aMeter.name == name {
            
            // get a reference to the Meter
            meter = aMeter
        }
        return meter
    }
    
    // --------------------------------------------------------------------------------
    // MARK: - Radio Reply Handler
    
    /// Process the Reply to a command, reply format: <value>,<value>,...<value>
    ///
    /// - Parameters:
    ///   - command:        the original command
    ///   - seqNum:         the Sequence Number of the original command
    ///   - responseValue:  the response value
    ///   - reply:          the reply
    ///
    public func replyHandler(_ command: String, seqNum: String, responseValue: String, reply: String) {
        
        guard responseValue == kNoError else {
            // ignore non-zero reply from "client program" command
            if !command.hasPrefix(kClientCmd) {
                // Anything other than 0 is an error, log it and ignore the Reply
                _log.msg(command + ", non-zero reply - \(reply)", level: .error, function: #function, file: #file, line: #line)
            }
            return
        }
        // which command?
        switch command {
            
        case kInfoCmd:
            // process the reply
            parseInfoReply(keyValuesArray(reply))
            
        case kAntListCmd:
            // save the list
            antennaList = valuesArray(reply, delimiter: ",")
            
        case kMeterListCmd:
            // process the reply
            parseMeterListReply(reply)
            
        case kMicListCmd:
            // save the list
            micList = valuesArray(reply, delimiter: ",")
            
        case kSliceListCmd:
            // save the list
            sliceList = valuesArray(reply)
            
        case kRadioUptimeCmd:
            // save the returned Uptime (seconds)
            uptime = Int(reply) ?? 0
            
        case kVersionCmd:
            // process the reply
            parseVersionReply(keyValuesArray(reply, delimiter: "#"))
            
        default:
            
            if command.hasPrefix(kDisplayPanCmd + "create") {
                
                // separate the Stream Ids
                let components = reply.components(separatedBy: ",")
                
                // create the new Panadapter & add it to the collection
                let panadapterId = String( components[0].characters.dropFirst(2) )
                panadapters[panadapterId] = Panadapter(radio: self, id: panadapterId, queue: _panadapterQ)
                
                // create the new Waterfall & add it to the collection
                let waterfallId = String( components[1].characters.dropFirst(2) )
                waterfalls[waterfallId] = Waterfall(streamId: waterfallId, radio: self, queue: _waterfallQ)
                
            } else if command.hasPrefix(kStreamCreateCmd + "dax=") {
                
                // FIXME: add code
                break
                
            } else if command.hasPrefix(kStreamCreateCmd + "daxmic") {
                
                // FIXME: add code
                break
                
            } else if command.hasPrefix(kStreamCreateCmd + "daxtx") {
                
                // FIXME: add code
                break
                
            } else if command.hasPrefix(kStreamCreateCmd + "daxiq") {
                
                // FIXME: add code
                break
                
            } else if command.hasPrefix(kSliceCmd + "get_error"){
                
                // save the errors, format: <rx_error_value>,<tx_error_value>
                sliceErrors = valuesArray(reply, delimiter: ",")
                
            } else {
                _log.msg(command + ", unprocessed reply - \(reply)", level: .error, function: #function, file: #file, line: #line)
            }
        }
    }
    /// Parse the Reply to an Info command, reply format: <key=value> <key=value> ...<key=value>
    ///
    /// - Parameters:
    ///   - keyValues:          a KeyValuesArray
    ///
    private func parseInfoReply(_ keyValues: KeyValuesArray) {
        
        // process each key/value pair, <key=value>
        for kv in keyValues {
            
            // check for unknown Keys
            guard let token = InfoToken(rawValue: kv.key.lowercased()) else {
                // unknown Key, log it and ignore this Key
                _log.msg("Unknown token - \(kv.key)", level: .debug, function: #function, file: #file, line: #line)
                continue
            }
            
            // get the String, Integer and Bool versions of the value
            let sValue = kv.value.replacingOccurrences(of: "\"", with:"")
            let iValue = (kv.value).iValue()
            let bValue = (kv.value).bValue()
            
            // Known keys, in alphabetical order
            switch token {
                
            case .atuPresent:
                willChangeValue(forKey: "atuPresent")
                _atuPresent = bValue
                didChangeValue(forKey: "atuPresent")
                
            case .callsign:
                willChangeValue(forKey: "callsign")
                _callsign = sValue
                didChangeValue(forKey: "callsign")
                
            case .chassisSerial:
                willChangeValue(forKey: "chassisSerial")
                _chassisSerial = sValue
                didChangeValue(forKey: "chassisSerial")
                
            case .gateway:
                willChangeValue(forKey: "gateway")
                _gateway = sValue
                didChangeValue(forKey: "gateway")
                
            case .gps:
                willChangeValue(forKey: "gpsPresent")
                _gpsPresent = bValue
                didChangeValue(forKey: "gpsPresent")
                
            case .ipAddress:
                willChangeValue(forKey: "ipAddress")
                _ipAddress = sValue
                didChangeValue(forKey: "ipAddress")
                
            case .location:
                willChangeValue(forKey: "location")
                _location = sValue
                didChangeValue(forKey: "location")
                
            case .macAddress:
                willChangeValue(forKey: "macAddress")
                _macAddress = sValue
                didChangeValue(forKey: "macAddress")
                
            case .model:
                willChangeValue(forKey: "radioModel")
                _radioModel = sValue
                didChangeValue(forKey: "radioModel")
                
            case .netmask:
                willChangeValue(forKey: "netmask")
                _netmask = sValue
                didChangeValue(forKey: "netmask")
                
            case .name:
                willChangeValue(forKey: "nickname")
                _nickname = sValue
                didChangeValue(forKey: "nickname")
                
            case .numberOfScus:
                willChangeValue(forKey: "numberOfScus")
                _numberOfScus = iValue
                didChangeValue(forKey: "numberOfScus")
                
            case .numberOfSlices:
                willChangeValue(forKey: "numberOfSlices")
                _numberOfSlices = iValue
                didChangeValue(forKey: "numberOfSlices")
                
            case .numberOfTx:
                willChangeValue(forKey: "numberOfTx")
                _numberOfTx = iValue
                didChangeValue(forKey: "numberOfTx")
                
            case .options:
                willChangeValue(forKey: "radioOptions")
                _radioOptions = sValue
                didChangeValue(forKey: "radioOptions")
                
            case .region:
                willChangeValue(forKey: "region")
                _region = sValue
                didChangeValue(forKey: "region")
                
            case .screensaver:
                willChangeValue(forKey: "radioScreenSaver")
                _radioScreenSaver = sValue
                didChangeValue(forKey: "radioScreenSaver")
                
            case .softwareVersion:
                willChangeValue(forKey: "softwareVersion")
                _softwareVersion = sValue
                didChangeValue(forKey: "softwareVersion")
            }
        }
    }
    /// Parse the Reply to a Meter list command, reply format: <value>,<value>,...<value>
    ///
    /// - Parameters:
    ///   - reply:          the reply
    ///
    private func parseMeterListReply(_ reply: String) {
        
        // nested function to add & parse meters
        func addMeter(id: String, keyValues: KeyValuesArray) {
            
            // create a meter
            let meter = Meter(radio: self, id: id, queue: _meterQ)
            
            // add it to the collection
            self.meters[id] = meter
            
            // pass the key values to the Meter for parsing
            meter.parseKeyValues( keyValues )
        }
        
        // drop the "meter " string
        let meters = String(reply.characters.dropFirst(6))
        let keyValues = keyValuesArray(meters, delimiter: "#")
        
        var meterKeyValues = KeyValuesArray()
        
        // extract the first Meter Number
        var id = keyValues[0].key.components(separatedBy: ".")[0]
        
        // loop through the kv pairs separating them into individual meters
        for (i, kv) in keyValues.enumerated() {
            
            // is this the start of a different meter?
            if id != kv.key.components(separatedBy: ".")[0] {
                
                // YES, add the current meter
                addMeter(id: id, keyValues: meterKeyValues)
                
                // recycle the keyValues
                meterKeyValues.removeAll(keepingCapacity: true)
                
                // get the new meter id
                id = keyValues[i].key.components(separatedBy: ".")[0]
                
            }
            // add the current kv pair to the current set of meter kv pairs
            meterKeyValues.append(keyValues[i])
        }
        // add the final meter
        addMeter(id: id, keyValues: meterKeyValues)
    }
    /// Parse the Reply to a Version command, reply format: <key=value>#<key=value>#...<key=value>
    ///
    /// - Parameters:
    ///   - keyValues:          a KeyValuesArray
    ///
    private func parseVersionReply(_ keyValues: KeyValuesArray) {
        
        // process each key/value pair, <key=value>
        for kv in keyValues {
            
            // check for unknown Tokens
            guard let token = VersionToken(rawValue: kv.key.lowercased() ) else {
                // Unknown Token, log it and ignore this Token
                _log.msg("Unknown token - \(kv.key)", level: .debug, function: #function, file: #file, line: #line)
                continue
            }
            // Known tokens, in alphabetical order
            switch token {
                
            case .smartSdrMB:
                willChangeValue(forKey: "smartSdrMB")
                _smartSdrMB = kv.value
                didChangeValue(forKey: "smartSdrMB")
                
            case .psocMbTrx:
                willChangeValue(forKey: "psocMbtrxVersion")
                _psocMbtrxVersion = kv.value
                didChangeValue(forKey: "psocMbtrxVersion")
                
            case .psocMbPa100:
                willChangeValue(forKey: "psocMbPa100Version")
                _psocMbPa100Version = kv.value
                didChangeValue(forKey: "psocMbPa100Version")
                
            case .fpgaMb:
                willChangeValue(forKey: "fpgaMbVersion")
                _fpgaMbVersion = kv.value
                didChangeValue(forKey: "fpgaMbVersion")
            }
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    ///
    ///     Note: commands will be in default order if one of the .all... values is passed
    ///             otherwise commands will be in the order found in the incoming array
    ///
    /// Populate a Commands array
    ///
    /// - Parameters:
    ///   - commands:       an array of Commands
    /// - Returns:          an array of CommandTuple
    ///
    private func setupCommands(_ commands: [Command]) -> [(CommandTuple)] {
        var array = [(CommandTuple)]()
        
        // return immediately if none required
        if !commands.contains(.none) {
            
            // check for the "all..." cases
            var adjustedCommands = commands
            if commands.contains(.allPrimary) {                             // All Primary
                
                adjustedCommands = Command.allPrimaryCommands()
                
            } else if commands.contains(.allSecondary) {                    // All Secondary
                
                adjustedCommands = Command.allSecondaryCommands()
                
            } else if commands.contains(.allSubscription) {                 // All Subscription
                
                adjustedCommands = Command.allSubscriptionCommands()
            }
            
            // add all the specified commands
            for command in adjustedCommands {
                
                switch command {
                    
                case .clientProgram:
                    array.append( (command.rawValue + _clientName, false, replyHandler) )
                    
                case .meterList:
                    array.append( (command.rawValue, false, replyHandler) )
                    
                case .info:
                    array.append( (command.rawValue, false, replyHandler) )
                    
                case .version:
                    array.append( (command.rawValue, false, replyHandler) )
                    
                case .antList:
                    array.append( (command.rawValue, false, replyHandler) )
                    
                case .micList:
                    array.append( (command.rawValue, false, replyHandler) )
                    
                case .clientGui:
                    if _isGui { array.append( (command.rawValue, false, nil) ) }
                    
                    // FIXME:
                    
                    //                case .clientUdpPort:
                    //                    array.append( (command.rawValue + "\(_udp.port)", false, nil) )
                    
                case .none, .allPrimary, .allSecondary, .allSubscription:   // should never occur
                    break
                    
                default:
                    array.append( (command.rawValue, false, nil) )
                }
            }
        }
        return array
    }
    /// Send command sets to the Radio
    ///
    /// - Parameters:
    ///   - commands:       an array of CommandTuple
    ///
    private func sendCommands(_ commands: [CommandTuple]) {
        
        // send the commands to the Radio (hardware)
        for cmd in commands {
            
            let _ = _tcp.send(cmd.command, diagnostic: cmd.diagnostic, replyTo: cmd.replyHandler)
        }
    }
    /// return the folder for App specific files, create it if not found
    ///
    /// - Returns:      a Path to the folder
    ///
    private func appFolder() -> URL {
        
        // find the Spplication Support folder for this App
        let fileManager = FileManager()
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask ) as [URL]
        let appFolder = urls.first!.appendingPathComponent( Bundle.main.bundleIdentifier! )
        
        // does the folder exist?
        if !fileManager.fileExists( atPath: appFolder.path ) {
            
            // NO, create it
            do {
                try fileManager.createDirectory( at: appFolder, withIntermediateDirectories: false, attributes: nil)
            } catch let error as NSError {
                _log.msg("Error creating App Support folder: \(error.localizedDescription)", level: .error, function: #function, file: #file, line: #line)
            }
        }
        return appFolder
    }
    /// Determine if the Radio (hardware) Firmware version is compatable with the API version
    ///
    /// - Parameters:
    ///   - selectedRadio:      a RadioParameters struct
    ///
    private func checkFirmwareVersion(_ selectedRadio: RadioParameters) {
        
        // separate the parts of each version
        let xFlexVersionParts = kApiFirmwareSupport.components(separatedBy: ".")
        let radioVersionParts = selectedRadio.firmwareVersion!.components(separatedBy: ".")
        
        // compare the versions
        if xFlexVersionParts[0] != radioVersionParts[0] || xFlexVersionParts[1] != radioVersionParts[1] || xFlexVersionParts[2] != radioVersionParts[2] {
            _log.msg("Firmware update needed, Radio Version = \(selectedRadio.firmwareVersion!), xFlexAPI Firmware Support = \(kApiFirmwareSupport)", level: .warning, function: #function, file: #file, line: #line)
        }
    }
    /// Replace spaces and equal signs in a CWX Macro with alternate characters
    ///
    /// - Parameters:
    ///   - string:     a String to be processed
    /// - Returns:      the String after processing
    ///
    private func fixString(_ string: String) -> String {
        var newString: String = ""
        var quotes = false
        
        // We could have spaces inside quotes, so we have to convert them to something else for key/value parsing.
        // We could also have an equal sign '=' (for Prosign BT) inside the quotes, so we're converting to a '*' so that the split on "="
        // will still work.  This will prevent the character '*' from being stored in a macro.  Using the ascii byte for '=' will not work.
        for char in string.characters {
            if char == "\"" {
                quotes = !quotes
                
            } else if char == " " && quotes {
                newString += "\u{007F}"
                
            } else if char == "=" && quotes {
                newString += "*"
                
            } else {
                newString.append(char)
            }
        }
        return newString
    }
    /// Find and Load Filter Specs
    ///
    /// - Parameters:
    ///   - userFilePath:   path to the Filters plist
    /// - Returns:          an array of Filter Dictionaries
    ///
    private func loadFilters(filterPath userFilePath: String) -> [FilterMode:[FilterSpec]] {
        let theDict: [String:AnyObject]
        var filterDict = [FilterMode:[FilterSpec]]()
        
        // find a Filters.plist file
        let fileManager = FileManager.default
        if fileManager.fileExists( atPath: userFilePath ) {
            
            // user file exists
            theDict = NSDictionary( contentsOfFile: userFilePath)! as! [String:AnyObject]
            
        } else {
            
            // no User file exists, use the default file
            let defaultFilePath = Bundle(identifier:kBundleIdentifier)!.path(forResource: "Filters", ofType: "plist")
            theDict = NSDictionary( contentsOfFile: defaultFilePath! )! as! [String:AnyObject]
            
            // create a User version of the file
            (theDict as NSDictionary).write(toFile: userFilePath, atomically: true)
        }
        // convert the plist format into [FilterMode:[FilterSpec]] format
        for (mode, filters) in theDict {
            var filterSpecs = [FilterSpec]()
            
            // get all the filters for the current mode
            for filter in filters as! [NSDictionary] {
                
                // populate a FilterSpec struct
                let filterSpec = FilterSpec(filterHigh: filter["filterHigh"] as! Int,
                                            filterLow: filter["filterLow"] as! Int,
                                            label: filter["label"] as! String,
                                            mode: mode,
                                            txFilterHigh: filter["txFilterHigh"] as! Int,
                                            txFilterLow: filter["txFilterLow"] as! Int)
                
                // add it to the array of FilterSpec's
                filterSpecs.append(filterSpec)
            }
            // set the [FilterSpec] as the mode's value
            filterDict[mode] = filterSpecs
        }
        return filterDict
    }
    /// Parse a String of <key=value>'s separated by the given Delimiter
    ///
    /// - Parameters:
    ///   - keyValueString:     String containing the key value pairs & delimiters
    ///   - delimiter:          the delimiter between key values (defaults to space)
    /// - Returns:              a KeyValues array
    ///
    private func keyValuesArray(_ keyValueString: String?, delimiter: String = " ") -> KeyValuesArray {
        var kvArray = KeyValuesArray()
        
        // make sure the string isn't nil
        guard let keyValueString = keyValueString else { return kvArray }
        
        // split it into an array of <key=value> values
        let keyAndValues = keyValueString.components(separatedBy: delimiter)
        
        for index in 0..<keyAndValues.count {
            // separate each entry into a Key and a Value
            let kv = keyAndValues[index].components(separatedBy: "=")
            
            // when "delimiter" is last character there will be an empty entry, don't include it
            if kv[0] != "" {
                // if no "=", set value to empty String (helps with strings with a prefix to KeyValues)
                // make sure there are no whitespaces before or after the entries
                if kv.count == 1 { kvArray.append( (kv[0].trimmingCharacters(in: NSCharacterSet.whitespaces),"") ) }
                if kv.count == 2 { kvArray.append( (kv[0].trimmingCharacters(in: NSCharacterSet.whitespaces),kv[1].trimmingCharacters(in: NSCharacterSet.whitespaces)) ) }
            }
        }
        return kvArray
    }
    /// Parse a String of <value>'s separated by the given Delimiter
    ///
    /// - Parameters:
    ///   - valueString:    String containing the values & delimiters
    ///   - delimiter:      the delimiter between values (defaults to space)
    /// - Returns:          a values array
    ///
    func valuesArray(_ valuesString: String, delimiter: String = " ") -> ValuesArray {
        
        return valuesString.components(separatedBy: delimiter)
    }
    func txFilterHighLimits(_ low: Int, _ high: Int) -> Int {
        
        let newValue = ( high < low + 50 ? low + 50 : high )
        return newValue > 10_000 ? 10_000 : newValue
    }
    func txFilterLowLimits(_ low: Int, _ high: Int) -> Int {
        
        let newValue = ( low > high - 50 ? high - 50 : low )
        return newValue < 0 ? 0 : newValue
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Notification methods
    
    /// Add Notifications
    ///
    private func addNotifications() {
        
        // Pinging Started
        NC.makeObserver(self, with: #selector(tcpPingStarted(_:)), of: .tcpPingStarted, object: nil)
        
        // Ping Timeout
        NC.makeObserver(self, with: #selector(tcpPingTimeout(_:)), of: .tcpPingTimeout, object: nil)
    }
    /// Process .tcpPingStarted Notification
    ///
    /// - Parameters:
    ///   - note:       a Notification instance
    ///
    @objc private func tcpPingStarted(_ note: Notification) {
        
        _log.msg("Pinging started", level: .verbose, function: #function, file: #file, line: #line)
    }
    /// Process .tcpPingTimeout Notification
    ///
    /// - Parameters:
    ///   - note:       a Notification instance
    ///
    @objc private func tcpPingTimeout(_ note: Notification) {
        
        _log.msg("Ping timeout", level: .error, function: #function, file: #file, line: #line)
        
        // FIXME: Disconnect?
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - TcpManagerDelegate methods (on the tcpQ)
    
    /// Process a sent message
    ///
    /// - Parameters:
    ///   - text:       text of the message
    ///
    public func sentMessage(_ text: String) {
        
        //        _log.command(String(text.characters.dropLast()))
    }
    /// Process a received message
    ///
    /// - Parameters:
    ///   - text:       text of the message
    ///
    public func receivedMessage(_ text: String) {
        
        //        _log.command(String(text.characters.dropLast()))
        
        // pass it to the parser
        parse(String(text.characters.dropLast()))
    }
    /// Respond to a TCP Connection/Disconnection event
    ///
    /// - Parameters:
    ///   - connected:  state of connection
    ///   - host:       host address
    ///   - port:       port number
    ///   - error:      error message
    ///
    public func tcpState(connected: Bool, host: String, port: UInt16, error: String) {
        
        // connected?
        if connected {
            
            // YES, set state
            setConnectionState(.tcpConnected(host: host, port: port))
            
        } else {
            
            // NO, error?
            if error == "" {
                
                // NO, normal disconnect
                setConnectionState(.disconnected(reason: .closed))
                
            } else {
                
                // YES, disconnect with error
                setConnectionState(.disconnected(reason: .connectionFailed))
            }
        }
    }
    /// Receive an Error message from TCP Manager
    ///
    /// - Parameters:
    ///   - message:    the error message
    ///
    public func tcpError(_ message: String) {
        
        _log.msg("TCP error:  \(message)", level: .error, function: #function, file: #file, line: #line)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - UdpManager delegate methods (on the udpReceiveQ)
    
    /// Respond to a UDP Connection/Disconnection event
    ///
    /// - Parameters:
    ///   - bound:  state of binding
    ///   - port:   a port number
    ///   - error:  error message
    ///
    public func udpState(bound : Bool, port: UInt16, error: String) {
        
        // bound?
        if bound {
            
            // YES, set state
            setConnectionState(.udpBound(port: port))
            
        } else {
            
            // YES, disconnect with error
            setConnectionState(.disconnected(reason: .connectionFailed))
        }
    }
    /// Receive a State Change message from UDP Manager
    ///
    /// - Parameters:
    ///   - active:     the state
    ///
    public func udpStream(active: Bool) {
        
        // UDP port active / timed out
        _log.msg("UDP Stream \(active ? "active" : "time out")", level: .verbose, function: #function, file: #file, line: #line)
    }
    /// Receive an Error message from UDP Manager
    ///
    /// - Parameters:
    ///   - message:    error message
    ///
    public func udpError(_ message: String) {
        
        // UDP port encountered an error
        _log.msg("UDP error:  \(message)", level: .error, function: #function, file: #file, line: #line)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - UdpManager Stream Handler delegates
    
    /// Process the Meter stream, called on the udpReceiveQ thread
    ///
    /// - Parameters:
    ///   - vitaPacket:     a Vita packet containing Meter data
    ///
    func meterVitaHandler(_ vitaPacket: Vita) {
        
        // four bytes per Meter
        let numberOfMeters = Int(vitaPacket.payloadSize / 4)
        
        // pointer to the first Meter number / Meter value pair
        if let ptr16 = (vitaPacket.payload)?.bindMemory(to: UInt16.self, capacity: 2) {
            
            // for each meter in the Meters packet
            for i in 0..<numberOfMeters {
                
                // get the Meter number and the Meter value
                let meterNumber: UInt16 = CFSwapInt16BigToHost(ptr16.advanced(by: 2 * i).pointee)
                let meterValue: UInt16 = CFSwapInt16BigToHost(ptr16.advanced(by: (2 * i) + 1).pointee)
                
                // Find the meter (if present) & update it
                if let thisMeter = self.meters[String(format: "%i", meterNumber)] {
                    
                    // interpret it as a signed value
                    thisMeter.update( Int16(bitPattern:meterValue) )
                }
            }
        }
    }
    /// Process the Panadapter Vita packets
    ///
    /// - Parameters:
    ///   - vitaPacket:     a Vita packet containing Panadapter data
    ///
    func panadapterVitaHandler(_ vitaPacket: Vita) {
        
        // pass the stream to the appropriate Panadapter
        panadapters[vitaPacket.streamId]?.vitaHandler(vitaPacket)
    }
    /// Process the Waterfall Vita packets
    ///
    /// - Parameters:
    ///   - vitaPacket:     a Vita packet containing Waterfall data
    ///
    func waterfallVitaHandler(_ vitaPacket: Vita) {
        
        // pass the stream to the appropriate Waterfall
        waterfalls[vitaPacket.streamId]?.vitaHandler(vitaPacket)
    }
    /// Process the Opus Vita packets
    ///
    /// - Parameters:
    ///   - vitaPacket:     a Vita packet containing Opus data
    ///
    func opusVitaHandler(_ vitaPacket: Vita) {
        
        // Pass the data frame to the Opus delegate
        opusStreams[vitaPacket.streamId]?.vitaHandler( vitaPacket )
    }
    /// Process the Dax Vita packets
    ///
    /// - Parameters:
    ///   - vitaPacket:     a Vita packet containing Dax Audiodata
    ///
    func daxVitaHandler(_ vitaPacket: Vita) {
        
        // what type of Dax packet?
        if let audioStream = audioStreams[vitaPacket.streamId] {
            
            // Audio Stream
            audioStream.vitaHandler(vitaPacket)
            
        } else if let micStream = micAudioStreams[vitaPacket.streamId] {
            
            // Mic Audio Stream
            micStream.vitaHandler(vitaPacket)
            
        } else {
            
            // Unknown
            _log.msg("Received vita dax packet but no stream existing: \(vitaPacket.desc())", level: .error, function: #function, file: #file, line: #line)
        }
    }
    /// Process the Dax Iq Vita packets
    ///
    /// - Parameters:
    ///   - vitaPacket:     a Vita packet containing DaxIq data
    ///
    func daxIqVitaHandler(_ vitaPacket: Vita) {
        
        // TODO: Add code
    }
}


// --------------------------------------------------------------------------------
// MARK: - Radio Class extensions
//              - Synchronized internal properties
//              - Dynamic public properties
//              - Radio message enum
//              - Other Radio related enums
//              - Type aliases
// --------------------------------------------------------------------------------

extension Radio {
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties - with synchronization
    
    // listed in alphabetical order
    fileprivate var _accTxEnabled: Bool {
        get { return _radioQ.sync { __accTxEnabled } }
        set { _radioQ.sync(flags: .barrier) { __accTxEnabled = newValue } } }
    
    fileprivate var _accTxDelay: Int {
        get { return _radioQ.sync { __accTxDelay } }
        set { _radioQ.sync(flags: .barrier) { __accTxDelay = newValue } } }
    
    fileprivate var _accTxReqEnabled: Bool {
        get { return _radioQ.sync { __accTxReqEnabled } }
        set { _radioQ.sync(flags: .barrier) { __accTxReqEnabled = newValue } } }
    
    fileprivate var _accTxReqPolarity: Bool {
        get { return _radioQ.sync { __accTxReqPolarity } }
        set { _radioQ.sync(flags: .barrier) { __accTxReqPolarity = newValue } } }
    
    fileprivate var _apfEnabled: Bool {
        get { return _radioQ.sync { __apfEnabled } }
        set { _radioQ.sync(flags: .barrier) { __apfEnabled = newValue } } }
    
    fileprivate var _apfQFactor: Int {
        get { return _radioQ.sync { __apfQFactor } }
        set { _radioQ.sync(flags: .barrier) { __apfQFactor = newValue.bound(kMinApfQ, kMaxApfQ) } } }
    
    fileprivate var _apfGain: Int {
        get { return _radioQ.sync { __apfGain } }
        set { _radioQ.sync(flags: .barrier) { __apfGain = newValue.bound(kMinLevel, kMaxLevel) } } }
    
    fileprivate var _atuPresent: Bool {
        get { return _radioQ.sync { __atuPresent } }
        set { _radioQ.sync(flags: .barrier) { __atuPresent = newValue } } }
    
    fileprivate var _atuStatus: String {
        get { return _radioQ.sync { __atuStatus } }
        set { _radioQ.sync(flags: .barrier) { __atuStatus = newValue } } }
    
    fileprivate var _atuEnabled: Bool {
        get { return _radioQ.sync { __atuEnabled } }
        set { _radioQ.sync(flags: .barrier) { __atuEnabled = newValue } } }
    
    fileprivate var _atuMemoriesEnabled: Bool {
        get { return _radioQ.sync { __atuMemoriesEnabled } }
        set { _radioQ.sync(flags: .barrier) { __atuMemoriesEnabled = newValue } } }
    
    fileprivate var _atuUsingMemories: Bool {
        get { return _radioQ.sync { __atuUsingMemories } }
        set { _radioQ.sync(flags: .barrier) { __atuUsingMemories = newValue } } }
    
    fileprivate var _availablePanadapters: Int {
        get { return _radioQ.sync { __availablePanadapters } }
        set { _radioQ.sync(flags: .barrier) { __availablePanadapters = newValue } } }
    
    fileprivate var _availableSlices: Int {
        get { return _radioQ.sync { __availableSlices } }
        set { _radioQ.sync(flags: .barrier) { __availableSlices = newValue } } }
    
    fileprivate var _binauralRxEnabled: Bool {
        get { return _radioQ.sync { __binauralRxEnabled } }
        set { _radioQ.sync(flags: .barrier) { __binauralRxEnabled = newValue } } }
    
    fileprivate var _calFreq: Int {
        get { return _radioQ.sync { __calFreq } }
        set { _radioQ.sync(flags: .barrier) { __calFreq = newValue } } }
    
    fileprivate var _callsign: String {
        get { return _radioQ.sync { __callsign } }
        set { _radioQ.sync(flags: .barrier) { __callsign = newValue } } }
    
    fileprivate var _carrierLevel: Int {
        get { return _radioQ.sync { __carrierLevel } }
        set { _radioQ.sync(flags: .barrier) { __carrierLevel = newValue.bound(kMinLevel, kMaxLevel) } } }
    
    fileprivate var _chassisSerial: String {
        get { return _radioQ.sync { __chassisSerial } }
        set { _radioQ.sync(flags: .barrier) { __chassisSerial = newValue } } }
    
    fileprivate var _companderEnabled: Bool {
        get { return _radioQ.sync { __companderEnabled } }
        set { _radioQ.sync(flags: .barrier) { __companderEnabled = newValue } } }
    
    fileprivate var _companderLevel: Int {
        get { return _radioQ.sync { __companderLevel } }
        set { _radioQ.sync(flags: .barrier) { __companderLevel = newValue.bound(kMinLevel, kMaxLevel) } } }
    
    fileprivate var _currentGlobalProfile: String {
        get { return _radioQ.sync { __currentGlobalProfile } }
        set { _radioQ.sync(flags: .barrier) { __currentGlobalProfile = newValue } } }
    
    fileprivate var _currentMicProfile: String {
        get { return _radioQ.sync { __currentMicProfile } }
        set { _radioQ.sync(flags: .barrier) { __currentMicProfile = newValue } } }
    
    fileprivate var _currentTxProfile: String {
        get { return _radioQ.sync { __currentTxProfile } }
        set { _radioQ.sync(flags: .barrier) { __currentTxProfile = newValue } } }
    
    fileprivate var _cwAutoSpaceEnabled: Bool {
        get { return _radioQ.sync { __cwAutoSpaceEnabled } }
        set { _radioQ.sync(flags: .barrier) { __cwAutoSpaceEnabled = newValue } } }
    
    fileprivate var _cwBreakInEnabled: Bool {
        get { return _radioQ.sync { __cwBreakInEnabled } }
        set { _radioQ.sync(flags: .barrier) { __cwBreakInEnabled = newValue } } }
    
    fileprivate var _cwBreakInDelay: Int {
        get { return _radioQ.sync { __cwBreakInDelay } }
        set { _radioQ.sync(flags: .barrier) { __cwBreakInDelay = newValue.bound(kMinDelay, kMaxDelay) } } }
    
    fileprivate var _cwIambicEnabled: Bool {
        get { return _radioQ.sync { __cwIambicEnabled } }
        set { _radioQ.sync(flags: .barrier) { __cwIambicEnabled = newValue } } }
    
    fileprivate var _cwIambicMode: Int {
        get { return _radioQ.sync { __cwIambicMode } }
        set { _radioQ.sync(flags: .barrier) { __cwIambicMode = newValue } } }
    
    fileprivate var _cwlEnabled: Bool {
        get { return _radioQ.sync { __cwlEnabled } }
        set { _radioQ.sync(flags: .barrier) { __cwlEnabled = newValue } } }
    
    fileprivate var _cwPitch: Int {
        get { return _radioQ.sync { __cwPitch } }
        set { _radioQ.sync(flags: .barrier) { __cwPitch = newValue.bound(kMinPitch, kMaxPitch) } } }
    
    fileprivate var _cwSidetoneEnabled: Bool {
        get { return _radioQ.sync { __cwSidetoneEnabled } }
        set { _radioQ.sync(flags: .barrier) { __cwSidetoneEnabled = newValue } } }
    
    fileprivate var _cwSwapPaddles: Bool {
        get { return _radioQ.sync { __cwSwapPaddles } }
        set { _radioQ.sync(flags: .barrier) { __cwSwapPaddles = newValue } } }
    
    fileprivate var _cwSyncCwxEnabled: Bool {
        get { return _radioQ.sync { __cwSyncCwxEnabled } }
        set { _radioQ.sync(flags: .barrier) { __cwSyncCwxEnabled = newValue } } }
    
    fileprivate var _cwWeight: Int {
        get { return _radioQ.sync { __cwWeight } }
        set { _radioQ.sync(flags: .barrier) { __cwWeight = newValue } } }
    
    fileprivate var _cwSpeed: Int {
        get { return _radioQ.sync { __cwSpeed } }
        set { _radioQ.sync(flags: .barrier) { __cwSpeed = newValue.bound(kMinWpm, kMaxWpm) } } }
    
    fileprivate var _daxEnabled: Bool {
        get { return _radioQ.sync { __daxEnabled } }
        set { _radioQ.sync(flags: .barrier) { __daxEnabled = newValue } } }
    
    fileprivate var _daxIqAvailable: Int {
        get { return _radioQ.sync { __daxIqAvailable } }
        set { _radioQ.sync(flags: .barrier) { __daxIqAvailable = newValue } } }
    
    fileprivate var _daxIqCapacity: Int {
        get { return _radioQ.sync { __daxIqCapacity } }
        set { _radioQ.sync(flags: .barrier) { __daxIqCapacity = newValue } } }
    
    fileprivate var _enforcePrivateIpEnabled: Bool {
        get { return _radioQ.sync { __enforcePrivateIpEnabled } }
        set { _radioQ.sync(flags: .barrier) { __enforcePrivateIpEnabled = newValue } } }
    
    fileprivate var _filterCwAutoLevel: Int {
        get { return _radioQ.sync { __filterCwAutoLevel } }
        set { _radioQ.sync(flags: .barrier) { __filterCwAutoLevel = newValue } } }
    
    fileprivate var _filterDigitalAutoLevel: Int {
        get { return _radioQ.sync { __filterDigitalAutoLevel } }
        set { _radioQ.sync(flags: .barrier) { __filterDigitalAutoLevel = newValue } } }
    
    fileprivate var _filterVoiceAutoLevel: Int {
        get { return _radioQ.sync { __filterVoiceAutoLevel } }
        set { _radioQ.sync(flags: .barrier) { __filterVoiceAutoLevel = newValue } } }
    
    fileprivate var _filterCwLevel: Int {
        get { return _radioQ.sync { __filterCwLevel } }
        set { _radioQ.sync(flags: .barrier) { __filterCwLevel = newValue } } }
    
    fileprivate var _filterDigitalLevel: Int {
        get { return _radioQ.sync { __filterDigitalLevel } }
        set { _radioQ.sync(flags: .barrier) { __filterDigitalLevel = newValue } } }
    
    fileprivate var _filterVoiceLevel: Int {
        get { return _radioQ.sync { __filterVoiceLevel } }
        set { _radioQ.sync(flags: .barrier) { __filterVoiceLevel = newValue } } }
    
    fileprivate var _fpgaMbVersion: String {
        get { return _radioQ.sync { __fpgaMbVersion } }
        set { _radioQ.sync(flags: .barrier) { __fpgaMbVersion = newValue } } }
    
    fileprivate var _freqErrorPpb: Int {
        get { return _radioQ.sync { __freqErrorPpb } }
        set { _radioQ.sync(flags: .barrier) { __freqErrorPpb = newValue } } }
    
    fileprivate var _frequency: Int {
        get { return _radioQ.sync { __frequency } }
        set { _radioQ.sync(flags: .barrier) { __frequency = newValue } } }
    
    fileprivate var _fullDuplexEnabled: Bool {
        get { return _radioQ.sync { __fullDuplexEnabled } }
        set { _radioQ.sync(flags: .barrier) { __fullDuplexEnabled = newValue } } }
    
    fileprivate var _gateway: String {
        get { return _radioQ.sync { __gateway } }
        set { _radioQ.sync(flags: .barrier) { __gateway = newValue } } }
    
    fileprivate var _headphoneGain: Int {
        get { return _radioQ.sync { __headphoneGain } }
        set { _radioQ.sync(flags: .barrier) { __headphoneGain = newValue.bound(kMinLevel, kMaxLevel) } } }
    
    fileprivate var _headphoneMute: Bool {
        get { return _radioQ.sync { __headphoneMute } }
        set { _radioQ.sync(flags: .barrier) { __headphoneMute = newValue } } }
    
    fileprivate var _gpsAltitude: String {
        get { return _radioQ.sync { __gpsAltitude } }
        set { _radioQ.sync(flags: .barrier) { __gpsAltitude = newValue } } }
    
    fileprivate var _gpsFrequencyError: Double {
        get { return _radioQ.sync { __gpsFrequencyError } }
        set { _radioQ.sync(flags: .barrier) { __gpsFrequencyError = newValue } } }
    
    fileprivate var _gpsGrid: String {
        get { return _radioQ.sync { __gpsGrid } }
        set { _radioQ.sync(flags: .barrier) { __gpsGrid = newValue } } }
    
    fileprivate var _gpsLatitude: String {
        get { return _radioQ.sync { __gpsLatitude } }
        set { _radioQ.sync(flags: .barrier) { __gpsLatitude = newValue } } }
    
    fileprivate var _gpsLongitude: String {
        get { return _radioQ.sync { __gpsLongitude } }
        set { _radioQ.sync(flags: .barrier) { __gpsLongitude = newValue } } }
    
    fileprivate var _gpsPresent: Bool {
        get { return _radioQ.sync { __gpsPresent } }
        set { _radioQ.sync(flags: .barrier) { __gpsPresent = newValue } } }
    
    fileprivate var _gpsSpeed: String {
        get { return _radioQ.sync { __gpsSpeed } }
        set { _radioQ.sync(flags: .barrier) { __gpsSpeed = newValue } } }
    
    fileprivate var _gpsStatus: String {
        get { return _radioQ.sync { __gpsStatus } }
        set { _radioQ.sync(flags: .barrier) { __gpsStatus = newValue } } }
    
    fileprivate var _gpsTime: String {
        get { return _radioQ.sync { __gpsTime } }
        set { _radioQ.sync(flags: .barrier) { __gpsTime = newValue } } }
    
    fileprivate var _gpsTrack: Double {
        get { return _radioQ.sync { __gpsTrack } }
        set { _radioQ.sync(flags: .barrier) { __gpsTrack = newValue } } }
    
    fileprivate var _gpsTracked: Bool {
        get { return _radioQ.sync { __gpsTracked } }
        set { _radioQ.sync(flags: .barrier) { __gpsTracked = newValue } } }
    
    fileprivate var _gpsVisible: Bool {
        get { return _radioQ.sync { __gpsVisible } }
        set { _radioQ.sync(flags: .barrier) { __gpsVisible = newValue } } }
    
    fileprivate var _hwAlcEnabled: Bool {
        get { return _radioQ.sync { __hwAlcEnabled } }
        set { _radioQ.sync(flags: .barrier) { __hwAlcEnabled = newValue } } }
    
    fileprivate var _inhibit: Bool {
        get { return _radioQ.sync { __inhibit } }
        set { _radioQ.sync(flags: .barrier) { __inhibit = newValue } } }
    
    fileprivate var _ipAddress: String {
        get { return _radioQ.sync { __ipAddress } }
        set { _radioQ.sync(flags: .barrier) { __ipAddress = newValue } } }
    
    fileprivate var _location: String {
        get { return _radioQ.sync { __location } }
        set { _radioQ.sync(flags: .barrier) { __location = newValue } } }
    
    fileprivate var _macAddress: String {
        get { return _radioQ.sync { __macAddress } }
        set { _radioQ.sync(flags: .barrier) { __macAddress = newValue } } }
    
    fileprivate var _lineoutGain: Int {
        get { return _radioQ.sync { __lineoutGain } }
        set { _radioQ.sync(flags: .barrier) { __lineoutGain = newValue.bound(kMinLevel, kMaxLevel) } } }
    
    fileprivate var _lineoutMute: Bool {
        get { return _radioQ.sync { __lineoutMute } }
        set { _radioQ.sync(flags: .barrier) { __lineoutMute = newValue } } }
    
    fileprivate var _maxPowerLevel: Int {
        get { return _radioQ.sync { __maxPowerLevel } }
        set { _radioQ.sync(flags: .barrier) { __maxPowerLevel = newValue.bound(kMinLevel, kMaxLevel) } } }
    
    fileprivate var _metInRxEnabled: Bool {
        get { return _radioQ.sync { __metInRxEnabled } }
        set { _radioQ.sync(flags: .barrier) { __metInRxEnabled = newValue } } }
    
    fileprivate var _micAccEnabled: Bool {
        get { return _radioQ.sync { __micAccEnabled } }
        set { _radioQ.sync(flags: .barrier) { __micAccEnabled = newValue } } }
    
    fileprivate var _micBoostEnabled: Bool {
        get { return _radioQ.sync { __micBoostEnabled } }
        set { _radioQ.sync(flags: .barrier) { __micBoostEnabled = newValue } } }
    
    fileprivate var _micBiasEnabled: Bool {
        get { return _radioQ.sync { __micBiasEnabled } }
        set { _radioQ.sync(flags: .barrier) { __micBiasEnabled = newValue } } }
    
    fileprivate var _micLevel: Int {
        get { return _radioQ.sync { __micLevel } }
        set { _radioQ.sync(flags: .barrier) { __micLevel = newValue.bound(kMinLevel, kMaxLevel) } } }
    
    fileprivate var _micSelection: String {
        get { return _radioQ.sync { __micSelection } }
        set { _radioQ.sync(flags: .barrier) { __micSelection = newValue } } }
    
    fileprivate var _netmask: String {
        get { return _radioQ.sync { __netmask } }
        set { _radioQ.sync(flags: .barrier) { __netmask = newValue } } }
    
    fileprivate var _nickname: String {
        get { return _radioQ.sync { __nickname } }
        set { _radioQ.sync(flags: .barrier) { __nickname = newValue } } }
    
    fileprivate var _numberOfScus: Int {
        get { return _radioQ.sync { __numberOfScus } }
        set { _radioQ.sync(flags: .barrier) { __numberOfScus = newValue } } }
    
    fileprivate var _numberOfSlices: Int {
        get { return _radioQ.sync { __numberOfSlices } }
        set { _radioQ.sync(flags: .barrier) { __numberOfSlices = newValue } } }
    
    fileprivate var _numberOfTx: Int {
        get { return _radioQ.sync { __numberOfTx } }
        set { _radioQ.sync(flags: .barrier) { __numberOfTx = newValue } } }
    
    fileprivate var _psocMbPa100Version: String {
        get { return _radioQ.sync { __psocMbPa100Version } }
        set { _radioQ.sync(flags: .barrier) { __psocMbPa100Version = newValue } } }
    
    fileprivate var _psocMbtrxVersion: String {
        get { return _radioQ.sync { __psocMbtrxVersion } }
        set { _radioQ.sync(flags: .barrier) { __psocMbtrxVersion = newValue } } }
    
    fileprivate var _radioModel: String {
        get { return _radioQ.sync { __radioModel } }
        set { _radioQ.sync(flags: .barrier) { __radioModel = newValue } } }
    
    fileprivate var _radioOptions: String {
        get { return _radioQ.sync { __radioOptions } }
        set { _radioQ.sync(flags: .barrier) { __radioOptions = newValue } } }
    
    fileprivate var _radioScreenSaver: String {
        get { return _radioQ.sync { __radioScreenSaver } }
        set { _radioQ.sync(flags: .barrier) { __radioScreenSaver = newValue } } }
    
    fileprivate var _rawIqEnabled: Bool {
        get { return _radioQ.sync { __rawIqEnabled } }
        set { _radioQ.sync(flags: .barrier) { __rawIqEnabled = newValue } } }
    
    fileprivate var _rcaTxReqEnabled: Bool {
        get { return _radioQ.sync { __rcaTxReqEnabled } }
        set { _radioQ.sync(flags: .barrier) { __rcaTxReqEnabled = newValue } } }
    
    fileprivate var _rcaTxReqPolarity: Bool {
        get { return _radioQ.sync { __rcaTxReqPolarity } }
        set { _radioQ.sync(flags: .barrier) { __rcaTxReqPolarity = newValue } } }
    
    fileprivate var _reason: String {
        get { return _radioQ.sync { __reason } }
        set { _radioQ.sync(flags: .barrier) { __reason = newValue } } }
    
    fileprivate var _region: String {
        get { return _radioQ.sync { __region } }
        set { _radioQ.sync(flags: .barrier) { __region = newValue } } }
    
    fileprivate var _remoteOnEnabled: Bool {
        get { return _radioQ.sync { __remoteOnEnabled } }
        set { _radioQ.sync(flags: .barrier) { __remoteOnEnabled = newValue } } }
    
    fileprivate var _rfPower: Int {
        get { return _radioQ.sync { __rfPower } }
        set { _radioQ.sync(flags: .barrier) { __rfPower = newValue.bound(kMinLevel, kMaxLevel) } } }
    
    fileprivate var _rttyMark: Int {
        get { return _radioQ.sync { __rttyMark } }
        set { _radioQ.sync(flags: .barrier) { __rttyMark = newValue } } }
    
    fileprivate var _sbMonitorEnabled: Bool {
        get { return _radioQ.sync { __sbMonitorEnabled } }
        set { _radioQ.sync(flags: .barrier) { __sbMonitorEnabled = newValue } } }
    
    fileprivate var _smartSdrMB: String {
        get { return _radioQ.sync { __smartSdrMB } }
        set { _radioQ.sync(flags: .barrier) { __smartSdrMB = newValue } } }
    
    fileprivate var _snapTuneEnabled: Bool {
        get { return _radioQ.sync { __snapTuneEnabled } }
        set { _radioQ.sync(flags: .barrier) { __snapTuneEnabled = newValue } } }
    
    fileprivate var _softwareVersion: String {
        get { return _radioQ.sync { __softwareVersion } }
        set { _radioQ.sync(flags: .barrier) { __softwareVersion = newValue } } }
    
    fileprivate var _source: String {
        get { return _radioQ.sync { __source } }
        set { _radioQ.sync(flags: .barrier) { __source = newValue } } }
    
    fileprivate var _speechProcessorEnabled: Bool {
        get { return _radioQ.sync { __speechProcessorEnabled } }
        set { _radioQ.sync(flags: .barrier) { __speechProcessorEnabled = newValue } } }
    
    fileprivate var _speechProcessorLevel: Int {
        get { return _radioQ.sync { __speechProcessorLevel } }
        set { _radioQ.sync(flags: .barrier) { __speechProcessorLevel = newValue } } }
    
    fileprivate var _ssbPeakControlEnabled: Bool {
        get { return _radioQ.sync { __ssbPeakControlEnabled } }
        set { _radioQ.sync(flags: .barrier) { __ssbPeakControlEnabled = newValue } } }
    
    fileprivate var _startOffset: Bool {
        get { return _radioQ.sync { __startOffset } }
        set { _radioQ.sync(flags: .barrier) { __startOffset = newValue } } }
    
    fileprivate var _state: String {
        get { return _radioQ.sync { __state } }
        set { _radioQ.sync(flags: .barrier) { __state = newValue } } }
    
    fileprivate var _staticGateway: String {
        get { return _radioQ.sync { __staticGateway } }
        set { _radioQ.sync(flags: .barrier) { __staticGateway = newValue } } }
    
    fileprivate var _staticIp: String {
        get { return _radioQ.sync { __staticIp } }
        set { _radioQ.sync(flags: .barrier) { __staticIp = newValue } } }
    
    fileprivate var _staticNetmask: String {
        get { return _radioQ.sync { __staticNetmask } }
        set { _radioQ.sync(flags: .barrier) { __staticNetmask = newValue } } }
    
    fileprivate var _timeout: Int {
        get { return _radioQ.sync { __timeout } }
        set { _radioQ.sync(flags: .barrier) { __timeout = newValue } } }
    
    fileprivate var _tnfEnabled: Bool {
        get { return _radioQ.sync { __tnfEnabled } }
        set { _radioQ.sync(flags: .barrier) { __tnfEnabled = newValue } } }
    
    fileprivate var _tune: Bool {
        get { return _radioQ.sync { __tune } }
        set { _radioQ.sync(flags: .barrier) { __tune = newValue } } }
    
    fileprivate var _tunePower: Int {
        get { return _radioQ.sync { __tunePower } }
        set { _radioQ.sync(flags: .barrier) { __tunePower = newValue.bound(kMinLevel, kMaxLevel) } } }
    
    fileprivate var _txFilterChanges: Bool {
        get { return _radioQ.sync { __txFilterChanges } }
        set { _radioQ.sync(flags: .barrier) { __txFilterChanges = newValue } } }
    
    fileprivate var _txFilterHigh: Int {
        get { return _radioQ.sync { __txFilterHigh } }
        set { let value = txFilterHighLimits(txFilterLow, newValue) ; _radioQ.sync(flags: .barrier) { __txFilterHigh = value } } }
    
    fileprivate var _txFilterLow: Int {
        get { return _radioQ.sync { __txFilterLow } }
        set { let value = txFilterLowLimits(newValue, txFilterHigh) ; _radioQ.sync(flags: .barrier) { __txFilterLow = value } } }
    
    fileprivate var _txInWaterfallEnabled: Bool {
        get { return _radioQ.sync { __txInWaterfallEnabled } }
        set { _radioQ.sync(flags: .barrier) { __txInWaterfallEnabled = newValue } } }
    
    fileprivate var _txRfPowerChanges: Bool {
        get { return _radioQ.sync { __txRfPowerChanges } }
        set { _radioQ.sync(flags: .barrier) { __txRfPowerChanges = newValue } } }
    
    fileprivate var _txDelay: Int {
        get { return _radioQ.sync { __txDelay } }
        set { _radioQ.sync(flags: .barrier) { __txDelay = newValue } } }
    
    fileprivate var _txAllowed: Bool {
        get { return _radioQ.sync { __txAllowed } }
        set { _radioQ.sync(flags: .barrier) { __txAllowed = newValue } } }
    
    fileprivate var _txMonitorAvailable: Bool {
        get { return _radioQ.sync { __txMonitorAvailable } }
        set { _radioQ.sync(flags: .barrier) { __txMonitorAvailable = newValue } } }
    
    fileprivate var _txMonitorEnabled: Bool {
        get { return _radioQ.sync { __txMonitorEnabled } }
        set { _radioQ.sync(flags: .barrier) { __txMonitorEnabled = newValue } } }
    
    fileprivate var _txMonitorGainCw: Int {
        get { return _radioQ.sync { __txMonitorGainCw } }
        set { _radioQ.sync(flags: .barrier) { __txMonitorGainCw = newValue.bound(kMinLevel, kMaxLevel) } } }
    
    fileprivate var _txMonitorGainSb: Int {
        get { return _radioQ.sync { __txMonitorGainSb } }
        set { _radioQ.sync(flags: .barrier) { __txMonitorGainSb = newValue.bound(kMinLevel, kMaxLevel) } } }
    
    fileprivate var _txMonitorPanCw: Int {
        get { return _radioQ.sync { __txMonitorPanCw } }
        set { _radioQ.sync(flags: .barrier) { __txMonitorPanCw = newValue.bound(kMinLevel, kMaxLevel) } } }
    
    fileprivate var _txMonitorPanSb: Int {
        get { return _radioQ.sync { __txMonitorPanSb } }
        set { _radioQ.sync(flags: .barrier) { __txMonitorPanSb = newValue.bound(kMinLevel, kMaxLevel) } } }
    
    fileprivate var _tx1Delay: Int {
        get { return _radioQ.sync { __tx1Delay } }
        set { _radioQ.sync(flags: .barrier) { __tx1Delay = newValue } } }
    
    fileprivate var _tx1Enabled: Bool {
        get { return _radioQ.sync { __tx1Enabled } }
        set { _radioQ.sync(flags: .barrier) { __tx1Enabled = newValue } } }
    
    fileprivate var _tx2Delay: Int {
        get { return _radioQ.sync { __tx2Delay } }
        set { _radioQ.sync(flags: .barrier) { __tx2Delay = newValue } } }
    
    fileprivate var _tx2Enabled: Bool {
        get { return _radioQ.sync { __tx2Enabled } }
        set { _radioQ.sync(flags: .barrier) { __tx2Enabled = newValue } } }
    
    fileprivate var _tx3Delay: Int {
        get { return _radioQ.sync { __tx3Delay } }
        set { _radioQ.sync(flags: .barrier) { __tx3Delay = newValue } } }
    
    fileprivate var _tx3Enabled: Bool {
        get { return _radioQ.sync { __tx3Enabled } }
        set { _radioQ.sync(flags: .barrier) { __tx3Enabled = newValue } } }
    
    fileprivate var _voxEnabled: Bool {
        get { return _radioQ.sync { __voxEnabled } }
        set { _radioQ.sync(flags: .barrier) { __voxEnabled = newValue } } }
    
    fileprivate var _voxDelay: Int {
        get { return _radioQ.sync { __voxDelay } }
        set { _radioQ.sync(flags: .barrier) { __voxDelay = newValue.bound(kMinLevel, kMaxLevel) } } }
    
    fileprivate var _voxLevel: Int {
        get { return _radioQ.sync { __voxLevel } }
        set { _radioQ.sync(flags: .barrier) { __voxLevel = newValue.bound(kMinLevel, kMaxLevel) } } }
    
    fileprivate var _waveformList: String {
        get { return _radioQ.sync { __waveformList } }
        set { _radioQ.sync(flags: .barrier) { __waveformList = newValue } } }
    
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
    // MARK: - Public properties - KVO compliant (no message to Radio)
    
    // FIXME: Should any of these send a message to the Radio?
    //          If yes, implement it, if not should they be "get" only?
    
    // listed in alphabetical order
    @objc dynamic public var atuEnabled: Bool {
        return _atuEnabled }
    
    @objc dynamic public var atuPresent: Bool {
        return _atuPresent }
    
    @objc dynamic public var atuStatus: String {
        return _atuStatus }
    
    @objc dynamic public var atuUsingMemories: Bool {
        return _atuUsingMemories }
    
    @objc dynamic public var availablePanadapters: Int {
        return _availablePanadapters }
    
    @objc dynamic public var availableSlices: Int {
        return _availableSlices }
    
    @objc dynamic public var chassisSerial: String {
        return _chassisSerial }
    
    @objc dynamic public var daxIqAvailable: Int {
        return _daxIqAvailable }
    
    @objc dynamic public var daxIqCapacity: Int {
        return _daxIqCapacity }
    
    @objc dynamic public var fpgaMbVersion: String {
        return _fpgaMbVersion }
    
    @objc dynamic public var frequency: Int {
        get {  return _frequency }
        set { if _frequency != newValue { _frequency = newValue } } }
    
    @objc dynamic public var gateway: String {
        return _gateway }
    
    @objc dynamic public var gpsAltitude: String {
        return _gpsAltitude }
    
    @objc dynamic public var gpsFrequencyError: Double {
        return _gpsFrequencyError }
    
    @objc dynamic public var gpsStatus: String {
        return _gpsStatus }
    
    @objc dynamic public var gpsGrid: String {
        return _gpsGrid }
    
    @objc dynamic public var gpsLatitude: String {
        return _gpsLatitude }
    
    @objc dynamic public var gpsLongitude: String {
        return _gpsLongitude }
    
    @objc dynamic public var gpsPresent: Bool {
        return _gpsPresent }
    
    @objc dynamic public var gpsSpeed: String {
        return _gpsSpeed }
    
    @objc dynamic public var gpsTime: String {
        return _gpsTime }
    
    @objc dynamic public var gpsTrack: Double {
        return _gpsTrack }
    
    @objc dynamic public var gpsTracked: Bool {
        return _gpsTracked }
    
    @objc dynamic public var gpsVisible: Bool {
        return _gpsVisible }
    
    @objc dynamic public var ipAddress: String {
        return _ipAddress }
    
    @objc dynamic public var location: String {
        return _location }
    
    @objc dynamic public var macAddress: String {
        return _macAddress }
    
    @objc dynamic public var netmask: String {
        return _netmask }
    
    @objc dynamic public var numberOfScus: Int {
        return _numberOfScus }
    
    @objc dynamic public var numberOfSlices: Int {
        return _numberOfSlices }
    
    @objc dynamic public var numberOfTx: Int {
        return _numberOfTx }
    
    @objc dynamic public var psocMbPa100Version: String {
        return _psocMbPa100Version }
    
    @objc dynamic public var psocMbtrxVersion: String {
        return _psocMbtrxVersion }
    
    @objc dynamic public var radioModel: String {
        return _radioModel }
    
    @objc dynamic public var radioOptions: String {
        return _radioOptions }
    
    @objc dynamic public var rawIqEnabled: Bool {
        return _rawIqEnabled }
    
    @objc dynamic public var reason: String {
        return _reason }
    
    @objc dynamic public var region: String {
        return _region }
    
    @objc dynamic public var sbMonitorEnabled: Bool {
        return _sbMonitorEnabled }
    
    @objc dynamic public var smartSdrMB: String {
        return _smartSdrMB }
    
    @objc dynamic public var softwareVersion: String {
        return _softwareVersion }
    
    @objc dynamic public var source: String {
        return _source }
    
    @objc dynamic public var state: String {
        return _state }
    
    @objc dynamic public var txAllowed: Bool {
        return _txAllowed }
    
    @objc dynamic public var txDelay: Int {
        return _txDelay }
    
    @objc dynamic public var txFilterChanges: Bool {
        return _txFilterChanges }
    
    @objc dynamic public var txMonitorAvailable: Bool {
        return _txMonitorAvailable }
    
    @objc dynamic public var txRfPowerChanges: Bool {
        return _txRfPowerChanges }
    
    @objc dynamic public var waveformList: String {
        return _waveformList }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - NON KVO compliant Setters / Getters with synchronization
    
    // collections
    public var audioStreams: [DaxStreamId: AudioStream] {
        get { return _objectQ.sync { _audioStreams } }
        set { _objectQ.sync(flags: .barrier) { _audioStreams = newValue } } }
    
    public var equalizers: [EqualizerType: Equalizer] {
        get { return _objectQ.sync { _equalizers } }
        set { _objectQ.sync(flags: .barrier) { _equalizers = newValue } } }
    
    public var iqStreams: [DaxStreamId: IqStream] {
        get { return _objectQ.sync { _iqStreams } }
        set { _objectQ.sync(flags: .barrier) { _iqStreams = newValue } } }
    
    public var memories: [MemoryId: Memory] {
        get { return _objectQ.sync { _memories } }
        set { _objectQ.sync(flags: .barrier) { _memories = newValue } } }
    
    public var meters: [MeterId: Meter] {
        get { return _objectQ.sync { _meters } }
        set { _objectQ.sync(flags: .barrier) { _meters = newValue } } }
    
    public var micAudioStreams: [DaxStreamId: MicAudioStream] {
        get { return _objectQ.sync { _micAudioStreams } }
        set { _objectQ.sync(flags: .barrier) { _micAudioStreams = newValue } } }
    
    public var opusStreams: [OpusId: Opus] {
        get { return _objectQ.sync { _opusStreams } }
        set { _objectQ.sync(flags: .barrier) { _opusStreams = newValue } } }
    
    public var panadapters: [PanadapterId: Panadapter] {
        get { return _objectQ.sync { _panadapters } }
        set { _objectQ.sync(flags: .barrier) { _panadapters = newValue } } }
    
    public var profiles: [ProfileToken: [ProfileString]] {
        get { return _objectQ.sync { _profiles } }
        set { _objectQ.sync(flags: .barrier) { _profiles = newValue } } }
    
    public var replyHandlers: [SequenceId: ReplyTuple] {
        get { return _objectQ.sync { _replyHandlers } }
        set { _objectQ.sync(flags: .barrier) { _replyHandlers = newValue } } }
    
    public var slices: [SliceId: Slice] {
        get { return _objectQ.sync { _slices } }
        set { _objectQ.sync(flags: .barrier) { _slices = newValue } } }
    
    public var tnfs: [TnfId: Tnf] {
        get { return _objectQ.sync { _tnfs } }
        set { _objectQ.sync(flags: .barrier) { _tnfs = newValue } } }
    
    public var txAudioStreams: [DaxStreamId: TxAudioStream] {
        get { return _objectQ.sync { _txAudioStreams } }
        set { _objectQ.sync(flags: .barrier) { _txAudioStreams = newValue } } }
    
    public var waterfalls: [WaterfallId: Waterfall] {
        get { return _objectQ.sync { _waterfalls } }
        set { _objectQ.sync(flags: .barrier) { _waterfalls = newValue } } }
    
    public var xvtrs: [XvtrId: Xvtr] {
        get { return _objectQ.sync { _xvtrs } }
        set { _objectQ.sync(flags: .barrier) { _xvtrs = newValue } } }
    
    // other
    public var connectionState: ConnectionState {
        get { return _radioQ.sync { _connectionState } }
        set { _radioQ.sync(flags: .barrier) { _connectionState = newValue } } }
    
    public var _udpPort: UInt16 {
        get { return _radioQ.sync { __udpPort } }
        set { _radioQ.sync(flags: .barrier) { __udpPort = newValue } } }
    
    
    // ----------------------------------------------------------------------------
    // Mark: - Token enums in alphabetical order.
    //          Only populate values that != case value
    // ----------------------------------------------------------------------------
    
    // ----------------------------------------------------------------------------
    // Mark: - Atu
    
    public enum AtuToken: String {
        case status
        case atuEnabled = "atu_enabled"
        case memoriesEnabled = "memories_enabled"
        case usingMemories = "using_mem"
    }
    // ----------------------------------------------------------------------------
    // Mark: - Display
    
    enum DisplayToken: String {
        case panadapter = "pan"
        case waterfall
    }
    // ----------------------------------------------------------------------------
    // Mark: - Equalizer Apf
    
    public enum EqApfToken: String {
        case gain
        case mode
        case qFactor
    }
    // ----------------------------------------------------------------------------
    // Mark: - Gps
    
    enum GpsToken: String {
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
    // Mark: - Info replies
    
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
    // Mark: - Interlock
    
    public enum InterlockToken: String {
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
    // Mark: - Profile
    
    public enum ProfileToken: String {
        case global
        case mic
        case tx
    }
    public enum ProfileSubType: String {
        case current
        case list
    }
    // ----------------------------------------------------------------------------
    // Mark: - Radio
    
    public enum RadioToken: String {
        case autoLevel = "auto_level"
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
    // Mark: - Status
    
    enum StatusToken : String {
        case audioStream = "audio_stream"
        case atu
        case client
        case cwx
        case daxiq
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
        case waveform
        case xvtr
    }
    
    // ----------------------------------------------------------------------------
    // Mark: - Transmit
    
    public enum TransmitToken: String {
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
    // Mark: - UsbCable
    
    enum UsbCableToken: String {
        case none
    }
    // ----------------------------------------------------------------------------
    // Mark: - Version replies
    
    enum VersionToken: String {
        case fpgaMb = "fpga-mb"
        case psocMbPa100 = "psoc-mbpa100"
        case psocMbTrx = "psoc-mbtrx"
        case smartSdrMB = "smartsdr-mb"
    }
    // ----------------------------------------------------------------------------
    // Mark: - Waveform
    
    enum WaveformToken: String {
        case waveformList = "installed_list"
    }
    // ----------------------------------------------------------------------------
    // Mark: - Xvtr
    
    enum XvtrToken: String {
        case none
    }
    
    
    // ----------------------------------------------------------------------------
    // Mark: - Other Radio related enums
    
    public enum ConnectionState: Equatable {
        case clientConnected
        case disconnected(reason: DisconnectReason)
        case tcpConnected(host: String, port: UInt16)
        case udpBound(port: UInt16)
        case update(host: String, port: UInt16)
        
        public static func ==(lhs: ConnectionState, rhs: ConnectionState) -> Bool {
            return lhs == rhs
        }
    }
    public enum DisconnectReason: String {
        case closed = "Closed"
        case connectionFailed = "Connection failed"
        case timeout = "Timeout"
        case tooManyGuiClients = "Too many Gui clients"
    }
    public enum EqualizerType: String {
        case rx         // deprecated type
        case rxsc
        case tx         // deprecated type
        case txsc
    }
    public struct FilterSpec {
        var filterHigh: Int
        var filterLow: Int
        var label: String
        var mode: String
        var txFilterHigh: Int
        var txFilterLow: Int
    }
    public struct TxFilter {
        var high = 0
        var low = 0
    }
    
    // --------------------------------------------------------------------------------
    // MARK: - Type Alias (alphabetical)
    
    public typealias CommandTuple = (command: String, diagnostic: Bool, replyHandler: ReplyHandler?)
    public typealias AntennaPort = String
    public typealias AudioStreamId = String
    public typealias DaxStreamId = String
    public typealias DaxChannel = Int
    public typealias DaxIqChannel = Int
    public typealias FilterMode = String
    public typealias KeyValuesArray = [(key:String, value:String)]
    public typealias MemoryId = String
    public typealias MeterId = String
    public typealias MeterName = String
    public typealias MicrophonePort = String
    public typealias OpusId = String
    public typealias PanadapterId = String
    public typealias ProfileString = String
    public typealias RfGainValue = String
    public typealias SliceId = String
    public typealias TnfId = String
    public typealias UsbCableId = String
    public typealias ValuesArray = [String]
    public typealias WaterfallId = String
    public typealias XvtrId = String
    
    /// Enum for Commands
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
    
}
