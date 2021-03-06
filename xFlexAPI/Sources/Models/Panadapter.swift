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

public protocol PanadapterStreamHandler {
    
    // method to process Panadapter data stream
    func panadapterStreamHandler(_ frame: PanadapterFrame) -> Void
    
}

// --------------------------------------------------------------------------------
// MARK: - Panadapter implementation
// --------------------------------------------------------------------------------

public final class Panadapter : NSObject, KeyValueParser, VitaHandler {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    public private(set) weak var radio: Radio?                  // The Radio that owns this Panadapter
    public private(set) var id: String = ""                     // Id that uniquely identifies this Panadapter (StreamId)
    
    public private(set) var lastFrameIndex: Int = 0             // Frame index of previous Vita payload
    public private(set) var droppedPackets: Int = 0             // Number of dropped (out of sequence) packets
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _pandapterQ: DispatchQueue                  // GCD queue that guards this object
    fileprivate var _initialized = false                        // True if initialized by Radio (hardware)
    
    // constants
    fileprivate let _log = Log.sharedInstance                   // shared Log
    fileprivate let kModule = "Panadapter"                      // Module Name reported in log messages
    fileprivate let kDisplayPanafallSetCmd = "display panafall set " // Panafall "set" command prefix
    fileprivate let kMinLevel = 0                               // control range
    fileprivate let kMaxLevel = 100
    fileprivate let kNoError = "0"                              // response without error
    
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    //                                                                                              //
    fileprivate var __antList = [String]()                      // Available antenna choices        //
    fileprivate var __autoCenterEnabled = false                 //                                  //
    fileprivate var __available = 0                             // Capacity available (read only)   //
    fileprivate var __average = 0                               // Setting of average (1 -> 100)    //
    fileprivate var __band = ""                                 // Band encompassed by this pan     //
    fileprivate var __bandwidth = 0                             // Bandwidth in Hz                  //
    fileprivate var __capacity = 0                              // Capacity maximum indicator       //
    fileprivate var __center = 0                                // Center in Hz                     //
    fileprivate var __daxIqChannel = 0                          // DAX IQ channel number (0=none)   //
    fileprivate var __daxIqRate = 0                             // DAX IQ Rate in bps               //
    fileprivate var __fps = 0                                   // Refresh rate (frames/second)     //
    fileprivate var __loopAEnabled = false                      // Enable LOOPA for RXA             //
    fileprivate var __loopBEnabled = false                      // Enable LOOPB for RXB             //
    fileprivate var __maxBw = 0                                 // Maximum bandwidth                //
    fileprivate var __minBw = 0                                 // Minimum bandwidthl               //
    fileprivate var __maxDbm: CGFloat = 0.0                     // Maximum dBm level                //
    fileprivate var __minDbm: CGFloat = 0.0                     // Minimum dBm level                //
    fileprivate var __panDimensions = CGSize(width: 0, height: 0) // frame size                     //
    fileprivate var __preamp = ""                               // Label of preselector selected    //
    fileprivate var __rfGain = 0                                // RF Gain of preamp/attenuator     //
    fileprivate var __rfGainHigh = 0                            // RF Gain high value               //
    fileprivate var __rfGainLow = 0                             // RF Gain low value                //
    fileprivate var __rfGainStep = 0                            // RF Gain step value               //
    fileprivate var __rfGainValues = ""                         // Possible Rf Gain values          //
    fileprivate var __rxAnt = ""                                // Receive antenna name             //
    fileprivate var __waterfallId = ""                          // Waterfall belowo this Panadapter //
    fileprivate var __weightedAverageEnabled = false            // Enable weighted averaging        //
    fileprivate var __wide = false                              // Preselector state                //
    fileprivate var __wnbEnabled = false                        // Wideband noise blanking enabled  //
    fileprivate var __wnbLevel = 0                              // Wideband noise blanking level    //
    fileprivate var __wnbUpdating = false                       // WNB is updating                  //
    fileprivate var __xvtrLabel = ""                            // Label of selected XVTR profile   //
                                                                                                    //
    fileprivate var _delegate: PanadapterStreamHandler?         // Delegate for Panadapter stream   //
    //                                                                                              //
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    
    // ------------------------------------------------------------------------------
    // MARK: - Initialization
    
    /// Initialize a Panadapter
    ///
    /// - Parameters:
    ///   - streamId: a Panadapter Id
    ///   - radio: parent Radio class
    ///   - queue: Panadapter Concurrent queue
    ///
    init(streamId: String, radio: Radio, queue: DispatchQueue) {
        
        self.radio = radio
        self.id = streamId
        self._pandapterQ = queue
        
        super.init()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods that send commands to the Radio (hardware)
    
    public func requestRfGainInfo() { radio!.send("display pan rf_gain_info 0x\(id)", replyTo: replyHandler) }
    
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
        let rfGainInfo = radio!.valuesArray(reply, delimiter: ",")
        rfGainLow = rfGainInfo[0].iValue()
        rfGainHigh = rfGainInfo[1].iValue()
        rfGainStep = rfGainInfo[2].iValue()
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - KeyValueParser Protocol methods
    //     called by Radio, executes on the radioQ
    //
    
    /// Parse Panadapter key/value pairs
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
                
            case .available:
                willChangeValue(forKey: "available")
                _available = iValue
                didChangeValue(forKey: "available")
                
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
                
            case .capacity:
                willChangeValue(forKey: "capacity")
                _capacity = iValue
                didChangeValue(forKey: "capacity")
                
            case .center:
                willChangeValue(forKey: "center")
                _center = kv.value.mhzToHz()
                didChangeValue(forKey: "center")
                
            case .daxIqChannel:
                willChangeValue(forKey: "daxIqChannel")
                _daxIqChannel = iValue
                didChangeValue(forKey: "daxIqChannel")
                
            case .daxIqRate:
                willChangeValue(forKey: "daxIqRate")
                _daxIqRate = iValue
                didChangeValue(forKey: "daxIqRate")
                
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
            }
        }
        // is the Panadapter initialized?
        if !_initialized && center != 0 && bandwidth != 0 && (minDbm != 0.0 || maxDbm != 0.0) {
            
            // YES, the Radio (hardware) has acknowledged this Panadapter
            _initialized = true
            
            // notify all observers
            NC.post(.panadapterInitialized, object: self as Any?)            
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - VitaHandler Protocol method

    //      called by Radio on the udpQ
    //
    //      The payload of the incoming Vita struct is converted to a PanadapterFrame and
    //      passed to the Panadapter Stream Handler
    
    /// Process the Panadapter Vita struct
    ///
    /// - parameter vita:     a Vita struct
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
    /// - parameter payload:    pointer to a Vita payload
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
//              - Dynamic public properties
//              - Panadapter message enum
// --------------------------------------------------------------------------------

extension Panadapter {
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties - with synchronization

    fileprivate var _antList: [String] {
        get { return _pandapterQ.sync { __antList } }
        set { _pandapterQ.sync(flags: .barrier) { __antList = newValue } } }
    
    fileprivate var _autoCenterEnabled: Bool {
        get { return _pandapterQ.sync { __autoCenterEnabled } }
        set { _pandapterQ.sync(flags: .barrier) { __autoCenterEnabled = newValue } } }
    
    fileprivate var _available: Int {
        get { return _pandapterQ.sync { __available } }
        set { _pandapterQ.sync(flags: .barrier) { __available = newValue } } }
    
    fileprivate var _average: Int {
        get { return _pandapterQ.sync { __average } }
        set { _pandapterQ.sync(flags: .barrier) { __average = newValue } } }
    
    fileprivate var _band: String {
        get { return _pandapterQ.sync { __band } }
        set { _pandapterQ.sync(flags: .barrier) { __band = newValue } } }
    
    fileprivate var _bandwidth: Int {
        get { return _pandapterQ.sync { __bandwidth } }
        set { _pandapterQ.sync(flags: .barrier) { __bandwidth = newValue } } }
    
    fileprivate var _capacity: Int {
        get { return _pandapterQ.sync { __capacity } }
        set { _pandapterQ.sync(flags: .barrier) { __capacity = newValue } } }
    
    fileprivate var _center: Int {
        get { return _pandapterQ.sync { __center } }
        set { _pandapterQ.sync(flags: .barrier) { __center = newValue } } }
    
    fileprivate var _daxIqChannel: Int {
        get { return _pandapterQ.sync { __daxIqChannel } }
        set { _pandapterQ.sync(flags: .barrier) { __daxIqChannel = newValue } } }
    
    fileprivate var _daxIqRate: Int {
        get { return _pandapterQ.sync { __daxIqRate } }
        set { _pandapterQ.sync(flags: .barrier) { __daxIqRate = newValue } } }
    
    fileprivate var _fps: Int {
        get { return _pandapterQ.sync { __fps } }
        set { _pandapterQ.sync(flags: .barrier) { __fps = newValue } } }
    
    fileprivate var _loopAEnabled: Bool {
        get { return _pandapterQ.sync { __loopAEnabled } }
        set { _pandapterQ.sync(flags: .barrier) { __loopAEnabled = newValue } } }
    
    fileprivate var _loopBEnabled: Bool {
        get { return _pandapterQ.sync { __loopBEnabled } }
        set { _pandapterQ.sync(flags: .barrier) { __loopBEnabled = newValue } } }
    
    fileprivate var _maxBw: Int {
        get { return _pandapterQ.sync { __maxBw } }
        set { _pandapterQ.sync(flags: .barrier) { __maxBw = newValue } } }
    
    fileprivate var _maxDbm: CGFloat {
        get { return _pandapterQ.sync { __maxDbm } }
        set { _pandapterQ.sync(flags: .barrier) { __maxDbm = newValue } } }
    
    fileprivate var _minBw: Int {
        get { return _pandapterQ.sync { __minBw } }
        set { _pandapterQ.sync(flags: .barrier) { __minBw = newValue } } }
    
    fileprivate var _minDbm: CGFloat {
        get { return _pandapterQ.sync { __minDbm } }
        set { _pandapterQ.sync(flags: .barrier) { __minDbm = newValue } } }
    
    fileprivate var _panDimensions: CGSize {
        get { return _pandapterQ.sync { __panDimensions } }
        set { _pandapterQ.sync(flags: .barrier) { __panDimensions = newValue } } }
    
    fileprivate var _preamp: String {
        get { return _pandapterQ.sync { __preamp } }
        set { _pandapterQ.sync(flags: .barrier) { __preamp = newValue } } }
    
    fileprivate var _rfGain: Int {
        get { return _pandapterQ.sync { __rfGain } }
        set { _pandapterQ.sync(flags: .barrier) { __rfGain = newValue } } }
    
    fileprivate var _rfGainHigh: Int {
        get { return _pandapterQ.sync { __rfGainHigh } }
        set { _pandapterQ.sync(flags: .barrier) { __rfGainHigh = newValue } } }
    
    fileprivate var _rfGainLow: Int {
        get { return _pandapterQ.sync { __rfGainLow } }
        set { _pandapterQ.sync(flags: .barrier) { __rfGainLow = newValue } } }
    
    fileprivate var _rfGainStep: Int {
        get { return _pandapterQ.sync { __rfGainStep } }
        set { _pandapterQ.sync(flags: .barrier) { __rfGainStep = newValue } } }
    
    fileprivate var _rfGainValues: String {
        get { return _pandapterQ.sync { __rfGainValues } }
        set { _pandapterQ.sync(flags: .barrier) { __rfGainValues = newValue } } }
    
    fileprivate var _rxAnt: String {
        get { return _pandapterQ.sync { __rxAnt } }
        set { _pandapterQ.sync(flags: .barrier) { __rxAnt = newValue } } }
    
    fileprivate var _waterfallId: String {
        get { return _pandapterQ.sync { __waterfallId } }
        set { _pandapterQ.sync(flags: .barrier) { __waterfallId = newValue } } }
    
    fileprivate var _weightedAverageEnabled: Bool {
        get { return _pandapterQ.sync { __weightedAverageEnabled } }
        set { _pandapterQ.sync(flags: .barrier) { __weightedAverageEnabled = newValue } } }
    
    fileprivate var _wide: Bool {
        get { return _pandapterQ.sync { __wide } }
        set { _pandapterQ.sync(flags: .barrier) { __wide = newValue } } }
    
    fileprivate var _wnbEnabled: Bool {
        get { return _pandapterQ.sync { __wnbEnabled } }
        set { _pandapterQ.sync(flags: .barrier) { __wnbEnabled = newValue } } }
    
    fileprivate var _wnbLevel: Int {
        get { return _pandapterQ.sync { __wnbLevel } }
        set { _pandapterQ.sync(flags: .barrier) { __wnbLevel = newValue } } }
    
    fileprivate var _wnbUpdating: Bool {
        get { return _pandapterQ.sync { __wnbUpdating } }
        set { _pandapterQ.sync(flags: .barrier) { __wnbUpdating = newValue } } }
    
    fileprivate var _xvtrLabel: String {
        get { return _pandapterQ.sync { __xvtrLabel } }
        set { _pandapterQ.sync(flags: .barrier) { __xvtrLabel = newValue } } }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant with Radio update
    
    // listed in alphabetical order
    dynamic public var antList: [String] {
        get { return _antList }
        set { _antList = newValue } }
    
    dynamic public var autoCenterEnabled: Bool {
        get { return _autoCenterEnabled }
        set { _autoCenterEnabled = newValue } }
    
    dynamic public var available: Int {
        get { return _available }
        set { _available = newValue } }
    
    dynamic public var average: Int {
        get { return _average }
        set {if _average != newValue { _average = newValue ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) average=\(newValue)") } } }
    
    dynamic public var band: String {
        get { return _band }
        set { if _band != newValue { _band = newValue ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) band=\(newValue)") } } }
    
    dynamic public var bandwidth: Int {
        get { return _bandwidth }
        set { if _bandwidth != newValue { _bandwidth = newValue ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) bandwidth=\(newValue.hzToMhz()) autocenter=\(autoCenterEnabled.asNumber())") } } }
    
    dynamic public var capacity: Int {
        get { return _capacity }
        set { _capacity = newValue } }
    
    dynamic public var center: Int {
        get { return _center }
        set { if _center != newValue { _center = newValue ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) center=\(newValue.hzToMhz())") } } }
    
    dynamic public var daxIqChannel: Int {
        get { return _daxIqChannel }
        set { if _daxIqChannel != newValue { _daxIqChannel = newValue ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) daxiq=\(newValue)") } } }
    
    dynamic public var daxIqRate: Int {
        get { return _daxIqRate }
        set { if _daxIqRate != newValue { _daxIqRate = newValue ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) daxiq_rate=\(newValue)") } } }
    
    dynamic public var fps: Int {
        get { return _fps }
        set { if _fps != newValue { _fps = newValue ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) fps=\(newValue)") } } }
    
    dynamic public var loopAEnabled: Bool {
        get { return _loopAEnabled }
        set { if _loopAEnabled != newValue { _loopAEnabled = newValue ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) loopa=\(newValue.asNumber())") } } }
    
    dynamic public var loopBEnabled: Bool {
        get { return _loopBEnabled }
        set { if _loopBEnabled != newValue { _loopBEnabled = newValue ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) loopb=\(newValue.asNumber())") } } }
    
    dynamic public var maxBw: Int {
        get { return _maxBw }
        set { if _maxBw != newValue { _maxBw = newValue } } }
    
    dynamic public var maxDbm: CGFloat {
        get { return _maxDbm }
        set { let value = newValue > 20.0 ? 20.0 : newValue ; if _maxDbm != value { _maxDbm = value ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) max_dbm=\(value)") } } }
    
    dynamic public var minBw: Int {
        get { return _minBw }
        set { if _minBw != newValue { _minBw = newValue } } }
    
    dynamic public var minDbm: CGFloat {
        get { return _minDbm }
        set { let value  = newValue < -180.0 ? -180.0 : newValue ; if _minDbm != value { _minDbm = value ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) min_dbm=\(value)") } } }
    
    dynamic public var panDimensions: CGSize {
        get { return _panDimensions }
        set { if _panDimensions != newValue { _panDimensions = newValue ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) xpixels=\(newValue.width) ypixels=\(newValue.height)") } } }
    
    dynamic public var preamp: String {
        get { return _preamp }
        set { _preamp = newValue } }
    
    dynamic public var rfGain: Int {
        get { return _rfGain }
        set { if _rfGain != newValue { _rfGain = newValue ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) rfgain=\(newValue)") } } }
    
    dynamic public var rfGainHigh: Int {
        get { return _rfGainHigh }
        set { _rfGainHigh = newValue } }
    
    dynamic public var rfGainLow: Int {
        get { return _rfGainLow }
        set { _rfGainLow = newValue } }
    
    dynamic public var rfGainStep: Int {
        get { return _rfGainStep }
        set { _rfGainStep = newValue } }
    
    dynamic public var rfGainValues: String {
        get { return _rfGainValues }
        set { _rfGainValues = newValue } }
    
    dynamic public var rxAnt: String {
        get { return _rxAnt }
        set { if _rxAnt != newValue { _rxAnt = newValue ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) rxant=\(newValue)") } } }
    
    dynamic public var waterfallId: String {
        get { return _waterfallId }
        set { _waterfallId = newValue } }
    
    dynamic public var weightedAverageEnabled: Bool {
        get { return _weightedAverageEnabled }
        set { if _weightedAverageEnabled != newValue { _weightedAverageEnabled = newValue ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) weighted_average=" + newValue.asNumber()) } } }
    
    dynamic public var wide: Bool {
        get { return _wide }
        set { _wide = newValue } }
    
    dynamic public var wnbEnabled: Bool {
        get { return _wnbEnabled }
        set { if _wnbEnabled != newValue { _wnbEnabled = newValue ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) wnb=\(newValue.asNumber())") } } }
    
    dynamic public var wnbLevel: Int {
        get { return _wnbLevel }
        set { if _wnbLevel != newValue { _wnbLevel = newValue ; radio!.send(kDisplayPanafallSetCmd + "0x\(id) wnb_level=\(newValue)") } } }
    
    dynamic public var wnbUpdating: Bool {
        get { return _wnbUpdating }
        set { _wnbUpdating = newValue } }
    
    dynamic public var xvtrLabel: String {
        get { return _xvtrLabel }
        set { _xvtrLabel = newValue } }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - NON KVO compliant Setters / Getters with synchronization
    
    public var delegate: PanadapterStreamHandler? {
        get { return _pandapterQ.sync { _delegate } }
        set { _pandapterQ.sync(flags: .barrier) { _delegate = newValue } } }
    
    // ----------------------------------------------------------------------------
    // Mark: - Tokens for Panadapter messages (only populate values that != case value)
    
    internal enum Token : String {
        case antList = "ant_list"
        case available
        case average
        case band
        case bandwidth
        case capacity
        case center
        case daxIqChannel = "daxiq"
        case daxIqRate = "daxiq_rate"
        case fps
        case loopAEnabled = "loopa"
        case loopBEnabled = "loopb"
        case maxBw = "max_bw"
        case maxDbm = "max_dbm"
        case minBw = "min_bw"
        case minDbm = "min_dbm"
        case preamp = "pre"
        case rfGain = "rfgain"
        case rxAnt = "rxant"
        case waterfallId = "waterfall"
        case weightedAverageEnabled = "weighted_average"
        case wide
        case wnbEnabled = "wnb"
        case wnbLevel = "wnb_level"
        case wnbUpdating = "wnb_updating"
        case xPixels = "x_pixels"
        case xvtrLabel = "xvtr"
        case yPixels = "y_pixels"
    }

}
