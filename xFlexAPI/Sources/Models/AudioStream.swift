//
//  AudioStream.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 2/24/17.
//  Copyright © 2017 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Protocols

public protocol AudioStreamHandler {
    
    // method to process audio data stream
    func audioStreamHandler(_ frame: AudioStreamFrame) -> Void
}

// ------------------------------------------------------------------------------
// MARK: - AudioStream Class implementation
//
//      creates a udp stream of audio, from a Slice in the Radio (hardware) to
//      the Client, to be used by the client for various purposes (e.g. CW Skimmer,
//      digital modes, etc.)
//
// ------------------------------------------------------------------------------

final public class AudioStream: NSObject {
    
    // ------------------------------------------------------------------------------
    // MARK: - Public properties
    
    public private(set) var rxLostPacketCount = 0       // Rx lost packet count
    public private(set) var id: Radio.DaxStreamId = ""  // The Audio stream id
    
    // ------------------------------------------------------------------------------
    // MARK: - fileprivate properties
    
    fileprivate var _initialized = false                // True if initialized by Radio hardware
    fileprivate var _radio: Radio?                      // The Radio that owns this Audio stream
    fileprivate var _audioStreamsQ: DispatchQueue!      // GCD queue that guards Audio Streams
    fileprivate var _rxSeq: Int?                        // Rx sequence number

    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    //                                                                                              //
    fileprivate var __daxChannel = 0                    // Channel in use (1 - 8)                       //
    fileprivate var __daxClients = 0                    // Number of clients                            //
    fileprivate var __inUse = false                     // true = in use                                //
    fileprivate var __ip = ""                           // Ip Address                                   //
    fileprivate var __port = 0                          // Port number                                  //
    fileprivate var __rxGain = 50                       // rx gain of stream                            //
    fileprivate var __slice: xFlexAPI.Slice?            // Source Slice                                 //
    //                                                                                              //
    fileprivate var _delegate: AudioStreamHandler?      // Delegate for Audio stream                    //
    //                                                                                              //
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------

    // constants
    fileprivate let _log = Log.sharedInstance           // shared Log
    
    // see FlexLib C# code
    fileprivate let kOneOverZeroDBfs: Float = 1.0 / pow(2, 15)  // FIXME: really 16-bit for 32-bit numbers???
    
    // ------------------------------------------------------------------------------
    // MARK: - Initialization
    
    /// Initialize an Audio Stream
    ///
    /// - Parameters:
    ///   - radio:              the Radio instance
    ///   - id:                 the Stream Id
    ///   - queue:              AudioStreams concurrent Queue
    ///
    init(radio: Radio, id: Radio.DaxStreamId, queue: DispatchQueue) {
        
        self._radio = radio
        self.id = id
        self._audioStreamsQ = queue
        
        super.init()
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - KeyValueParser Protocol methods
    //     called by Radio, executes on the radioQ
    
    /// Parse Audio Stream key/value pairs
    ///
    /// - parameter keyValues: a KeyValuesArray
    ///
    public func parseKeyValues(_ keyValues: Radio.KeyValuesArray) {
        
        // process each key/value pair, <key=value>
        for kv in keyValues {
            
            // check for unknown keys
            guard let token = Token(rawValue: kv.key.lowercased()) else {
                // unknown Key, log it and ignore the Key
                _log.msg("Unknown token - \(kv.key)", level: .debug, function: #function, file: #file, line: #line)
                continue
            }
            // get the Int and Bool versions of the value
            let iValue = (kv.value).iValue()
            let bValue = (kv.value).bValue()
            
            // known keys, in alphabetical order
            switch token {
                
            case .daxChannel:
                willChangeValue(forKey: "daxChannel")
                _daxChannel = iValue
                didChangeValue(forKey: "daxChannel")
                
            case .daxClients:
                willChangeValue(forKey: "daxClients")
                _daxClients = iValue
                didChangeValue(forKey: "daxClients")
                
            case .inUse:
                willChangeValue(forKey: "inUse")
                _inUse = bValue
                didChangeValue(forKey: "inUse")
                
            case .ip:
                willChangeValue(forKey: "ip")
                _ip = kv.value
                didChangeValue(forKey: "ip")
                
            case .port:
                willChangeValue(forKey: "port")
                _port = iValue
                didChangeValue(forKey: "port")
                
            case .slice:
                willChangeValue(forKey: "slice")
                _slice = _radio?.slices[kv.value]
                didChangeValue(forKey: "slice")
                // DL3LSM resend rxGain value
                let gain = _rxGain;
                _rxGain = 0;
                rxGain = gain;
            }
        }
        // if this is not yet initialized and inUse becomes true
        if !_initialized && _inUse && _ip != "" {
            
            // YES, the Radio (hardware) has acknowledged this Audio Stream
            _initialized = true
            
            // notify all observers
            NC.post(.audioStreamHasBeenAdded, object: self as Any?)
        }
    }

    // ----------------------------------------------------------------------------
    // MARK: - VitaHandler Protocol method
    
    //      called by Radio on the udpReceiveQ
    //
    //      The payload of the incoming Vita struct is converted to an AudioStreamFrame and
    //      passed to the Audio Stream Handler
    
    /// Process the AudioStream Vita struct
    ///
    /// - parameter vita:   a Vita struct
    ///
    func vitaHandler(_ vita: Vita) {
        
        if vita.classCode != .daxAudio {
            // not for us
            return
        }
        
        // if there is a delegate, process the Panadapter stream
        if let delegate = delegate {
            
            // initialize a data frame
            var dataFrame = AudioStreamFrame(payload: vita.payload!, numberOfBytes: vita.payloadSize)
            
            dataFrame.daxChannel = self.daxChannel
            
            // get a pointer to the data in the payload
            guard let wordsPtr = vita.payload?.bindMemory(to: UInt32.self, capacity: dataFrame.samples * 2) else {
                return
            }
            
            // allocate temporary data arrays
            var dataLeft = [UInt32](repeating: 0, count: dataFrame.samples)
            var dataRight = [UInt32](repeating: 0, count: dataFrame.samples)
            
            // swap endianess on the bytes
            // for each sample if we are dealing with DAX audio
            
            // Swap the byte ordering of the samples & place it in the dataFrame left and right samples
            for i in 0..<dataFrame.samples {
                
                dataLeft[i] = CFSwapInt32BigToHost(wordsPtr.advanced(by: 2*i+0).pointee)
                dataRight[i] = CFSwapInt32BigToHost(wordsPtr.advanced(by: 2*i+1).pointee)
            }
            
            if (Int(vita.classCode.rawValue) & 0x200) == 0 {
                // FIXME: should not be necessary
                // convert the payload data from 2s complement to float
                // for each sample...
                for i in 0..<dataFrame.samples {
                    
                    dataFrame.leftAudio[i] = Float(dataLeft[i]) * kOneOverZeroDBfs
                    dataFrame.rightAudio[i] = Float(dataRight[i]) * kOneOverZeroDBfs
                }
            } else {
                
                // copy the data as is -- it is already floating point
                memcpy(&(dataFrame.leftAudio), &dataLeft, dataFrame.samples * 4)
                memcpy(&(dataFrame.rightAudio), &dataRight, dataFrame.samples * 4)
            }
            
            // Pass the data frame to this AudioSream's delegate
            delegate.audioStreamHandler(dataFrame)
        }
        
        // calculate the next Sequence Number
        let expectedSequenceNumber = (_rxSeq == nil ? vita.sequence : (_rxSeq! + 1) % 16)
        
        // is the received Sequence Number correct?
        if vita.sequence != expectedSequenceNumber {
            
            // NO, log the issue
            _log.msg("Missing packet(s), rcvdSeq: \(vita.sequence) != expectedSeq: \(expectedSequenceNumber)", level: .warning, function: #function, file: #file, line: #line)
            
            _rxSeq = nil
            rxLostPacketCount += 1
        } else {
            
            _rxSeq = expectedSequenceNumber
        }
    }
}

// --------------------------------------------------------------------------------
// MARK: - AudioStreamFrame struct implementation
// --------------------------------------------------------------------------------
//
//  Populated by the Audio Stream vitaHandler
//

/// Struct containing Audio Stream data
///
public struct AudioStreamFrame {
    
    public var daxChannel = -1
    public private(set) var samples = 0                     /// number of samples (L/R) in this frame
    public var leftAudio = [Float]()                        /// Array of left audio samples
    public var rightAudio = [Float]()                       /// Array of right audio samples
    
    /// Initialize an AudioStreamFrame
    ///
    /// - Parameters:
    ///   - payload:        pointer to a Vita packet payload
    ///   - numberOfBytes:  number of bytes in the payload
    ///
    public init(payload: UnsafeRawPointer, numberOfBytes: Int) {
        
        // 4 byte each for left and right sample (4 * 2)
        self.samples = numberOfBytes / (4 * 2)
        
        // allocate the samples arrays
        self.leftAudio = [Float](repeating: 0, count: samples)
        self.rightAudio = [Float](repeating: 0, count: samples)
    }
}

// --------------------------------------------------------------------------------
// MARK: - AudioStream Class extensions
//              - Synchronized internal properties
//              - Dynamic public properties
//              - AudioStream message enum
// --------------------------------------------------------------------------------

extension AudioStream {
    
    // ----------------------------------------------------------------------------
    // MARK: - fileprivate properties - with synchronization
    
    // listed in alphabetical order
    fileprivate var _daxChannel: Int {
        get { return _audioStreamsQ.sync { __daxChannel } }
        set { _audioStreamsQ.sync(flags: .barrier) { __daxChannel = newValue } } }
    
    fileprivate var _daxClients: Int {
        get { return _audioStreamsQ.sync { __daxClients } }
        set { _audioStreamsQ.sync(flags: .barrier) { __daxClients = newValue } } }
    
    fileprivate var _inUse: Bool {
        get { return _audioStreamsQ.sync { __inUse } }
        set { _audioStreamsQ.sync(flags: .barrier) { __inUse = newValue } } }
    
    fileprivate var _ip: String {
        get { return _audioStreamsQ.sync { __ip } }
        set { _audioStreamsQ.sync(flags: .barrier) { __ip = newValue } } }
    
    fileprivate var _port: Int {
        get { return _audioStreamsQ.sync { __port } }
        set { _audioStreamsQ.sync(flags: .barrier) { __port = newValue } } }
    
    fileprivate var _rxGain: Int {
        get { return _audioStreamsQ.sync { __rxGain } }
        set { _audioStreamsQ.sync(flags: .barrier) { __rxGain = newValue } } }
    
    fileprivate var _slice: xFlexAPI.Slice? {
        get { return _audioStreamsQ.sync { __slice } }
        set { _audioStreamsQ.sync(flags: .barrier) { __slice = newValue } } }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant with Radio update
    
    // listed in alphabetical order
    @objc dynamic public var daxChannel: Int {        // DL3LSM
        get { return _daxChannel }
        set {
            if _daxChannel != newValue {
                _daxChannel = newValue
                if _radio != nil {
                    slice = _radio!.findSliceBy(daxChannel: _daxChannel)
                }
            }
        }
    }
    
    @objc dynamic public var daxClients: Int {
        get { return _daxClients  }
        set { if _daxClients != newValue { _daxClients = newValue } } }
    
    @objc dynamic public var inUse: Bool {
        get { return _inUse }
        set { _inUse = newValue } }
    
    @objc dynamic public var ip: String {
        get { return _ip }
        set { if _ip != newValue { _ip = newValue } } }
    
    @objc dynamic public var port: Int {
        get { return _port  }
        set { if _port != newValue { _port = newValue } } }

    @objc dynamic public var rxGain: Int {
        get { return _rxGain  }
        set {
            if _rxGain != newValue {
                let value = newValue.bound(0, 100)
                if _rxGain != value {
                    _rxGain = value
                    if _slice != nil {          // DL3LSM
                        _radio?.send("audio stream 0x" + id + " slice " + _slice!.id + " gain \(value)")
                    }
                }
            }
        }
    }
    @objc dynamic public var slice: xFlexAPI.Slice? {
        get { return _slice }
        set {
            if _slice != newValue {
                _slice = newValue
                // resend the RX Gain for the new slice - removed DL3LSM
            }
        }
    }

    // ----------------------------------------------------------------------------
    // MARK: - Public properties - NON KVO compliant Setters / Getters with synchronization
    
    public var delegate: AudioStreamHandler? {
        get { return _audioStreamsQ.sync { _delegate } }
        set { _audioStreamsQ.sync(flags: .barrier) { _delegate = newValue } } }
        
    // ----------------------------------------------------------------------------
    // Mark: - Tokens for AudioStream messages (only populate values that != case value)
    
    enum Token: String {
        case daxChannel = "dax"
        case daxClients = "dax_clients"
        case inUse = "in_use"
        case ip
        case port
        case slice
    }
}
