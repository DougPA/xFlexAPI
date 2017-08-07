//
//  Panadapter.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 5/31/15.
//  Copyright (c) 2015 Douglas Adams, K3TZR
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Protocols

public protocol PanadapterStreamHandler: class {
    
    // method to process Panadapter data stream
    func panadapterStreamHandler(_ frame: PanadapterFrame) -> Void
}

// --------------------------------------------------------------------------------
// MARK: - Panadapter implementation
//
//      creates a Panadapter instance to be used by a Client to support the
//      rendering of a Panadapter
//
// --------------------------------------------------------------------------------

public final class Panadapter : NSObject, KeyValueParser, VitaHandler {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    public private(set) var radio: Radio?                   // The Radio that owns this Panadapter
    public private(set) var id: String = ""                 // Id that uniquely identifies this Panadapter (StreamId)
    
    public private(set) var lastFrameIndex: Int = 0         // Frame index of previous Vita payload
    public private(set) var droppedPackets: Int = 0         // Number of dropped (out of sequence) packets
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    internal let kDisplayPanafallSetCmd = "display panafall set " // Panafall "set" command prefix
    internal let kDisplayPanCmd = "display pan "                // Pan command prefix
    internal let kMinLevel = 0                                  // control range
    internal let kMaxLevel = 100
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _pandapterQ: DispatchQueue                  // GCD queue that guards this object
    fileprivate var _initialized = false                        // True if initialized by Radio (hardware)
    
    // constants
    fileprivate let _log = Log.sharedInstance                   // shared Log
    fileprivate let kNoError = "0"                              // response without error
    
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    //                                                                                                  //
    fileprivate var __antList = [String]()                      // Available antenna choices            //
    fileprivate var __autoCenterEnabled = false                 //                                      //
    fileprivate var __average = 0                               // Setting of average (1 -> 100)        //
    fileprivate var __band = ""                                 // Band encompassed by this pan         //
    fileprivate var __bandwidth = 0                             // Bandwidth in Hz                      //
    fileprivate var __center = 0                                // Center in Hz                         //
    fileprivate var __daxIqChannel = 0                          // DAX IQ channel number (0=none)       //
    fileprivate var __fps = 0                                   // Refresh rate (frames/second)         //
    fileprivate var __loopAEnabled = false                      // Enable LOOPA for RXA                 //
    fileprivate var __loopBEnabled = false                      // Enable LOOPB for RXB                 //
    fileprivate var __maxBw = 0                                 // Maximum bandwidth                    //
    fileprivate var __minBw = 0                                 // Minimum bandwidthl                   //
    fileprivate var __maxDbm: CGFloat = 0.0                     // Maximum dBm level                    //
    fileprivate var __minDbm: CGFloat = 0.0                     // Minimum dBm level                    //
    fileprivate var __panDimensions = CGSize(width: 0, height: 0) // frame size                         //
    fileprivate var __preamp = ""                               // Label of preselector selected        //
    fileprivate var __rfGain = 0                                // RF Gain of preamp/attenuator         //
    fileprivate var __rfGainHigh = 0                            // RF Gain high value                   //
    fileprivate var __rfGainLow = 0                             // RF Gain low value                    //
    fileprivate var __rfGainStep = 0                            // RF Gain step value                   //
    fileprivate var __rfGainValues = ""                         // Possible Rf Gain values              //
    fileprivate var __rxAnt = ""                                // Receive antenna name                 //
    fileprivate var __waterfallId = ""                          // Waterfall belowo this Panadapter     //
    fileprivate var __weightedAverageEnabled = false            // Enable weighted averaging            //
    fileprivate var __wide = false                              // Preselector state                    //
    fileprivate var __wnbEnabled = false                        // Wideband noise blanking enabled      //
    fileprivate var __wnbLevel = 0                              // Wideband noise blanking level        //
    fileprivate var __wnbUpdating = false                       // WNB is updating                      //
    fileprivate var __xvtrLabel = ""                            // Label of selected XVTR profile       //
    //                                                                                                  //
    fileprivate weak var _delegate: PanadapterStreamHandler?    // Delegate for Panadapter stream       //
    //                                                                                                  //
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    
    // ------------------------------------------------------------------------------
    // MARK: - Initialization
    
    /// Initialize a Panadapter
    ///
    /// - Parameters:
    ///   - radio:      parent Radio class
    ///   - id:         a Panadapter Id
    ///   - queue:      Panadapter Concurrent queue
    ///
    init(radio: Radio, id: String, queue: DispatchQueue) {
        
        self.radio = radio
        self.id = id
        self._pandapterQ = queue
        
        super.init()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Panadapter Reply Handler
    
    /// Process the Reply to an Rf Gain Info command, reply format: <value>,<value>,...<value>
    ///
    /// - Parameters:
    ///   - seqNum:         the Sequence Number of the original command
    ///   - responseValue:  the response value
    ///   - reply:          the reply
    ///
    func replyHandler(_ command: String, seqNum: String, responseValue: String, reply: String) {
        
        guard responseValue == kNoError else {
            // Anything other than 0 is an error, log it and ignore the Reply
            _log.msg(command + ", non-zero reply - \(responseValue)", level: .error, function: #function, file: #file, line: #line)
            return
        }
        // parse out the values
        let rfGainInfo = reply.valuesArray( delimiter: "," )
        _rfGainLow = rfGainInfo[0].iValue()
        _rfGainHigh = rfGainInfo[1].iValue()
        _rfGainStep = rfGainInfo[2].iValue()
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - KeyValueParser Protocol methods
    //     called by Radio, executes on the radioQ
    //
    
    /// Parse Panadapter key/value pairs
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///
    func parseKeyValues(_ keyValues: Radio.KeyValuesArray) {
        
        // process each key/value pair, <key=value>
        for kv in keyValues {
            
            // check for unknown keys
            guard let token = PanadapterToken(rawValue: kv.key.lowercased()) else {
                // unknown Key, log it and ignore the Key
                _log.msg("Unknown token - \(kv.key)", level: .debug, function: #function, file: #file, line: #line)
                continue
            }
            // get the Int, Bool and Float versions of the value
            let iValue = (kv.value).iValue()
            let bValue = (kv.value).bValue()
            let fValue = (kv.value).fValue()
            
            // Known keys, in alphabetical order
            switch token {
                
            case .antList:
                willChangeValue(forKey: "antList")
                _antList = kv.value.components(separatedBy: ",")
                didChangeValue(forKey: "antList")
                
            case .average:
                willChangeValue(forKey: "average")
                _average = iValue
                didChangeValue(forKey: "average")
                
            case .band:
                willChangeValue(forKey: "band")
                _band = kv.value
                didChangeValue(forKey: "band")
                
            case .bandwidth:
                willChangeValue(forKey: "bandwidth")
                _bandwidth = kv.value.mhzToHz()
                didChangeValue(forKey: "bandwidth")
                
            case .center:
                willChangeValue(forKey: "center")
                _center = kv.value.mhzToHz()
                didChangeValue(forKey: "center")
                
            case .daxIqChannel:
                willChangeValue(forKey: "daxIqChannel")
                _daxIqChannel = iValue
                didChangeValue(forKey: "daxIqChannel")
                
            case .fps:
                willChangeValue(forKey: "fps")
                _fps = iValue
                didChangeValue(forKey: "fps")
                
            case .loopAEnabled:
                willChangeValue(forKey: "loopAEnabled")
                _loopAEnabled = bValue
                didChangeValue(forKey: "loopAEnabled")
                
            case .loopBEnabled:
                willChangeValue(forKey: "loopAEnabled")
                _loopAEnabled = bValue
                didChangeValue(forKey: "loopAEnabled")
                
            case .maxBw:
                willChangeValue(forKey: "maxBw")
                _maxBw = kv.value.mhzToHz()
                didChangeValue(forKey: "maxBw")
                
            case .maxDbm:
                willChangeValue(forKey: "maxDbm")
                _maxDbm = CGFloat(fValue)
                didChangeValue(forKey: "maxDbm")
                
            case .minBw:
                willChangeValue(forKey: "minBw")
                _minBw = kv.value.mhzToHz()
                didChangeValue(forKey: "minBw")
                
            case .minDbm:
                willChangeValue(forKey: "minDbm")
                _minDbm = CGFloat(fValue)
                didChangeValue(forKey: "minDbm")
                
            case .preamp:
                willChangeValue(forKey: "preamp")
                _preamp = kv.value
                didChangeValue(forKey: "preamp")
                
            case .rfGain:
                willChangeValue(forKey: "rfGain")
                _rfGain = iValue
                didChangeValue(forKey: "rfGain")
                
            case .rxAnt:
                willChangeValue(forKey: "rxAnt")
                _rxAnt = kv.value
                didChangeValue(forKey: "rxAnt")
                
            case .waterfallId:
                willChangeValue(forKey: "waterfallId")
                _waterfallId = kv.value
                didChangeValue(forKey: "waterfallId")
                
            case .wide:
                willChangeValue(forKey: "wide")
                _wide = bValue
                didChangeValue(forKey: "wide")
                
            case .weightedAverageEnabled:
                willChangeValue(forKey: "weightedAverageEnabled")
                _weightedAverageEnabled = bValue
                didChangeValue(forKey: "weightedAverageEnabled")
                
            case .wnbEnabled:
                willChangeValue(forKey: "wnbEnabled")
                _wnbEnabled = bValue
                didChangeValue(forKey: "wnbEnabled")
                
            case .wnbLevel:
                willChangeValue(forKey: "wnbLevel")
                _wnbLevel = iValue
                didChangeValue(forKey: "wnbLevel")
                
            case .wnbUpdating:
                willChangeValue(forKey: "wnbUpdating")
                _wnbUpdating = bValue
                didChangeValue(forKey: "wnbUpdating")
                
            case .xPixels:
                willChangeValue(forKey: "panDimensions")
                _panDimensions.width = CGFloat(fValue)
                didChangeValue(forKey: "panDimensions")
                
            case .xvtrLabel:
                willChangeValue(forKey: "xvtrLabel")
                _xvtrLabel = kv.value
                didChangeValue(forKey: "xvtrLabel")
                
            case .yPixels:
                willChangeValue(forKey: "panDimensions")
                _panDimensions.height = CGFloat(fValue)
                didChangeValue(forKey: "panDimensions")
                
            case .available, .capacity, .daxIqRate:
                // ignored here
                break
            }
        }
        // is the Panadapter initialized?
        if !_initialized && center != 0 && bandwidth != 0 && (minDbm != 0.0 || maxDbm != 0.0) {
            
            // YES, the Radio (hardware) has acknowledged this Panadapter
            _initialized = true
            
            // notify all observers
            NC.post(.panadapterHasBeenAdded, object: self as Any?)            
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - VitaHandler Protocol method

    //      called by Radio on the udpReceiveQ
    //
    //      The payload of the incoming Vita struct is converted to a PanadapterFrame and
    //      passed to the Panadapter Stream Handler
    
    /// Process the Panadapter Vita struct
    ///
    /// - Parameters:
    ///   - vita:        a Vita struct
    ///
    func vitaHandler(_ vita: Vita) {
        let kByteOffsetToBins = 16              // Bins are located 16 bytes into payload
        
        // if there is a delegate, process the Panadapter stream
        if let delegate = delegate {
            
            // initialize a data frame
            var dataFrame = PanadapterFrame(payload: vita.payload!)
            
            // If the frame index is out-of-sequence, ignore the packet
            if dataFrame.frameIndex < self.lastFrameIndex {
                self.droppedPackets += 1
                self._log.msg("Missing packet(s), frameIndex: \(dataFrame.frameIndex) < last frameIndex: \(self.lastFrameIndex)", level: .warning, function: #function, file: #file, line: #line)
                return
            }
            self.lastFrameIndex = dataFrame.frameIndex
            
            // get a pointer to the data in the payload
            if let binsPtr = vita.payload?.advanced(by: kByteOffsetToBins).bindMemory(to: UInt16.self, capacity: dataFrame.numberOfBins) {
                
                // Swap the byte ordering of the data & place it in the dataFrame bins
                for i in 0..<dataFrame.numberOfBins {
                    dataFrame.bins[i] = CFSwapInt16BigToHost( binsPtr.advanced(by: i).pointee )
                }
            }
            // Pass the data frame to this Panadapter's delegate
            delegate.panadapterStreamHandler(dataFrame)
        }
    }
}

// --------------------------------------------------------------------------------
// MARK: - PanadapterFrame struct implementation
// --------------------------------------------------------------------------------
//
//  Populated by the Panadapter vitaHandler
//

/// Struct containing Panadapter Stream data
///
public struct PanadapterFrame {
    
    public private(set) var startingBinIndex = 0        /// Index of first bin
    public private(set) var numberOfBins = 0            /// Number of bins
    public private(set) var binSize = 0                 /// Bin size in bytes
    public private(set) var frameIndex = 0              /// Frame index
    public var bins = [UInt16]()                        /// Array of bin values
    
    private struct PanadapterPayload {                  /// struct to mimic payload layout
        var startingBinIndex: UInt32
        var numberOfBins: UInt32
        var binSize: UInt32
        var frameIndex: UInt32
    }
    
    /// Initialize a PanadapterFRame
    ///
    /// - Parameters:
    ///   - payload:        pointer to a Vita payload
    ///
    public init(payload: UnsafeRawPointer) {
        
        // map the payload to the PanadapterPayload struct
        let p = payload.bindMemory(to: PanadapterPayload.self, capacity: 1)
        
        // byte swap and convert each payload component
        self.startingBinIndex = Int(CFSwapInt32BigToHost(p.pointee.startingBinIndex))
        self.numberOfBins = Int(CFSwapInt32BigToHost(p.pointee.numberOfBins))
        self.binSize = Int(CFSwapInt32BigToHost(p.pointee.binSize))
        self.frameIndex = Int(CFSwapInt32BigToHost(p.pointee.frameIndex))
        
        // allocate the bins array
        self.bins = [UInt16](repeating: 0, count: numberOfBins)
    }
}

// --------------------------------------------------------------------------------
// MARK: - Panadapter Class extensions
//              - Synchronized internal properties
//              - Public properties, no message to Radio
// --------------------------------------------------------------------------------

extension Panadapter {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties - with synchronization

    internal var _antList: [String] {
        get { return _pandapterQ.sync { __antList } }
        set { _pandapterQ.sync(flags: .barrier) { __antList = newValue } } }
    
    internal var _average: Int {
        get { return _pandapterQ.sync { __average } }
        set { _pandapterQ.sync(flags: .barrier) { __average = newValue } } }
    
    internal var _band: String {
        get { return _pandapterQ.sync { __band } }
        set { _pandapterQ.sync(flags: .barrier) { __band = newValue } } }
    
    internal var _bandwidth: Int {
        get { return _pandapterQ.sync { __bandwidth } }
        set { _pandapterQ.sync(flags: .barrier) { __bandwidth = newValue } } }
    
    internal var _center: Int {
        get { return _pandapterQ.sync { __center } }
        set { _pandapterQ.sync(flags: .barrier) { __center = newValue } } }
    
    internal var _daxIqChannel: Int {
        get { return _pandapterQ.sync { __daxIqChannel } }
        set { _pandapterQ.sync(flags: .barrier) { __daxIqChannel = newValue } } }
    
    internal var _fps: Int {
        get { return _pandapterQ.sync { __fps } }
        set { _pandapterQ.sync(flags: .barrier) { __fps = newValue } } }
    
    internal var _loopAEnabled: Bool {
        get { return _pandapterQ.sync { __loopAEnabled } }
        set { _pandapterQ.sync(flags: .barrier) { __loopAEnabled = newValue } } }
    
    internal var _loopBEnabled: Bool {
        get { return _pandapterQ.sync { __loopBEnabled } }
        set { _pandapterQ.sync(flags: .barrier) { __loopBEnabled = newValue } } }
    
    internal var _maxBw: Int {
        get { return _pandapterQ.sync { __maxBw } }
        set { _pandapterQ.sync(flags: .barrier) { __maxBw = newValue } } }
    
    internal var _maxDbm: CGFloat {
        get { return _pandapterQ.sync { __maxDbm } }
        set { _pandapterQ.sync(flags: .barrier) { __maxDbm = newValue } } }
    
    internal var _minBw: Int {
        get { return _pandapterQ.sync { __minBw } }
        set { _pandapterQ.sync(flags: .barrier) { __minBw = newValue } } }
    
    internal var _minDbm: CGFloat {
        get { return _pandapterQ.sync { __minDbm } }
        set { _pandapterQ.sync(flags: .barrier) { __minDbm = newValue } } }
    
    internal var _panDimensions: CGSize {
        get { return _pandapterQ.sync { __panDimensions } }
        set { _pandapterQ.sync(flags: .barrier) { __panDimensions = newValue } } }
    
    internal var _preamp: String {
        get { return _pandapterQ.sync { __preamp } }
        set { _pandapterQ.sync(flags: .barrier) { __preamp = newValue } } }
    
    internal var _rfGain: Int {
        get { return _pandapterQ.sync { __rfGain } }
        set { _pandapterQ.sync(flags: .barrier) { __rfGain = newValue } } }
    
    internal var _rfGainHigh: Int {
        get { return _pandapterQ.sync { __rfGainHigh } }
        set { _pandapterQ.sync(flags: .barrier) { __rfGainHigh = newValue } } }
    
    internal var _rfGainLow: Int {
        get { return _pandapterQ.sync { __rfGainLow } }
        set { _pandapterQ.sync(flags: .barrier) { __rfGainLow = newValue } } }
    
    internal var _rfGainStep: Int {
        get { return _pandapterQ.sync { __rfGainStep } }
        set { _pandapterQ.sync(flags: .barrier) { __rfGainStep = newValue } } }
    
    internal var _rfGainValues: String {
        get { return _pandapterQ.sync { __rfGainValues } }
        set { _pandapterQ.sync(flags: .barrier) { __rfGainValues = newValue } } }
    
    internal var _rxAnt: String {
        get { return _pandapterQ.sync { __rxAnt } }
        set { _pandapterQ.sync(flags: .barrier) { __rxAnt = newValue } } }
    
    internal var _waterfallId: String {
        get { return _pandapterQ.sync { __waterfallId } }
        set { _pandapterQ.sync(flags: .barrier) { __waterfallId = newValue } } }
    
    internal var _weightedAverageEnabled: Bool {
        get { return _pandapterQ.sync { __weightedAverageEnabled } }
        set { _pandapterQ.sync(flags: .barrier) { __weightedAverageEnabled = newValue } } }
    
    internal var _wide: Bool {
        get { return _pandapterQ.sync { __wide } }
        set { _pandapterQ.sync(flags: .barrier) { __wide = newValue } } }
    
    internal var _wnbEnabled: Bool {
        get { return _pandapterQ.sync { __wnbEnabled } }
        set { _pandapterQ.sync(flags: .barrier) { __wnbEnabled = newValue } } }
    
    internal var _wnbLevel: Int {
        get { return _pandapterQ.sync { __wnbLevel } }
        set { _pandapterQ.sync(flags: .barrier) { __wnbLevel = newValue } } }
    
    internal var _wnbUpdating: Bool {
        get { return _pandapterQ.sync { __wnbUpdating } }
        set { _pandapterQ.sync(flags: .barrier) { __wnbUpdating = newValue } } }
    
    internal var _xvtrLabel: String {
        get { return _pandapterQ.sync { __xvtrLabel } }
        set { _pandapterQ.sync(flags: .barrier) { __xvtrLabel = newValue } } }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (no message to Radio)
    
    // FIXME: Should any of these send a message to the Radio?
    //          If yes, implement it, if not should they be "get" only?
    
    // listed in alphabetical order
    @objc dynamic public var antList: [String] {
        return _antList }
    
    @objc dynamic public var maxBw: Int {
        return _maxBw }
    
    @objc dynamic public var minBw: Int {
        return _minBw }
    
    @objc dynamic public var preamp: String {
        return _preamp }
    
    @objc dynamic public var rfGainHigh: Int {
        return _rfGainHigh }
    
    @objc dynamic public var rfGainLow: Int {
        return _rfGainLow }
        
    @objc dynamic public var rfGainStep: Int {
        return _rfGainStep }
    
    @objc dynamic public var rfGainValues: String {
        return _rfGainValues }
    
    @objc dynamic public var waterfallId: String {
        return _waterfallId }
    
    @objc dynamic public var wide: Bool {
        return _wide }
    
    @objc dynamic public var wnbUpdating: Bool {
        return _wnbUpdating }
    
    @objc dynamic public var xvtrLabel: String {
        return _xvtrLabel }
    
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - NON KVO compliant Setters / Getters with synchronization
    
    public var delegate: PanadapterStreamHandler? {
        get { return _pandapterQ.sync { _delegate } }
        set { _pandapterQ.sync(flags: .barrier) { _delegate = newValue } } }

}
