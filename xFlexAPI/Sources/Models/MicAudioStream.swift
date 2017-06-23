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

final public class MicAudioStream: NSObject, KeyValueParser, VitaHandler {

    
    public private(set) var id: Radio.DaxStreamId = ""  // The Mic Audio stream id
    public var rxLostPacketCount = 0                    // Rx lost packet count
    
    // ------------------------------------------------------------------------------
    // MARK: - Private properties
    
    
    private weak var _radio: Radio?                 // The Radio that owns this MicAudioStream
    private var _micAudioStreamsQ: DispatchQueue    // GCD queue that guards MicAudioStreams
    private var _initialized = false                // True if initialized by Radio hardware
    
    private var rxSeq: Int?                         // Rx sequence number
    
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    //                                                                                              //
    private var __inUse = false                     // true = in use                            //
    private var __ip = ""                           // Ip Address                               //
    private var __port = 0                          // Port number                              //
    private var __micGain = 50                      // rx gain of stream                        //
    private var __micGainScalar: Float = 1.0        // scalar gain value for multiplying        //
    //
    private var _delegate: MicAudioStreamHandler?   // Delegate for Audio stream                //
    //                                                                                              //
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ----//
    
    // constants
    private let _log = Log.sharedInstance           // shared Log
    private let kModule = "MicAudioStream"          // Module Name reported in log messages
    private let kNoError = "0"                      // response without error
    
    private let kMicStreamCreateCmd = "stream create daxmic"
    
    // see FlexLib
    private let kOneOverZeroDBfs: Float = 1.0 / pow(2, 15)  // FIXME: really 16-bit for 32-bit numbers???
    
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
    // MARK: - Public methods that send commands to the Radio (hardware)
    
//    public func requestMicAudioStream() -> Bool {
//
//        // check to see if this object has already been activated
//        if !_initialized { return false }
//
//        // check to ensure this object is tied to a radio object
//        if _radio == nil { return false }
//
//        // check to make sure the radio is connected
//        switch _radio!.connectionState {
//        case .clientConnected:
//            _radio!.send(kMicStreamCreateCmd, replyTo: updateStreamId)
//            return true
//        default:
//            return false
//        }
//    }
//    public func removeMicAudioStream() {
//
//        _radio?.send("stream remove 0x\(streamId)")
//        _radio?.removeAudioStream(streamId)
//    }
    
    // ------------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Process the Reply to a Stream Create command, reply format: <value>,<value>,...<value>
    ///
    /// - Parameters:
    ///   - seqNum:         the Sequence Number of the original command
    ///   - responseValue:  the response value
    ///   - reply:          the reply
    ///
//    private func updateStreamId(_ command: String, seqNum: String, responseValue: String, reply: String) {
//
//        guard responseValue == kNoError else {
//            // Anything other than 0 is an error, log it and ignore the Reply
//            _log.msg(command + ", non-zero reply - \(responseValue)", level: .error, function: #function, file: #file, line: #line)
//            return
//        }
//
//        //get the streamId (remove the "0x" prefix)
//        //_streamId = String(reply.characters.dropFirst(2))
//        // DL3LSM: there is no 0x prefix -> don't drop anything
//        // but make the string 8 characters long -> add "0" at the beginning
//        let fillCnt = 8 - reply.characters.count
//        let fills = (fillCnt > 0 ? String(repeatElement("0", count: fillCnt)) : "")
//        _streamId = fills + reply
//
//        // add the Audio Stream to the collection if not existing
//        if let _ = _radio?.micAudioStreams[_streamId] {
//            _log.msg(command + ", attempted to add MicAudioStream already in Radio micAudioStreams List", level: .warning, function: #function, file: #file, line: #line)
//            return // already in the list
//        }
//
//        _radio?.micAudioStreams[_streamId] = self
//    }
    
    // ------------------------------------------------------------------------------
    // MARK: - KeyValueParser Protocol methods
    //     called by Radio, executes on the parseQ
    
    /// Parse Mic Audio Stream key/value pairs
    ///
    /// - parameter keyValues:  a KeyValuesArray
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
    
    //      called by Radio on the udpQ
    //
    //      The payload of the incoming Vita struct is converted to a MicAudioStreamFrame and
    //      passed to the Mic Audio Stream Handler
    
    /// Process the Mic Audio Stream Vita struct
    ///
    /// - parameter vitaPacket: a Vita struct
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
    /// - parameter payload: pointer to a Vita packet payload
    /// - parameter numberOfWords: number of 32-bit Words in the payload
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
    private var _inUse: Bool {
        get { return _micAudioStreamsQ.sync { __inUse } }
        set { _micAudioStreamsQ.sync(flags: .barrier) { __inUse = newValue } } }
    
    private var _ip: String {
        get { return _micAudioStreamsQ.sync { __ip } }
        set { _micAudioStreamsQ.sync(flags: .barrier) { __ip = newValue } } }
    
    private var _port: Int {
        get { return _micAudioStreamsQ.sync { __port } }
        set { _micAudioStreamsQ.sync(flags: .barrier) { __port = newValue } } }
    
    private var _micGain: Int {
        get { return _micAudioStreamsQ.sync { __micGain } }
        set { _micAudioStreamsQ.sync(flags: .barrier) { __micGain = newValue } } }
    
    private var _micGainScalar: Float {
        get { return _micAudioStreamsQ.sync { __micGainScalar } }
        set { _micAudioStreamsQ.sync(flags: .barrier) { __micGainScalar = newValue } } }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant with Radio update
    
    // listed in alphabetical order
    @objc dynamic public var inUse: Bool {
        get { return _inUse }
        set { _inUse = newValue } }
    
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
    
    // ----------------------------------------------------------------------------
    // Mark: - Tokens for MicAudioStream messages (only populate values that != case value)
    
    enum Token: String {
        case inUse = "in_use"
        case ip
        case port
    }
}
