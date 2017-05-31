//
//  Waterfall.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 5/31/15.
//  Copyright (c) 2015 Douglas Adams, K3TZR
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Protocols

public protocol WaterfallStreamHandler
{
    // method to process Waterfall data stream
    func waterfallStreamHandler(_ dataFrame: WaterfallFrame ) -> Void
}

// --------------------------------------------------------------------------------
// MARK: - Waterfall Class implementation
// --------------------------------------------------------------------------------

public final class Waterfall : NSObject, KeyValueParser, VitaHandler {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    public private(set) var id: String = ""                 // Id that uniquely identifies this Waterfall (StreamId)
    public private(set) var lastTimecode: Int = 0           // Time code of last frame received
    public private(set) var droppedPackets: Int = 0         // Number of dropped (out of sequence) packets
    public private(set) var isBeingRemoved = false          // true when in the process of being removed

    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _initialized = false                    // True if initialized by Radio hardware

    fileprivate weak var _radio: Radio?                     // The Radio that owns this Waterfall
    fileprivate var _waterfallQ: DispatchQueue              // GCD queue that guards this object
    fileprivate var _delegate: WaterfallStreamHandler?      // Delegate for Waterfall stream

    // constants
    fileprivate let _log = Log.sharedInstance               // shared log
    fileprivate let kModule = "Waterfall"                   // Module Name reported in log messages
    fileprivate let kDisplayPanafallSetCmd = "display panafall set " // Panafall Set command prefix
    
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    //                                                                                              //
    fileprivate var __autoBlackEnabled = false              // State of auto black                  //
    fileprivate var __autoBlackLevel: UInt32 = 0            //                                      //
    fileprivate var __blackLevel = 0                        // Setting of black level (1 -> 100)    //
    fileprivate var __colorGain = 0                         // Setting of color gain (1 -> 100)     //
    fileprivate var __gradientIndex = 0                     // Index of selected color gradient     //
    fileprivate var __lineDuration = 0                      // Line duration (milliseconds)         //
    fileprivate var __panadapterId = ""                     // Panadaptor above this waterfall      //
    //                                                                                              //
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    
    // ------------------------------------------------------------------------------
    // MARK: - Initialization
    
    /// Initialize a Waterfall
    ///
    /// - Parameters:
    ///   - streamId: a Waterfall Id
    ///   - radio: parent Radio class
    ///   - queue: Waterfall Concurrent queue
    ///
    public init(streamId: String, radio: Radio, queue: DispatchQueue) {
        
        self._radio = radio
        self.id = streamId
        self._waterfallQ = queue

        super.init()
    }

    // ------------------------------------------------------------------------------
    // MARK: - KeyValueParser Protocol methods
    //     called by Radio, executes on the parseQ
    
    /// Parse Waterfall key/value pairs
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
            // get the Integer version of the value
            let iValue = (kv.value).iValue()
            
            // Known keys, in alphabetical order
            switch token {
                
            case .autoBlackEnabled:
                willChangeValue(forKey: "autoBlackEnabled")
                _autoBlackEnabled = kv.value.bValue()
                didChangeValue(forKey: "autoBlackEnabled")
            
            case .blackLevel:
                willChangeValue(forKey: "blackLevel")
                _blackLevel = iValue
                didChangeValue(forKey: "blackLevel")
            
            case .colorGain:
                willChangeValue(forKey: "colorGain")
                _colorGain = iValue
                didChangeValue(forKey: "colorGain")
            
            case .gradientIndex:
                willChangeValue(forKey: "gradientIndex")
                _gradientIndex = iValue
                didChangeValue(forKey: "gradientIndex")
            
            case .lineDuration:
                willChangeValue(forKey: "lineDuration")
                _lineDuration = iValue
                didChangeValue(forKey: "lineDuration")
            
            case .panadapterId:
                willChangeValue(forKey: "panadapterId")
                _panadapterId = kv.value
                didChangeValue(forKey: "panadapterId")
            
            case .available, .band, .bandwidth, .capacity, .center, .daxIq, .daxIqRate,
                    .loopA, .loopB, .rfGain, .rxAnt, .wide, .xPixels, .xvtr:
                // held on the corresponding Panadapter object
                break
            }
        }
        // is the waterfall initialized?
        if !_initialized && panadapterId != "" {

            // YES, the Radio (hardware) has acknowledged this Waterfall
            _initialized = true
            
            // notify all observers
            NC.post(.waterfallInitialized, object: self as Any?)
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - VitaHandler protocol methods

    //      called by Radio on the udpQ
    //
    //      The payload of the incoming Vita struct is converted to a WaterfallFrame and
    //      passed to the Waterfall Stream Handler
    
    /// Process the Waterfall Vita struct
    ///
    /// - parameter vita:   a Vita struct
    ///
    func vitaHandler(_ vita: Vita) {
        let kByteOffsetToBins = 32              // Bins are located 32 bytes into payload
        
        // if there is a delegate, process the Waterfall stream
        if let delegate = delegate {
            
            // initialize a data frame
            var dataFrame = WaterfallFrame(payload: vita.payload!)
            
            // If the time code is out-of-sequence, ignore the packet
            if dataFrame.timeCode < self.lastTimecode {
                self.droppedPackets += 1
                self._log.msg("Missing packet(s), timecode: \(dataFrame.timeCode) < last timecode: \(self.lastTimecode)", level: .warning, function: #function, file: #file, line: #line)
                // out of sequence, ignore this packet
                return
            }
            self.lastTimecode = dataFrame.timeCode;
            
            // get a pointer to the data in the payload
            //                let binsPtr = UnsafePointer<UInt16>( vitaPacket.payload!.advanced(by: kByteOffsetToBins) )
            if let binsPtr = vita.payload?.advanced(by: kByteOffsetToBins).bindMemory(to: UInt16.self, capacity: dataFrame.numberOfBins) {
                
                // Swap the byte ordering of the data & place it in the dataFrame bins
                for i in 0..<dataFrame.numberOfBins * dataFrame.lineHeight {
                    dataFrame.bins[i] = CFSwapInt16BigToHost(binsPtr.advanced(by: i).pointee)
                }
            }
            autoBlackLevel = dataFrame.autoBlackLevel
            
            // Pass the data frame to this Waterfall's delegate
            delegate.waterfallStreamHandler(dataFrame)
        }
    }
}

// ------------------------------------------------------------------------------
// MARK: - WaterfallFrame struct implementation
// --------------------------------------------------------------------------------
//
//  Populated by the Waterfall vitaHandler
//

/// Struct containing Waterfall Stream data
///
public struct WaterfallFrame {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    public private(set) var firstBinFreq: CGFloat = 0.0 // Frequency of first Bin (Hz)
    public private(set) var binBandwidth: CGFloat = 0.0 // Bandwidth of a single bin (Hz)
    public private(set) var lineDuration = 0            // Duration of this line (ms)
    public private(set) var lineHeight = 0              // Height of frame (pixels)
    public private(set) var timeCode = 0                // Time code
    public private(set) var autoBlackLevel: UInt32 = 0  // Auto black level
    public private(set) var numberOfBins = 0            // Number of bins
    public var bins = [UInt16]()                        // Array of bin values
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private struct WaterfallPayload {                   /// struct to mimic payload layout
        var firstBinFreq: UInt64                        // 8 bytes
        var binBandwidth: UInt64                        // 8 bytes
        var lineDuration: UInt32                        // 4 bytes
        var numberOfBins: UInt16                        // 2 bytes
        var lineHeight: UInt16                          // 2 bytes
        var timeCode: UInt32                            // 4 bytes
        var autoBlackLevel: UInt32                      // 4 bytes
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization

    /// Initialize a WaterfallFrame
    ///
    /// - parameter payload:    pointer to a Vita payload
    ///
    public init(payload: UnsafeRawPointer) {
        
        // map the payload to the WaterfallPayload struct
        let p = payload.bindMemory(to: WaterfallPayload.self, capacity: 1)
        
        // byte swap and convert each payload component
        self.firstBinFreq = CGFloat(CFSwapInt64BigToHost(p.pointee.firstBinFreq)) / 1.048576E6
        self.binBandwidth = CGFloat(CFSwapInt64BigToHost(p.pointee.binBandwidth)) / 1.048576E6
        self.lineDuration = Int( CFSwapInt32BigToHost(p.pointee.lineDuration) )
        self.lineHeight = Int( CFSwapInt16BigToHost(p.pointee.lineHeight) )
        self.timeCode = Int( CFSwapInt32BigToHost(p.pointee.timeCode) )
        self.autoBlackLevel = CFSwapInt32BigToHost(p.pointee.autoBlackLevel)
        self.numberOfBins = Int( CFSwapInt16BigToHost(p.pointee.numberOfBins) )
        
        // allocate the bins array
        self.bins = [UInt16](repeating: 0, count: numberOfBins)
    }
}

// --------------------------------------------------------------------------------
// MARK: - Waterfall Class extensions
//              - Synchronized internal properties
//              - Dynamic public properties
//              - Waterfall message enum
// --------------------------------------------------------------------------------

extension Waterfall {
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties - with synchronization
    
    // listed in alphabetical order
    fileprivate var _autoBlackEnabled: Bool {
        get { return _waterfallQ.sync { __autoBlackEnabled } }
        set { _waterfallQ.sync(flags: .barrier) {__autoBlackEnabled = newValue } } }
    
    fileprivate var _autoBlackLevel: UInt32 {
        get { return _waterfallQ.sync { __autoBlackLevel } }
        set { _waterfallQ.sync(flags: .barrier) { __autoBlackLevel = newValue } } }
    
    fileprivate var _blackLevel: Int {
        get { return _waterfallQ.sync { __blackLevel } }
        set { _waterfallQ.sync(flags: .barrier) {__blackLevel = newValue } } }
    
    fileprivate var _colorGain: Int {
        get { return _waterfallQ.sync { __colorGain } }
        set { _waterfallQ.sync(flags: .barrier) {__colorGain = newValue } } }
    
    fileprivate var _gradientIndex: Int {
        get { return _waterfallQ.sync { __gradientIndex } }
        set { _waterfallQ.sync(flags: .barrier) {__gradientIndex = newValue } } }
    
    fileprivate var _lineDuration: Int {
        get { return _waterfallQ.sync { __lineDuration } }
        set { _waterfallQ.sync(flags: .barrier) {__lineDuration = newValue } } }
    
    fileprivate var _panadapterId: String {
        get { return _waterfallQ.sync { __panadapterId } }
        set { _waterfallQ.sync(flags: .barrier) { __panadapterId = newValue } } }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant with Radio update
    
    // listed in alphabetical order
    dynamic public var autoBlackEnabled: Bool {
        get { return _autoBlackEnabled }
        set { if _autoBlackEnabled != newValue { _autoBlackEnabled = newValue ; _radio!.send(kDisplayPanafallSetCmd + "0x\(id) auto_black=" + newValue.asNumber()) } } }
    
    dynamic public var autoBlackLevel: UInt32 {
        get { return _autoBlackLevel }
        set { if _autoBlackLevel != newValue { _autoBlackLevel = newValue } } }
    
    dynamic public var blackLevel: Int {
        get { return _blackLevel }
        set { if _blackLevel != newValue { _blackLevel = newValue ; _radio!.send(kDisplayPanafallSetCmd + "0x\(id) black_level=\(newValue)") } } }
    
    dynamic public var colorGain: Int {
        get { return _colorGain }
        set { if _colorGain != newValue { _colorGain = newValue ; _radio!.send(kDisplayPanafallSetCmd + "0x\(id) color_gain=\(newValue)") } } }
    
    dynamic public var gradientIndex: Int {
        get { return _gradientIndex }
        set { if _gradientIndex != newValue { _gradientIndex = newValue ; _radio!.send(kDisplayPanafallSetCmd + "0x\(id) gradient_index=\(newValue)") } } }
    
    dynamic public var lineDuration: Int {
        get { return _lineDuration }
        set { if _lineDuration != newValue { _lineDuration = newValue ; _radio!.send(kDisplayPanafallSetCmd + "0x\(id) line_duration=\(newValue)") } } }
    
    dynamic public var panadapterId: String {
        get { return _panadapterId }
        set { if _panadapterId != newValue { _panadapterId = newValue } } }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - NON KVO compliant Setters / Getters with synchronization
    
    public var delegate: WaterfallStreamHandler? {
        get { return _waterfallQ.sync { _delegate } }
        set { _waterfallQ.sync(flags: .barrier) { _delegate = newValue } } }

    // ----------------------------------------------------------------------------
    // Mark: - Tokens for Waterfall messages (only populate values that != case value)
    
    internal enum Token : String {
        case autoBlackEnabled = "auto_black"
        case available
        case band
        case bandwidth
        case blackLevel = "black_level"
        case capacity
        case center
        case colorGain = "color_gain"
        case daxIq = "daxiq"
        case daxIqRate = "daxiq_rate"
        case gradientIndex = "gradient_index"
        case lineDuration = "line_duration"
        case loopA = "loopa"
        case loopB = "loopb"
        case panadapterId = "panadapter"
        case rfGain = "rfgain"
        case rxAnt = "rxant"
        case wide
        case xPixels = "x_pixels"
        case xvtr
    }

}
