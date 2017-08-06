//
//  IqStream.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 3/9/17.
//  Copyright © 2017 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation
import Accelerate

// --------------------------------------------------------------------------------
// MARK: - Protocols

public protocol IqStreamHandler: class {
    
    // method to process audio data stream
    func iqStreamHandler(_ frame: IqStreamFrame) -> Void
}

// ------------------------------------------------------------------------------
// MARK: - IqStream Class implementation
//
//      creates a udp stream of I / Q data, from a Panadapter in the Radio (hardware) to
//      to the Client, to be used by the client for various purposes (e.g. CW Skimmer,
//      digital modes, etc.)
//
// ------------------------------------------------------------------------------

public final class IqStream: NSObject {
    
    // ------------------------------------------------------------------------------
    // MARK: - Public properties
    
    public private(set) var id: Radio.DaxStreamId = ""                     // Stream Id
    public private(set) var rxLostPacketCount = 0       // Rx lost packet count
    
    // ------------------------------------------------------------------------------
    // MARK: - Internal properties
    
    internal var _radio: Radio?                         // The Radio that owns this IqStream
    internal let kIqStreamCmd = "dax iq "
    
    // ------------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _iqStreamsQ: DispatchQueue          // GCD queue that guards IqStreams
    fileprivate var _initialized = false                // True if initialized by Radio hardware
    fileprivate var _shouldBeRemoved = false            // True if being removed
    fileprivate var _rxSeq: Int?                        // Rx sequence number
    fileprivate let _log = Log.sharedInstance           // shared Log
    // see FlexLib
    fileprivate var _kOneOverZeroDBfs: Float = 1.0 / pow(2.0, 15.0)
    
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ----------- //
    //                                                                                                      //
    fileprivate var __available = 0                         // Number of available IQ Streams               //
    fileprivate var __capacity = 0                          // Total Number of  IQ Streams                  //
    fileprivate var __daxIqChannel: Radio.DaxIqChannel = 0  // Channel in use (1 - 4)                       //
    fileprivate var __inUse = false                         // true = in use                                //
    fileprivate var __ip = ""                               // Ip Address                                   //
    fileprivate var __pan: xFlexAPI.Radio.PanadapterId?     // Source Panadapter                            //
    fileprivate var __port = 0                              // Port number                                  //
    fileprivate var __rate = 0                              // Stream rate                                  //
    fileprivate var __streaming = false                     // Stream state                                 //
    //                                                                                                      //
    fileprivate weak var _delegate: IqStreamHandler?        // Delegate for IQ stream                       //
    //                                                                                                      //
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ----------- //
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    /// Initialize an IQ Stream
    ///
    /// - Parameters:
    ///   - radio:              the Radio instance
    ///   - id:                 the Stream Id
    ///   - queue:              IqStreams concurrent Queue
    ///
    init(radio: Radio, id: Radio.DaxStreamId, queue: DispatchQueue) {
        
        self._radio = radio
        self.id = id
        self._iqStreamsQ = queue
        
        super.init()
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - KeyValueParser Protocol methods
    //     called by Radio, executes on the radioQ
    
    /// Parse IQ Stream key/value pairs
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///
    func parseKeyValues(_ keyValues: Radio.KeyValuesArray) {
        
        // process each key/value pair, <key=value>
        for kv in keyValues {
            
            guard let token = IqStreamToken(rawValue: kv.key.lowercased()) else {
                // unknown Key, log it and ignore the Key
                _log.msg("Unknown token - \(kv.key)", level: .debug, function: #function, file: #file, line: #line)
                continue
            }
            // get the Int and Bool versions of the value
            let iValue = (kv.value).iValue()
            let bValue = (kv.value).bValue()
            
            // known keys, in alphabetical order
            switch token {
                
            case .available:
                willChangeValue(forKey: "available")
                _available = iValue
                didChangeValue(forKey: "available")
                
            case .capacity:
                willChangeValue(forKey: "capacity")
                _capacity = iValue
                didChangeValue(forKey: "capacity")
                
            case .daxIqChannel:
                willChangeValue(forKey: "daxIqChannel")
                _daxIqChannel = iValue
                didChangeValue(forKey: "daxIqChannel")
                // FIXME: needed??
                //                if let panadapter = _radio?.findPanadapterBy(daxIqChannel: _daxIqChannel) {
                //                    willChangeValue(forKey: "pan")
                //                    _pan = panadapter.id
                //                    didChangeValue(forKey: "pan")
                //                }
                
            case .inUse:
                willChangeValue(forKey: "inUse")
                _inUse = bValue
                didChangeValue(forKey: "inUse")
                
            case .ip:
                willChangeValue(forKey: "ip")
                _ip = kv.value
                didChangeValue(forKey: "ip")
                
            case .pan:
                willChangeValue(forKey: "pan")
                _pan = String(kv.value.characters.dropFirst(2))
                didChangeValue(forKey: "pan")
                
            case .port:
                willChangeValue(forKey: "port")
                _port = iValue
                didChangeValue(forKey: "port")
                
            case .rate:
                willChangeValue(forKey: "rate")
                _rate = iValue
                didChangeValue(forKey: "rate")
                
            case .streaming:
                willChangeValue(forKey: "streaming")
                _streaming = bValue
                didChangeValue(forKey: "streaming")
            }
        }
        // is the Stream initialized?
        if !_initialized && /*_inUse &&*/ _ip != "" {   // in_use is not send at the beginning
            
            // YES, the Radio (hardware) has acknowledged this Stream
            _initialized = true
            
            // notify all observers
            NC.post(.iqStreamHasBeenAdded, object: self as Any?)
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - VitaHandler Protocol method
    
    //      called by Radio on the udpReceiveQ
    //
    //      The payload of the incoming Vita struct is converted to an IqStreamFrame and
    //      passed to the IQ Stream Handler
    
    /// Process the IqStream Vita struct
    ///
    /// - Parameters:
    ///   - vita:       a Vita struct
    ///
    func vitaHandler(_ vita: Vita) {
        
        if vita.classCode != .daxIq24 && vita.classCode != .daxIq48 && vita.classCode != .daxIq96 && vita.classCode != .daxIq192 {
            // not for us
            return
        }
        
        // if there is a delegate, process the Panadapter stream
        if let delegate = delegate {
            
            // initialize a data frame
            var dataFrame = IqStreamFrame(payload: vita.payload!, numberOfBytes: vita.payloadSize)
            
            dataFrame.daxIqChannel = self.daxIqChannel
            
            // get a pointer to the data in the payload
            guard let wordsPtr = vita.payload?.bindMemory(to: UInt32.self, capacity: dataFrame.samples * 2) else {
                return
            }
            
            // allocate temporary data arrays
            var dataLeft = [UInt32](repeating: 0, count: dataFrame.samples)
            var dataRight = [UInt32](repeating: 0, count: dataFrame.samples)
            
            // FIXME: is there a better way
            for i in 0..<dataFrame.samples {
                
                dataLeft[i] = wordsPtr.advanced(by: 2*i+0).pointee
                dataRight[i] = wordsPtr.advanced(by: 2*i+1).pointee
            }
            
            // copy the data as is -- it is already floating point
            memcpy(&(dataFrame.realSamples), &dataLeft, dataFrame.samples * 4)
            memcpy(&(dataFrame.imagSamples), &dataRight, dataFrame.samples * 4)
            
            // normalize data
            vDSP_vsmul(&(dataFrame.realSamples), 1, &_kOneOverZeroDBfs, &(dataFrame.realSamples), 1, vDSP_Length(dataFrame.samples))
            vDSP_vsmul(&(dataFrame.imagSamples), 1, &_kOneOverZeroDBfs, &(dataFrame.imagSamples), 1, vDSP_Length(dataFrame.samples))
            
            // Pass the data frame to this AudioSream's delegate
            delegate.iqStreamHandler(dataFrame)
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
// MARK: - IqStreamFrame struct implementation
// --------------------------------------------------------------------------------
//
//  Populated by the IQ Stream vitaHandler
//

/// Struct containing IQ Stream data
///
public struct IqStreamFrame {
    
    public var daxIqChannel = -1
    public private(set) var samples = 0                     /// number of samples (L/R) in this frame
    public var realSamples = [Float]()                        /// Array of real (I) samples
    public var imagSamples = [Float]()                       /// Array of imag (Q) samples
    
    /// Initialize an IqtreamFrame
    ///
    /// - Parameters:
    ///   - payload:        pointer to a Vita packet payload
    ///   - numberOfBytes:  number of bytes in the payload
    ///
    public init(payload: UnsafeRawPointer, numberOfBytes: Int) {
        
        // 4 byte each for left and right sample (4 * 2)
        self.samples = numberOfBytes / (4 * 2)
        
        // allocate the samples arrays
        self.realSamples = [Float](repeating: 0, count: samples)
        self.imagSamples = [Float](repeating: 0, count: samples)
    }
}

// --------------------------------------------------------------------------------
// MARK: - IqStream Class extensions
//              - Synchronized internal properties
//              - Public properties, no message to Radio
// --------------------------------------------------------------------------------

extension IqStream {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties - with synchronization
    
    // listed in alphabetical order
    internal var _available: Int {
        get { return _iqStreamsQ.sync { __available } }
        set { _iqStreamsQ.sync(flags: .barrier) { __available = newValue } } }
    
    internal var _capacity: Int {
        get { return _iqStreamsQ.sync { __capacity } }
        set { _iqStreamsQ.sync(flags: .barrier) { __capacity = newValue } } }
    
    internal var _daxIqChannel: Radio.DaxIqChannel {
        get { return _iqStreamsQ.sync { __daxIqChannel } }
        set { _iqStreamsQ.sync(flags: .barrier) { __daxIqChannel = newValue } } }
    
    internal var _inUse: Bool {
        get { return _iqStreamsQ.sync { __inUse } }
        set { _iqStreamsQ.sync(flags: .barrier) { __inUse = newValue } } }
    
    internal var _ip: String {
        get { return _iqStreamsQ.sync { __ip } }
        set { _iqStreamsQ.sync(flags: .barrier) { __ip = newValue } } }
    
    internal var _port: Int {
        get { return _iqStreamsQ.sync { __port } }
        set { _iqStreamsQ.sync(flags: .barrier) { __port = newValue } } }
    
    internal var _pan: xFlexAPI.Radio.PanadapterId? {
        get { return _iqStreamsQ.sync { __pan } }
        set { _iqStreamsQ.sync(flags: .barrier) { __pan = newValue } } }
    
    internal var _rate: Int {
        get { return _iqStreamsQ.sync { __rate } }
        set { _iqStreamsQ.sync(flags: .barrier) { __rate = newValue } } }
    
    internal var _streaming: Bool {
        get { return _iqStreamsQ.sync { __streaming } }
        set { _iqStreamsQ.sync(flags: .barrier) { __streaming = newValue } } }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (no message to Radio)
    
    // FIXME: Should any of these send a message to the Radio?
    //          If yes, implement it, if not should they be "get" only?
    
    // listed in alphabetical order
    @objc dynamic public var available: Int {
        return _available }
    
    @objc dynamic public var capacity: Int {
        return _capacity }
    
    @objc dynamic public var daxIqChannel: Radio.DaxIqChannel {
        return _daxIqChannel }
    
    @objc dynamic public var inUse: Bool {
        return _inUse }
    
    @objc dynamic public var ip: String {
        return _ip }
    
    @objc dynamic public var port: Int {
        return _port  }
    
    @objc dynamic public var pan: xFlexAPI.Radio.PanadapterId? {
        return _pan }
    
    @objc dynamic public var streaming: Bool {
        return _streaming  }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - NON KVO compliant Setters / Getters with synchronization
    
    public var delegate: IqStreamHandler? {
        get { return _iqStreamsQ.sync { _delegate } }
        set { _iqStreamsQ.sync(flags: .barrier) { _delegate = newValue } } }
}
