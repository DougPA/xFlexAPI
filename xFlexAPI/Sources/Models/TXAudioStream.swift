//
//  TXAudioStream.swift
//  xFlexAPI
//
//  Created by Mario Illgen on 27.03.17.
//  Copyright © 2017 Douglas Adams & Mario Illgen. All rights reserved.
//

import Cocoa

// ------------------------------------------------------------------------------
// MARK: - TXAudioStream Class implementation
//
//      creates a udp stream of audio, from the Client to the Radio (hardware),
//      to be used by the Radio as transmit audio
//
// ------------------------------------------------------------------------------

final public class TXAudioStream: NSObject, KeyValueParser {
    
    // ------------------------------------------------------------------------------
    // MARK: - Public properties
    
    public private(set) var id: Radio.DaxStreamId = ""  // Stream Id
    
    // ------------------------------------------------------------------------------
    // MARK: - Private properties
    
    private var _radio: Radio?                      // The Radio that owns this TXAudioStream
    private var _txAudioStreamsQ: DispatchQueue     // GCD queue that guards TXAudioStreams
    private var _initialized = false                // True if initialized by Radio hardware
    private var _txSeq = 0                          // Tx sequence number (modulo 16)
    
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    //                                                                                              //
    private var __inUse = false                     // true = in use                                //
    private var __ip = ""                           // Ip Address                                   //
    private var __port = 0                          // Port number                                  //
    private var __transmit = false                  // dax transmitting                             //
    private var __txGain = 50                       // tx gain of stream                            //
    private var __txGainScalar: Float = 1.0         // scalar gain value for multiplying            //
    //                                                                                              //
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    
    // constants
    private let _log = Log.sharedInstance           // shared Log
        
    /// Initialize an TX Audio Stream
    ///
    /// - Parameters:
    ///   - radio:              the Radio instance
    ///   - queue:              MicAudioStreams concurrent Queue
    ///
    init(radio: Radio, id: Radio.DaxStreamId, queue: DispatchQueue) {
        
        self._radio = radio
        self.id = id
        self._txAudioStreamsQ = queue
        
        super.init()        
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - Public methods for sending tx audio to the Radio (hardware)
    
//    private var _vita: Vita?
//    public func sendTXAudio(left: [Float], right: [Float], samples: Int) -> Bool {
//        
//        // skip this if we are not the DAX TX Client
//        if !_transmit { return false }
//        
//        if _vita == nil {
//            // get a new Vita struct (w/defaults & IfDataWithStream, daxAudio, StreamId, tsi.other)
//            _vita = Vita(packetType: .ifDataWithStream, classCode: .daxAudio, streamId: _streamId, tsi: .other)
//        }
//        
//        var samplesSent = 0
//        
//        while samplesSent < samples {
//            
//            // how many samples should we send?
//            let numSamplesToSend = min(128, samples - samplesSent)
//            
//            // create new array for payload (interleaved L/R samples)
//            var payload = [Float](repeating: 0.0, count: samples * 2)
//            // scale with rx gain
//            let scale = self._txGainScalar
//            // TODO: use Accelerate
//            for i in 0..<samples {
//                payload[2 * i + 0] = left[i] * scale
//                payload[2 * i + 1] = left[i] * scale
//            }
//            
//            // now process payload
//            let payloadPtr = UnsafeMutableRawPointer(mutating: payload)
//            let payloadInWords = samples * 2
//            // get a pointer to the data in the payload
//            let wordsPtr = payloadPtr.bindMemory(to: UInt32.self, capacity: payloadInWords)
//            
//            // swap endianess of the samples
//            for i in 0..<payloadInWords {
//                wordsPtr.advanced(by: i).pointee = CFSwapInt32HostToBig(wordsPtr.advanced(by: i).pointee)
//            }
//            _vita?.payload = UnsafeMutableRawPointer(mutating: payload)
//            
//            // set the length of the packet
//            let payloadSize = numSamplesToSend * 2 * 4  // 32-Bit L/R samples
//            _vita?.payloadSize = payloadSize
//            _vita?.packetSize = payloadSize + MemoryLayout<VitaHeader>.size // payload size + header size
//            
//            _vita?.sequence = _txSeq
//            
//            // encode vita packet to data and send to radio
//            if let packet = _vita!.encode() {
//                
//                // send packet to radio
//                _radio?.sendVitaData(packet)
//            }
//
//            _txSeq = (_txSeq + 1) % 16
//            
//            // adjust the samples sent
//            samplesSent += numSamplesToSend
//        }
//        
//        return true
//    }
    
    private var _vita: Vita?
    public func sendTXAudio(left: [Float], right: [Float], samples: Int) -> Bool {
        
        // skip this if we are not the DAX TX Client
        if !_transmit { return false }
        
        if _vita == nil {
            // get a new Vita struct (w/defaults & IfDataWithStream, daxAudio, StreamId, tsi.other)
            _vita = Vita(packetType: .ifDataWithStream, classCode: .daxAudio, streamId: id, tsi: .other)
        }
        
        let kMaxSamplesToSend = 128     // maximum packet samples (per channel)
        let kNumberOfChannels = 2       // 2 channels
        
        // create new array for payload (interleaved L/R samples)
        var payload = [Float](repeating: 0.0, count: kMaxSamplesToSend * kNumberOfChannels)
        
        // get a raw pointer to the start of the payload
        let payloadPtr = UnsafeMutableRawPointer(mutating: payload)
        _vita!.payload = UnsafeRawPointer(payload)
        
        // get a pointer to 32-bit chunks in the payload
        let wordsPtr = payloadPtr.bindMemory(to: UInt32.self, capacity: kMaxSamplesToSend * kNumberOfChannels)
        
        var samplesSent = 0
        while samplesSent < samples {
            
            // how many samples this iteration? (kMaxSamplesToSend or remainder if < kMaxSamplesToSend)
            let numSamplesToSend = min(kMaxSamplesToSend, samples - samplesSent)
            let numFloatsToSend = numSamplesToSend * kNumberOfChannels
            
            // interleave the payload & scale with tx gain
            for i in 0..<numSamplesToSend {                                         // TODO: use Accelerate
                payload[(2 * i)] = left[i + samplesSent] * _txGainScalar
                payload[(2 * i) + 1] = right[i + samplesSent] * _txGainScalar
            }
            
            // swap endianess of the samples
            for i in 0..<numFloatsToSend {
                wordsPtr.advanced(by: i).pointee = CFSwapInt32HostToBig(wordsPtr.advanced(by: i).pointee)
            }
            
            // set the length of the packet
            _vita!.payloadSize = numFloatsToSend * MemoryLayout<UInt32>.size        // 32-Bit L/R samples
            _vita!.packetSize = _vita!.payloadSize + MemoryLayout<VitaHeader>.size     // payload size + header size
            
            // set the sequence number
            _vita!.sequence = _txSeq
            
            // encode vita packet to data and send to radio
            if let packet = _vita!.encode() {
                
                // send packet to radio
                _radio?.sendVitaData(packet)
            }
            // increment the sequence number (mod 16)
            _txSeq = (_txSeq + 1) % 16
            
            // adjust the samples sent
            samplesSent += numSamplesToSend
        }
        return true
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - KeyValueParser Protocol methods
    //     called by Radio, executes on the radioQ
    
    /// Parse TX Audio Stream key/value pairs
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
                
            case .daxTx:
                willChangeValue(forKey: "transmit")
                _transmit = bValue
                didChangeValue(forKey: "transmit")
                
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
            NC.post(.txAudioStreamHasBeenAdded, object: self as Any?)
        }
    }

}

// --------------------------------------------------------------------------------
// MARK: - MicAudioStream Class extensions
//              - Synchronized internal properties
//              - Dynamic public properties
//              - AudioStream message enum
// --------------------------------------------------------------------------------

extension TXAudioStream {
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties - with synchronization
    
    // listed in alphabetical order
    private var _inUse: Bool {
        get { return _txAudioStreamsQ.sync { __inUse } }
        set { _txAudioStreamsQ.sync(flags: .barrier) { __inUse = newValue } } }
    
    private var _ip: String {
        get { return _txAudioStreamsQ.sync { __ip } }
        set { _txAudioStreamsQ.sync(flags: .barrier) { __ip = newValue } } }
    
    private var _port: Int {
        get { return _txAudioStreamsQ.sync { __port } }
        set { _txAudioStreamsQ.sync(flags: .barrier) { __port = newValue } } }
    
    private var _transmit: Bool {
        get { return _txAudioStreamsQ.sync { __transmit } }
        set { _txAudioStreamsQ.sync(flags: .barrier) { __transmit = newValue } } }
    
    private var _txGain: Int {
        get { return _txAudioStreamsQ.sync { __txGain } }
        set { _txAudioStreamsQ.sync(flags: .barrier) { __txGain = newValue } } }
    
    private var _txGainScalar: Float {
        get { return _txAudioStreamsQ.sync { __txGainScalar } }
        set { _txAudioStreamsQ.sync(flags: .barrier) { __txGainScalar = newValue } } }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant with Radio update (where appropriate)
    
    // listed in alphabetical order
    @objc dynamic public var inUse: Bool {
        return _inUse }
    
    @objc dynamic public var ip: String {
        get { return _ip }
        set { if _ip != newValue { _ip = newValue } } }
    
    @objc dynamic public var port: Int {
        get { return _port  }
        set { if _port != newValue { _port = newValue } } }
    
    @objc dynamic public var transmit: Bool {
        get { return _transmit  }
        set {
            if _transmit != newValue {
                _transmit = newValue
                _radio?.send("dax tx \(_transmit.asNumber())")
            }
        }
    }
    
    @objc dynamic public var txGain: Int {
        get { return _txGain  }
        set {
            if _txGain != newValue {
                let value = newValue.bound(0, 100)
                if _txGain != value {
                    _txGain = value
                    if _txGain == 0 {
                        _txGainScalar = 0.0
                        return
                    }
                    let db_min:Float = -10.0;
                    let db_max:Float = +10.0;
                    let db:Float = db_min + (Float(_txGain) / 100.0) * (db_max - db_min);
                    _txGainScalar = pow(10.0, db / 20.0);
                }
            }
        }
    }
    
    // ----------------------------------------------------------------------------
    // Mark: - Tokens for TxAudioStream messages (only populate values that != case value)
    
    enum Token: String {
        case daxTx = "dax_tx"
        case inUse = "in_use"
        case ip
        case port
    }
}

