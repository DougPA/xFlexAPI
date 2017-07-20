//
//  MicAudioStream.swift
//  xFlexAPI
//
//  Created by Mario Illgen on 27.03.17.
//  Copyright © 2017 Douglas Adams & Mario Illgen. All rights reserved.
//

import Cocoa

public protocol MicAudioStreamHandler {
    
    // method to process audio data stream
    func micAudioStreamHandler(_ frame: MicAudioStreamFrame) -> Void
}

// ------------------------------------------------------------------------------
// MARK: - MicAudioStream Class implementation
//
//      creates a udp stream of audio, from the Radio (hardware) to the Client,
//      containing the Radio's transmit audio
//
// ------------------------------------------------------------------------------

public final class MicAudioStream: NSObject, KeyValueParser, VitaHandler {

    
    public private(set) var id: Radio.DaxStreamId = ""  // The Mic Audio stream id
    public var rxLostPacketCount = 0                    // Rx lost packet count
    
    // ------------------------------------------------------------------------------
    // MARK: - Private properties
    
    internal var _radio: Radio?                         // The Radio that owns this MicAudioStream
    fileprivate var _micAudioStreamsQ: DispatchQueue    // GCD queue that guards MicAudioStreams
    fileprivate var _initialized = false                // True if initialized by Radio hardware
    
    fileprivate var rxSeq: Int?                         // Rx sequence number
    
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    //                                                                                              //
    fileprivate var __inUse = false                     // true = in use                                //
    fileprivate var __ip = ""                           // Ip Address                                   //
    fileprivate var __port = 0                          // Port number                                  //
    fileprivate var __micGain = 50                      // rx gain of stream                            //
    fileprivate var __micGainScalar: Float = 1.0        // scalar gain value for multiplying            //
                                                                                                    //
    fileprivate var _delegate: MicAudioStreamHandler?   // Delegate for Audio stream                    //
    //                                                                                              //
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ----//
    
    // constants
    fileprivate let _log = Log.sharedInstance           // shared Log
    
//    fileprivate let kMicStreamCreateCmd = "stream create daxmic"
    
    // see FlexLib
    fileprivate let kOneOverZeroDBfs: Float = 1.0 / pow(2, 15)  // FIXME: really 16-bit for 32-bit numbers???
    
    /// Initialize an Mic Audio Stream
    ///
    /// - Parameters:
    ///   - radio:              the Radio instance
    ///   - queue:              MicAudioStreams concurrent Queue
    ///
    init(radio: Radio, id: Radio.DaxStreamId, queue: DispatchQueue) {
        
        self._radio = radio
        self.id = id
        self._micAudioStreamsQ = queue
        
        super.init()
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - KeyValueParser Protocol methods
    //     called by Radio, executes on the parseQ
    
    /// Parse Mic Audio Stream key/value pairs
    ///
    /// - Parameters:
    ///   - keyValues:  a KeyValuesArray
    ///
    func parseKeyValues(_ keyValues: Radio.KeyValuesArray) {
        
        // process each key/value pair, <key=value>
        for kv in keyValues {
            
            // check for unknown keys
            guard let token = MicAudioStreamToken(rawValue: kv.key.lowercased()) else {
                // unknown Key, log it and ignore the Key
                _log.msg("Unknown token - \(kv.key)", level: .debug, function: #function, file: #file, line: #line)
                continue
            }
            // get the Int and Bool versions of the value
            let iValue = (kv.value).iValue()
            let bValue = (kv.value).bValue()
            
            // known keys, in alphabetical order
            switch token {
                
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
                
            }
        }
        // is the AudioStream acknowledged by the radio?
        if !_initialized && _inUse && _ip != "" {
            
            // YES, the Radio (hardware) has acknowledged this Audio Stream
            _initialized = true
            
            // notify all observers
            NC.post(.micAudioStreamHasBeenAdded, object: self as Any?)
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - VitaHandler protocol methods
    
    //      called by Radio on the udpReceiveQ
    //
    //      The payload of the incoming Vita struct is converted to a MicAudioStreamFrame and
    //      passed to the Mic Audio Stream Handler
    
    /// Process the Mic Audio Stream Vita struct
    ///
    /// - Parameters:
    ///   - vitaPacket:         a Vita struct
    ///
    func vitaHandler(_ vita: Vita) {
        
        if vita.classCode != .daxAudio {
            // not for us
            return
        }
        
        // if there is a delegate, process the Mic Audio stream
        if let delegate = delegate {
            
            // initialize a data frame
            var dataFrame = MicAudioStreamFrame(payload: vita.payload!, numberOfBytes: vita.payloadSize)
            
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
            
            // scale with rx gain
            let scale = self._micGainScalar
            for i in 0..<dataFrame.samples {
                
                dataFrame.leftAudio[i] = dataFrame.leftAudio[i] * scale
                dataFrame.rightAudio[i] = dataFrame.rightAudio[i] * scale
            }
            
            // Pass the data frame to this AudioSream's delegate
            delegate.micAudioStreamHandler(dataFrame)
        }
        
        // calculate the next Sequence Number
        let expectedSequenceNumber = (rxSeq == nil ? vita.sequence : (rxSeq! + 1) % 16)
        
        // is the received Sequence Number correct?
        if vita.sequence != expectedSequenceNumber {
            
            // NO, log the issue
            _log.msg("Missing packet(s), rcvdSeq: \(vita.sequence) != expectedSeq: \(expectedSequenceNumber)", level: .warning, function: #function, file: #file, line: #line)
            
            rxSeq = nil
            rxLostPacketCount += 1
        } else {
            
            rxSeq = expectedSequenceNumber
        }
    }
}

// --------------------------------------------------------------------------------
// MARK: - MicAudioStreamFrame struct implementation
// --------------------------------------------------------------------------------
//
//  Populated by the Mic Audio Stream vitaHandler
//

/// Struct containing Mic Audio Stream data
///
public struct MicAudioStreamFrame {
    
    public private(set) var samples = 0                     /// number of samples (L/R) in this frame
    public var leftAudio = [Float]()                        /// Array of left audio samples
    public var rightAudio = [Float]()                       /// Array of right audio samples
    
    /// Initialize a AudioStreamFrame
    ///
    /// - Parameters:
    ///   - payload:        pointer to a Vita packet payload
    ///   - numberOfWords:  number of 32-bit Words in the payload
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
// MARK: - MicAudioStream Class extensions
//              - Synchronized internal properties
//              - Dynamic public properties
//              - AudioStream message enum
// --------------------------------------------------------------------------------

extension MicAudioStream {
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties - with synchronization
    
    // listed in alphabetical order
    fileprivate var _inUse: Bool {
        get { return _micAudioStreamsQ.sync { __inUse } }
        set { _micAudioStreamsQ.sync(flags: .barrier) { __inUse = newValue } } }
    
    fileprivate var _ip: String {
        get { return _micAudioStreamsQ.sync { __ip } }
        set { _micAudioStreamsQ.sync(flags: .barrier) { __ip = newValue } } }
    
    fileprivate var _port: Int {
        get { return _micAudioStreamsQ.sync { __port } }
        set { _micAudioStreamsQ.sync(flags: .barrier) { __port = newValue } } }
    
    fileprivate var _micGain: Int {
        get { return _micAudioStreamsQ.sync { __micGain } }
        set { _micAudioStreamsQ.sync(flags: .barrier) { __micGain = newValue } } }
    
    fileprivate var _micGainScalar: Float {
        get { return _micAudioStreamsQ.sync { __micGainScalar } }
        set { _micAudioStreamsQ.sync(flags: .barrier) { __micGainScalar = newValue } } }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (no message to Radio)
    
    // FIXME: Should any of these send a message to the Radio?
    //          If yes, implement it, if not should they be "get" only?
    
    // listed in alphabetical order
    @objc dynamic public var inUse: Bool {
        return _inUse }
    
    @objc dynamic public var ip: String {
        get { return _ip }
        set { if _ip != newValue { _ip = newValue } } }
    
    @objc dynamic public var port: Int {
        get { return _port  }
        set { if _port != newValue { _port = newValue } } }
    
    @objc dynamic public var micGain: Int {
        get { return _micGain  }
        set {
            if _micGain != newValue {
                let value = newValue.bound(0, 100)
                if _micGain != value {
                    _micGain = value
                    if _micGain == 0 {
                        _micGainScalar = 0.0
                        return
                    }
                    let db_min:Float = -10.0;
                    let db_max:Float = +10.0;
                    let db:Float = db_min + (Float(_micGain) / 100.0) * (db_max - db_min);
                    _micGainScalar = pow(10.0, db / 20.0);
                }
            }
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - NON KVO compliant Setters / Getters with synchronization
    // DL3LSM
    
    public var delegate: MicAudioStreamHandler? {
        get { return _micAudioStreamsQ.sync { _delegate } }
        set { _micAudioStreamsQ.sync(flags: .barrier) { _delegate = newValue } } }
}
