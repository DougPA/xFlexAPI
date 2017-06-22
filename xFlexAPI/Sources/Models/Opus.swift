//
//  Opus.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 2/9/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Protocols

public protocol OpusStreamHandler {
    
    // method to process Opus data stream
    func opusStreamHandler(_ frame: OpusFrame) -> Void    
}

// --------------------------------------------------------------------------------
// MARK: - Opus Class implementation
// --------------------------------------------------------------------------------

public final class Opus : NSObject, KeyValueParser, VitaHandler {
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate weak var _radio: Radio?                 // The Radio that owns the Opus stream
    fileprivate var _id: Radio.OpusId                   // The Opus stream id

    fileprivate var _initialized = false                // True if initialized by Radio hardware
    fileprivate var _ip = ""                            // IP Address of ???
    fileprivate var _port = 0                           // port number used by Opus
    
    fileprivate var rxSeq: Int?                         // Rx sequence number
    fileprivate var rxByteCount = 0                     // Rx byte count
    fileprivate var rxPacketCount = 0                   // Rx packet count
    fileprivate var rxBytesPerSec = 0                   // Rx rate
    fileprivate var rxLostPacketCount = 0               // Rx lost packet count
    
    fileprivate var txSeq = 0                           // Tx sequence number
    fileprivate var txByteCount = 0                     // Tx byte count
    fileprivate var _txPacketSize = 240                  // Tx packet size (bytes)
    fileprivate var txBytesPerSec = 0                   // Tx rate
    
    // constants
    fileprivate let _opusQ: DispatchQueue               // Opus synchronization
    fileprivate let _log = Log.sharedInstance           // Shared Log
    fileprivate let kModule = "Opus"                    // Module Name reported in log messages
    fileprivate let kRemoteAudioCmd = "remote_audio "   // Remote Audio command prefix
    
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    //                                                                                              //
    fileprivate var __remoteRxOn = false                // Opus for receive                         //
    fileprivate var __remoteTxOn = false                // Opus for transmit                        //
    fileprivate var __rxStreamStopped = false           // Rx stream stopped                        //
                                                                                                    //
    fileprivate var _delegate: OpusStreamHandler?  {    // Delegate to receive Opus Data            //
        didSet { if _delegate == nil { _initialized = false ; rxSeq = nil } } }                     //
    //                                                                                              //
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    /// Initialize Opus
    ///
    /// - Parameters:
    ///   - radio:      the parent Radio class
    ///   - id:         an Opus Stream id
    ///   - queue:      Opus Serial queue
    ///
    init(radio: Radio, id: Radio.OpusId, queue: DispatchQueue) {
        
        self._radio = radio
        self._opusQ = queue
        self._id = id
        
        super.init()
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - Public methods
    
    private var _vita: Vita?
    /// Send Opus encoded TX audio to the Radio (hardware)
    ///
    /// - Parameters:
    ///   - buffer:     array of encoded audio samples
    ///   - samples:    number of samples to be sent
    /// - Returns:      success / failure
    ///
    public func sendOpusTxAudio(buffer: [UInt8], samples: Int) {
        
        if _vita == nil {
            // get a new Vita struct (w/defaults & IfDataWithStream, daxAudio, StreamId, tsi.other)
            _vita = Vita(packetType: .ifDataWithStream, classCode: .daxAudio, streamId: _id, tsi: .other)
        }
        // create new array for payload (interleaved L/R samples)
        let payload = [UInt8](repeating: 0, count: _txPacketSize)

        // get a raw pointer to the start of the payload
        _vita!.payload = UnsafeRawPointer(payload)
        
        // set the length of the packet
        _vita!.payloadSize = _txPacketSize                                      // 8-Bit encoded samples
        _vita!.packetSize = _vita!.payloadSize + MemoryLayout<VitaHeader>.size     // payload size + header size
        
        // set the sequence number
        _vita!.sequence = txSeq
        
        // encode vita packet to data and send to radio
        if let packet = _vita!.encode() {
            
            // send packet to radio
            _radio?.sendVitaData(packet)
        }
        // increment the sequence number (mod 16)
        txSeq = (txSeq + 1) % 16
    }

    // ------------------------------------------------------------------------------
    // MARK: - KeyValueParser Protocol methods
    //     called by Radio, executes on the parseQ
    //
    
    ///  Parse Opus key/value pairs
    ///
    /// - parameter keyValues: a KeyValuesArray
    ///
    public func parseKeyValues(_ keyValues: Radio.KeyValuesArray) {
        
        // process each key/value pair
        for kv in keyValues {
            
            // check for unknown Keys
            guard let token = Token(rawValue: kv.key.lowercased()) else {
                
                // unknown Key, log it and ignore the Key
                _log.msg("Unknown token - \(kv.key)", level: .debug, function: #function, file: #file, line: #line)
                continue
            }
            
            // get the Int and Bool versions of the value
            let iValue = kv.value.iValue()
            let bValue = kv.value.bValue()
            
            // known Keys, in alphabetical order
            switch token {
                
            case .ipAddress:
                willChangeValue(forKey: "ip")
                _ip = kv.value.trimmingCharacters(in: CharacterSet.whitespaces)
                didChangeValue(forKey: "ip")
            
            case .port:
                willChangeValue(forKey: "port")
                _port = iValue
                didChangeValue(forKey: "port")

            case .remoteRxOn:
                willChangeValue(forKey: "remoteRxOn")
                _remoteRxOn = bValue
                didChangeValue(forKey: "remoteRxOn")
                
            case .remoteTxOn:
                willChangeValue(forKey: "remoteTxOn")
                _remoteTxOn = bValue
                didChangeValue(forKey: "remoteTxOn")
                
            case .rxStreamStopped:
                willChangeValue(forKey: "rxStreamStopped")
                _rxStreamStopped = bValue
                didChangeValue(forKey: "rxStreamStopped")                
            }
        }
        // the Radio (hardware) has acknowledged this Opus
        if !_initialized && _ip != "" {
            
            // YES, the Radio (hardware) has acknowledged this Opus
            _initialized = true
            
            // notify all observers
            NC.post(.opusHasBeenAdded, object: self as Any?)
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - VitaHandler protocol methods
    
    //      called by Radio on the udpQ
    //
    //      The payload of the incoming Vita struct is converted to an OpusFrame and
    //      passed to the Opus Stream Handler

    ///  Process the Opus Vita struct
    ///
    /// - parameter vita:     an Opus Vita struct
    ///
    public func vitaHandler(_ vita: Vita) {
        
        // is this the first packet?
        if rxSeq == nil { rxSeq = vita.sequence }
        
        // is the received Sequence Number correct?
        if vita.sequence != rxSeq {
            
            // NO, log the issue
            _log.msg("Missing packet(s), rcvdSeq: \(vita.sequence) != expectedSeq: \(rxSeq!)", level: .warning, function: #function, file: #file, line: #line)
            
            if vita.sequence < rxSeq! {
                
                // less than expected, packet is old, ignore it
                rxSeq = nil
                rxLostPacketCount += 1
                return
                
            } else {
                
                // greater than expected, one or more packets were lost, resync & process it
                rxSeq = vita.sequence
                rxLostPacketCount += 1
            }
        }
        // calculate the next Sequence Number
        rxSeq = (rxSeq! + 1) % 16
        
        // Pass the data frame to the Opus delegate
        delegate?.opusStreamHandler( OpusFrame(payload: vita.payload!, numberOfSamples: vita.payloadSize) )
    }
}

// ------------------------------------------------------------------------------
// MARK: - OpusFrame struct implementation
// ------------------------------------------------------------------------------
//
//  Populated by the Opus vitaHandler
//

/// Struct containing Opus Stream data
///
public struct OpusFrame {
    
    public var samples: [UInt8]                     // array of samples
    public var numberOfSamples: Int                 // number of samples
    
    /*
    public var duration: Float                      // frame duration (ms)
    public var channels: Int                        // number of channels (1 or 2)
    */
    
    /// Initialize an OpusFrame
    ///
    /// - parameter payload:         pointer to the Vita packet payload
    /// - parameter numberOfSamples: number of Samples in the payload
    ///
    public init(payload: UnsafeRawPointer, numberOfSamples: Int) {
        
        // allocate the samples array
        samples = [UInt8](repeating: 0, count: numberOfSamples)
        
        // save the count and copy the data
        self.numberOfSamples = numberOfSamples
        memcpy(&samples, payload, numberOfSamples)
        
        /*
        // MARK: This code unneeded at this time
        
        // determine the frame duration
        let durationCode = (samples[0] & 0xF8)
        switch durationCode {
        case 0xC0:
            duration = 2.5
        case 0xC8:
            duration = 5.0
        case 0xD0:
            duration = 10.0                                 // Flex uses 10 ms
        case 0xD8:
            duration = 20.0
        default:
            duration = 0
        }
        // determine the number of channels (mono = 1, stereo = 2)
        channels = (samples[0] & 0x04) == 0x04 ? 2 : 1      // Flex uses stereo
        */
    }
}

// --------------------------------------------------------------------------------
// MARK: - Opus Class extensions
//              - Synchronized internal properties
//              - Dynamic public properties
//              - Opus message enum
// --------------------------------------------------------------------------------

extension Opus {
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties - with synchronization
    
    // listed in alphabetical order
    fileprivate var _remoteRxOn: Bool {
        get { return _opusQ.sync { __remoteRxOn } }
        set { _opusQ.sync(flags: .barrier) { __remoteRxOn = newValue } } }
    
    fileprivate var _remoteTxOn: Bool {
        get { return _opusQ.sync { __remoteTxOn } }
        set { _opusQ.sync(flags: .barrier) { __remoteTxOn = newValue } } }
    
//    fileprivate var _rxStreamId: String {
//        get { return _opusQ.sync { __rxStream } }
//        set { _opusQ.sync(flags: .barrier) { __rxStream = newValue } } }
    
    fileprivate var _rxStreamStopped: Bool {
        get { return _opusQ.sync { __rxStreamStopped } }
        set { _opusQ.sync(flags: .barrier) { __rxStreamStopped = newValue } } }
    
//    fileprivate var _txStreamId: String {
//        get { return _opusQ.sync { __txStream } }
//        set { _opusQ.sync(flags: .barrier) { __txStream = newValue } } }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant with Radio update

    // listed in alphabetical order
    @objc dynamic public var remoteRxOn: Bool {
        get { return _remoteRxOn }
        set { if _remoteRxOn != newValue { _remoteRxOn = newValue ; _radio!.send(kRemoteAudioCmd + "rx_on \(newValue.asNumber())") } } }
    
    @objc dynamic public var remoteTxOn: Bool {
        get { return _remoteTxOn }
        set { if _remoteTxOn != newValue { _remoteTxOn = newValue ; _radio!.send(kRemoteAudioCmd + "tx_on \(newValue.asNumber())") } } }
    
//    dynamic public var rxStreamId: String {
//        get { return _rxStreamId }
//        set { if _rxStreamId != newValue { _rxStreamId = newValue } } }
    
    @objc dynamic public var rxStreamStopped: Bool {
        get { return _rxStreamStopped }
        set { if _rxStreamStopped != newValue { _rxStreamStopped = newValue ; _radio!.send(kRemoteAudioCmd + "opus_rx_stream_stopped \(newValue.asNumber())") } } }
    
//    dynamic public var txStreamId: String {
//        get { return _txStreamId }
//        set { if _txStreamId != newValue { _txStreamId = newValue ; _radio!.send(kRemoteAudioCmd + "tx_stream \(newValue)") } } }
    
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - NON KVO compliant Setters / Getters with synchronization
    
    public var delegate: OpusStreamHandler? {
        get { return _opusQ.sync { _delegate } }
        set { _opusQ.sync(flags: .barrier) { _delegate = newValue } } }
    
    // ----------------------------------------------------------------------------
    // Mark: - Tokens for Opus messages (only populate values that != case value)
    
    internal enum Token : String {
        case ipAddress = "ip"
        case port
        case remoteRxOn = "rx_on"
        case remoteTxOn = "tx_on"
//        case rxStreamId = "rx_stream"
        case rxStreamStopped = "opus_rx_stream_stopped"
//        case txStreamId = "tx_stream"
    }
    
}

