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
// ------------------------------------------------------------------------------

final public class TXAudioStream: NSObject, KeyValueParser {

    // ------------------------------------------------------------------------------
    // MARK: - Internal properties
    
    fileprivate weak var _radio: Radio?                 // The Radio that owns this TXAudioStream
    fileprivate var _txAudioStreamsQ: DispatchQueue       // GCD queue that guards TXAudioStreams
    fileprivate var _shouldBeRemoved = false            // True if being removed
    
    fileprivate var txSeq = 0                         // Tx sequence number (modulo 16)
    
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    //                                                                                              //
    fileprivate var __inUse = false                     // true = in use                            //
    fileprivate var __ip = ""                           // Ip Address                               //
    fileprivate var __port = 0                          // Port number                              //
    fileprivate var __radioAck = false                  // has the radio acknowledged this stream   //
    fileprivate var __transmit = false                  // dax transmitting                         //
    fileprivate var __txGain = 50                       // tx gain of stream                        //
    fileprivate var __txGainScalar: Float = 1.0         // scalar gain value for multiplying        //
    fileprivate var __streamId: Radio.DaxStreamId = ""  // Stream Id                                //
    //                                                                                              //
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    
    // constants
    fileprivate let _log = Log.sharedInstance           // shared Log
    fileprivate let kModule = "TXAudioStream"             // Module Name reported in log messages
    fileprivate let kNoError = "0"                      // response without error
    
    fileprivate let kTXStreamCreateCmd = "stream create daxtx"
    
    // see FlexLib
    fileprivate let kOneOverZeroDBfs: Float = 1.0 / pow(2, 15)  // FIXME: really 16-bit for 32-bit numbers???
    
    /// Initialize an TX Audio Stream
    ///
    /// - Parameters:
    ///   - radio:              the Radio instance
    ///   - queue:              MicAudioStreams concurrent Queue
    ///
    init(radio: Radio, queue: DispatchQueue) {
        
        self._radio = radio
        self._txAudioStreamsQ = queue
        
        super.init()        
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - Public methods that send commands to the Radio (hardware)
    
    public func requestTXAudioStream() -> Bool {
        
        // check to see if this object has already been activated
        if _radioAck { return false }
        
        // check to ensure this object is tied to a radio object
        if _radio == nil { return false }
        
        // check to make sure the radio is connected
        switch _radio!.connectionState {
        case .clientConnected:
            _radio!.send(kTXStreamCreateCmd, replyTo: updateStreamId)
            return true
        default:
            return false
        }
    }
    public func removeTXAudioStream() {
        
        _radio?.send("stream remove 0x\(streamId)")
        _radio?.removeTXAudioStream(streamId)
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - Public methods for sending tx audio to the Radio (hardware)
    
    private var _vita: Vita?
    public func sendTXAudio(left: [Float], right: [Float], samples: Int) -> Bool {
        
        // skip this if we are not the DAX TX Client
        if !_transmit { return false }
        
        if _vita == nil {
            // get a new Vita struct (w/defaults & IfDataWithStream / daxAudio)
            _vita = Vita(packetType: .ifDataWithStream, classCode: .daxAudio, streamId: _streamId)
        }
        
        var samplesSent = 0
        
        while samplesSent < samples {
            
            // how many samples should we send?
            let numSamplesToSend = min(128, samples - samplesSent)
            
            // create new array for payload (interleaved L/R samples)
            var payload = [Float](repeating: 0.0, count: samples * 2)
            // scale with rx gain
            let scale = self._txGainScalar
            // TODO: use Accelerate
            for i in 0..<samples {
                payload[2 * i + 0] = left[i] * scale
                payload[2 * i + 1] = left[i] * scale
            }
            
            _vita?.payload = UnsafeMutableRawPointer(mutating: payload)
            
            // set the length of the packet
            let payloadSize = numSamplesToSend * 2 * 4  // 32-Bit L/R samples
            _vita?.payloadSize = payloadSize
//            let headerSize = 28 // 7*4=28 bytes of Vita overhead
//            _vita?.headerSize = headerSize
            _vita?.packetSize = payloadSize + MemoryLayout<VitaHeader>.size // payload size + header size
            
            _vita?.sequence = txSeq
            
            // encode vita packet to data and send to radio
            if let packet = _vita!.encode() {
                
                // send packet to radio
                _radio?.sendVitaData(packet)
            }

            txSeq = (txSeq + 1) % 16
            
            // adjust the samples sent
            samplesSent += numSamplesToSend
        }
        
        return true
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Process the Reply to a Stream Create command, reply format: <value>,<value>,...<value>
    ///
    /// - Parameters:
    ///   - seqNum:         the Sequence Number of the original command
    ///   - responseValue:  the response value
    ///   - reply:          the reply
    ///
    private func updateStreamId(_ command: String, seqNum: String, responseValue: String, reply: String) {
        
        guard responseValue == kNoError else {
            // Anything other than 0 is an error, log it and ignore the Reply
            _log.message(#function + " - \(responseValue)", level: .error, source: kModule)
            return
        }
        
        //get the streamId (remove the "0x" prefix)
        //_streamId = String(reply.characters.dropFirst(2))
        // DL3LSM: there is no 0x prefix -> don't drop anything
        // but make the string 8 characters long -> add "0" at the beginning
        let fillCnt = 8 - reply.characters.count
        let fills = (fillCnt > 0 ? String(repeatElement("0", count: fillCnt)) : "")
        _streamId = fills + reply
        
        // add the Audio Stream to the collection if not existing
        if let _ = _radio?.txAudioStreams[_streamId] {
            _log.message(#function + " - Attempted to Add TXAudioStream already in Radio txAudioStreams List",
                       level: .warning, source: kModule)
            return // already in the list
        }
        
        _radio?.txAudioStreams[_streamId] = self
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - KeyValueParser Protocol methods
    //     called by Radio, executes on the radioQ
    
    /// Parse TX Audio Stream key/value pairs
    ///
    /// - parameter keyValues: a KeyValuesArray
    ///
    public func parseKeyValues(_ keyValues: Radio.KeyValuesArray) {
        
        var setRadioAck = false
        
        // process each key/value pair, <key=value>
        for kv in keyValues {
            
            // check for unknown keys
            guard let token = Token(rawValue: kv.key.lowercased()) else {
                // unknown Key, log it and ignore the Key
                _log.message(" - \(kv.key)", level: .debug, source: kModule)
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
                
                if !_radioAck {
                    setRadioAck = true
                }
                
            case .port:
                willChangeValue(forKey: "port")
                _port = iValue
                didChangeValue(forKey: "port")
                
            }
        }
        // if this is an initialized AudioStream and inUse becomes false
        if _radioAck && _shouldBeRemoved == false && _inUse == false {
            
            // mark it for removal
            _shouldBeRemoved = true
            
            _radio?.removeTXAudioStream(self.streamId)
        }
        
        // is the AudioStream acknowledged by the radio?
        if setRadioAck {
            
            // YES, the Radio (hardware) has acknowledged this Audio Stream
            radioAck = true
            
            // notify all observers
            NC.post(.txAudioStreamInitialized, object: self as Any?)
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
    fileprivate var _inUse: Bool {
        get { return _txAudioStreamsQ.sync { __inUse } }
        set { _txAudioStreamsQ.sync(flags: .barrier) { __inUse = newValue } } }
    
    fileprivate var _ip: String {
        get { return _txAudioStreamsQ.sync { __ip } }
        set { _txAudioStreamsQ.sync(flags: .barrier) { __ip = newValue } } }
    
    fileprivate var _port: Int {
        get { return _txAudioStreamsQ.sync { __port } }
        set { _txAudioStreamsQ.sync(flags: .barrier) { __port = newValue } } }
    
    fileprivate var _radioAck: Bool {
        get { return _txAudioStreamsQ.sync { __radioAck } }
        set { _txAudioStreamsQ.sync(flags: .barrier) { __radioAck = newValue } } }
    
    fileprivate var _transmit: Bool {
        get { return _txAudioStreamsQ.sync { __transmit } }
        set { _txAudioStreamsQ.sync(flags: .barrier) { __transmit = newValue } } }
    
    fileprivate var _txGain: Int {
        get { return _txAudioStreamsQ.sync { __txGain } }
        set { _txAudioStreamsQ.sync(flags: .barrier) { __txGain = newValue } } }
    
    fileprivate var _txGainScalar: Float {
        get { return _txAudioStreamsQ.sync { __txGainScalar } }
        set { _txAudioStreamsQ.sync(flags: .barrier) { __txGainScalar = newValue } } }
    
    fileprivate var _streamId: String {
        get { return _txAudioStreamsQ.sync { __streamId } }
        set { _txAudioStreamsQ.sync(flags: .barrier) { __streamId = newValue } } }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant with Radio update
    
    // listed in alphabetical order
    dynamic public var inUse: Bool {
        get { return _inUse }
        set { _inUse = newValue } }
    
    dynamic public var ip: String {
        get { return _ip }
        set { if _ip != newValue { _ip = newValue } } }
    
    dynamic public var port: Int {
        get { return _port  }
        set { if _port != newValue { _port = newValue } } }
    
    dynamic public var radioAck: Bool {
        get { return _radioAck }
        set { _radioAck = newValue } }
    
    dynamic public var transmit: Bool {
        get { return _transmit  }
        set {
            if _transmit != newValue {
                _transmit = newValue
                _radio?.send("dax tx \(_transmit.asNumber())")
            }
        }
    }
    
    dynamic public var txGain: Int {
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
    
    dynamic public var streamId: String {
        get { return _streamId }
        set { if _streamId != newValue { _streamId = newValue } } }
    
    // ----------------------------------------------------------------------------
    // Mark: - Tokens for MicAudioStream messages (only populate values that != case value)
    
    enum Token: String {
        case daxTx = "dax_tx"
        case inUse = "in_use"
        case ip
        case port
    }
}

