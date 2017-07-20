//
//  Slice.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 6/2/15.
//  Copyright (c) 2015 Douglas Adams, K3TZR
//

import Foundation

// ------------------------------------------------------------------------------
// MARK: - Slice Class implementation
//
//      creates a Slice instance to be used by a Client to support the
//      rendering of a Slice
//
// ------------------------------------------------------------------------------

public final class Slice : NSObject, KeyValueParser {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    public private(set) var id = ""                         // Id that uniquely identifies this Slice
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    internal var _radio: Radio?                             // The Radio that owns this Slice
    internal let kAudioClientCommand = "audio client 0 slice "   // command prefixes
    internal let kFilterCommand = "filt "
    internal let kSliceCommand = "slice "
    internal let kSliceSetCommand = "slice set "
    internal let kSliceTuneCommand = "slice tune "
    internal let kMinLevel = 0                              // control range
    internal let kMaxLevel = 100
    internal let kMinOffset = -99_999                       // frequency offset range
    internal let kMaxOffset = 99_999
    internal let kNoError = "0"                             // response without error
    internal let kTuneStepList =                            // tuning steps
        [1, 10, 50, 100, 500, 1_000, 2_000, 3_000]
    internal var _diversityIsAllowed: Bool
        { return _radio?.selectedRadio?.model == "FLEX-6700" || _radio?.selectedRadio?.model == "FLEX-6700R" }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _sliceQ: DispatchQueue                  // GCD queue that guards this object
    fileprivate var _initialized = false                    // True if initialized by Radio (hardware)
    fileprivate let _log = Log.sharedInstance               // shared Log
    
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    //                                                                                                  //
    fileprivate var _meters = [String: Meter]()         // Dictionary of Meters (on this Slice)         //
                                                                                                        //
    fileprivate var __daxClients = 0                    // DAX clients for this slice                   //
                                                                                                        //
    fileprivate var __active = false                    //                                              //
    fileprivate var __agcMode = AgcMode.off.rawValue    //                                              //
    fileprivate var __agcOffLevel = 0                   // Slice AGC Off level                          //
    fileprivate var __agcThreshold = 0                  //                                              //
    fileprivate var __anfEnabled = false                //                                              //
    fileprivate var __anfLevel = 0                      //                                              //
    fileprivate var __apfEnabled = false                //                                              //
    fileprivate var __apfLevel = 0                      // DSP APF Level (0 - 100)                      //
    fileprivate var __audioGain = 0                     // Slice audio gain (0 - 100)                   //
    fileprivate var __audioMute = false                 // State of slice audio MUTE                    //
    fileprivate var __audioPan = 50                     // Slice audio pan (0 - 100)                    //
    fileprivate var __daxChannel = 0                    // DAX channel for this slice (1-8)             //
    fileprivate var __daxTxEnabled = false              // DAX for transmit                             //
    fileprivate var __dfmPreDeEmphasisEnabled = false   //                                              //
    fileprivate var __digitalLowerOffset = 0            //                                              //
    fileprivate var __digitalUpperOffset = 0            //                                              //
    fileprivate var __diversityChild = false            // Slice is the child of the pair               //
    fileprivate var __diversityEnabled = false          // Slice is part of a diversity pair            //
    fileprivate var __diversityIndex = 0                // Slice number of the other slice              //
    fileprivate var __diversityParent = false           // Slice is the parent of the pair              //
    fileprivate var __filterHigh = 0                    // RX filter high frequency                     //
    fileprivate var __filterLow = 0                     // RX filter low frequency                      //
    fileprivate var __fmDeviation = 0                   // FM deviation                                 //
    fileprivate var __fmRepeaterOffset: Float = 0.0     // FM repeater offset                           //
    fileprivate var __fmToneBurstEnabled = false        // FM tone burst                                //
    fileprivate var __fmToneFreq: Float = 0.0           // FM CTCSS tone frequency                      //
    fileprivate var __fmToneMode: String = ""           // FM CTCSS tone mode (ON | OFF)                //
    fileprivate var __frequency = 0                     // Slice frequency in Hz                        //
    fileprivate var __inUse = false                     // True = being used                            //
    fileprivate var __locked = false                    // Slice frequency locked                       //
    fileprivate var __loopAEnabled = false              // Loop A enable                                //
    fileprivate var __loopBEnabled = false              // Loop B enable                                //
    fileprivate var __mode = Mode.lsb.rawValue          // Slice mode                                   //
    fileprivate var __modeList = [String]()             // Array of Strings with available modes        //
    fileprivate var __nbEnabled = false                 // State of DSP Noise Blanker                   //
    fileprivate var __nbLevel = 0                       // DSP Noise Blanker level (0 -100)             //
    fileprivate var __nrEnabled = false                 // State of DSP Noise Reduction                 //
    fileprivate var __nrLevel = 0                       // DSP Noise Reduction level (0 - 100)          //
    fileprivate var __owner = 0                         // Slice owner - RESERVED for FUTURE use        //
    fileprivate var __panadapterId = ""                 // Panadaptor StreamID for this slice           //
    fileprivate var __playbackEnabled = false           // Quick playback enable                        //
    fileprivate var __postDemodBypassEnabled = false    //                                              //
    fileprivate var __postDemodHigh = 0                 //                                              //
    fileprivate var __postDemodLow = 0                  //                                              //
    fileprivate var __qskEnabled = false                // QSK capable on slice                         //
    fileprivate var __recordEnabled = false             // Quick record enable                          //
    fileprivate var __recordLength: Float = 0.0         // Length of quick recording (seconds)          //
    fileprivate var __repeaterOffsetDirection = RepeaterOffsetDirection.simplex.rawValue // Repeater offset direction (DOWN, UP, SIMPLEX)
    fileprivate var __rfGain = 0                        // RF Gain                                      //
    fileprivate var __ritEnabled = false                // RIT enabled                                  //
    fileprivate var __ritOffset = 0                     // RIT offset value                             //
    fileprivate var __rttyMark = 0                      // Rtty Mark                                    //
    fileprivate var __rttyShift = 0                     // Rtty Shift                                   //
    fileprivate var __rxAnt = ""                        // RX Antenna port for this slice               //
    fileprivate var __rxAntList = [String]()            // Array of available Antenna ports             //
    fileprivate var __step = 0                          // Frequency step value                         //
    fileprivate var __squelchEnabled = false            // Squelch enabled                              //
    fileprivate var __squelchLevel = 0                  // Squelch level (0 - 100)                      //
    fileprivate var __stepList = ""                     // Available Step values                        //
    fileprivate var __txAnt: String = ""                // TX Antenna port for this slice               //
    fileprivate var __txEnabled = false                 // TX on ths slice frequency/mode               //
    fileprivate var __txOffsetFreq: Float = 0.0         // TX Offset Frequency                          //
    fileprivate var __wide = false                      // State of slice bandpass filter               //
    fileprivate var __wnbEnabled = false                // Wideband noise blanking enabled              //
    fileprivate var __wnbLevel = 0                      // Wideband noise blanking level                //
    fileprivate var __xitEnabled = false                // XIT enable                                   //
    fileprivate var __xitOffset = 0                     // XIT offset value                             //
    //                                                                                                  //
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    /// Initialize a Slice
    ///
    /// - Parameters:
    ///   - radio: parent Radio class
    ///   - sliceId: a Slice Id
    ///   - queue: Slice concurrent queue
    ///
    public init(radio: Radio, sliceId: String, queue: DispatchQueue) {
        self._radio = radio;
        self.id = sliceId
        
        self._sliceQ = queue
        
        super.init()
        
        // setup the Step List
        var stepListString = kTuneStepList.reduce("") {start , value in "\(start), \(String(describing: value))" }
        stepListString = String(stepListString.characters.dropLast())
        _stepList = stepListString
    
        // set filterLow & filterHigh to default values
        setupDefaultFilters(_mode)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods that send commands to the Radio (hardware)
    
    public func setRecord(_ value: Bool) { _radio?.send(kSliceSetCommand + "\(id) record=\(value.asNumber())") }
    public func setPlay(_ value: Bool) { _radio?.send(kSliceSetCommand + "\(id) play=\(value.asNumber())") }

    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    /// Add a Meter to this Slice's Meters collection
    ///
    /// - Parameters:
    ///   - meter:      a reference to a Meter
    ///
    func addMeter(_ meter: Meter) {
        meters[meter.id] = meter
    }
    /// Remove a Meter from this Slice's Meters collection
    ///
    /// - Parameters:
    ///   - meter:      a reference to a Meter
    ///
    func removeMeter(_ id: Radio.MeterId) {
        meters[id] = nil
    }
    /// Set the default Filter widths
    ///
    /// - Parameters:
    ///   - mode:       demod mode
    ///
    func setupDefaultFilters(_ mode: String) {
        
        if let modeValue = Mode(rawValue: mode) {
            
            switch modeValue {
                
            case .cw:
                _filterLow = 450
                _filterHigh = 750
                
            case .rtty:
                _filterLow = -285
                _filterHigh = 115
                
            case .dsb:
                _filterLow = -2_400
                _filterHigh = 2_400
                
            case .am, .sam:
                _filterLow = -3_000
                _filterHigh = 3_000
                
            case .fm, .nfm, .dfm, .dstr:
                _filterLow = -8_000
                _filterHigh = 8_000
                
            case .lsb, .digl:
                _filterLow = -2_400
                _filterHigh = -300
                
            case .usb, .digu, .fdv:
                _filterLow = 300
                _filterHigh = 2_400
            }
        }
    }
    /// Restrict the Filter High value
    ///
    /// - Parameters:
    ///   - value:          the value
    /// - Returns:          adjusted value
    ///
    func filterHighLimits(_ value: Int) -> Int {
        
        var newValue = (value < filterLow + 10 ? filterLow + 10 : value)
        
        if let modeType = Mode(rawValue: mode.lowercased()) {
            switch modeType {
            
            case .fm, .nfm:
                _log.msg("Cannot change Filter width in FM mode", level: .warning, function: #function, file: #file, line: #line)
                newValue = value
                
            case .cw:
                newValue = (newValue > 12_000 - _radio!.cwPitch ? 12_000 - _radio!.cwPitch : newValue)
                
            case .rtty:
                newValue = (newValue > rttyMark ? rttyMark : newValue)
                newValue = (newValue < 50 ? 50 : newValue)
                
            case .dsb, .am, .sam, .dfm, .dstr:
                newValue = (newValue > 12_000 ? 12_000 : newValue)
                newValue = (newValue < 10 ? 10 : newValue)
                
            case .lsb, .digl:
                newValue = (newValue > 0 ? 0 : newValue)
                
            case .usb, .digu, .fdv:
                newValue = (newValue > 12_000 ? 12_000 : newValue)
            }
        }
        return newValue
    }
    /// Restrict the Filter Low value
    ///
    /// - Parameters:
    ///   - value:          the value
    /// - Returns:          adjusted value
    ///
    func filterLowLimits(_ value: Int) -> Int {
        
        var newValue = (value > filterHigh - 10 ? filterHigh - 10 : value)
        
        if let modeType = Mode(rawValue: mode.lowercased()) {
            switch modeType {
                
            case .fm, .nfm:
                _log.msg("Cannot change Filter width in FM mode", level: .warning, function: #function, file: #file, line: #line)
                newValue = value
                
            case .cw:
                newValue = (newValue < -12_000 - _radio!.cwPitch ? -12_000 - _radio!.cwPitch : newValue)
                
            case .rtty:
                newValue = (newValue < -12_000 + rttyMark ? -12_000 + rttyMark : newValue)
                newValue = (newValue > -(50 + rttyShift) ? -(50 + rttyShift) : newValue)
                
            case .dsb, .am, .sam, .dfm, .dstr:
                newValue = (newValue < -12_000 ? -12_000 : newValue)
                newValue = (newValue > -10 ? -10 : newValue)
                
            case .lsb, .digl:
                newValue = (newValue < -12_000 ? -12_000 : newValue)
                
            case .usb, .digu, .fdv:
                newValue = (newValue < 0 ? 0 : newValue)
            }
        }
        return newValue
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Reply Handler methods
    
    
    // ----------------------------------------------------------------------------
    // MARK: - RadioParser Protocol methods
    //     called by Radio, executes on the radioQ
    
    /// Parse Slice key/value pairs
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///
    func parseKeyValues(_ keyValues: Radio.KeyValuesArray) {
        
        // process each key/value pair, <key=value>
        for kv in keyValues {
            
            // check for unknown keys
            guard let token = SliceToken(rawValue: kv.key.lowercased()) else {
                // unknown Key, log it and ignore the Key
                _log.msg("Unknown token - \(kv.key)", level: .debug, function: #function, file: #file, line: #line)
                continue
            }
            // get the Int, Bool and Float versions of the value
            let iValue = kv.value.iValue()
            let bValue = kv.value.bValue()
            let fValue = kv.value.fValue()
            
            // Known keys, in alphabetical order
            switch token {
                
            case .active:
                willChangeValue(forKey: "active")
                _active = bValue
                didChangeValue(forKey: "active")
            
            case .agcMode:
                willChangeValue(forKey: "agcMode")
                _agcMode = kv.value
                didChangeValue(forKey: "agcMode")
            
            case .agcOffLevel:
                willChangeValue(forKey: "agcOffLevel")
                _agcOffLevel = iValue
                didChangeValue(forKey: "agcOffLevel")
            
            case .agcThreshold:
                willChangeValue(forKey: "agcThreshold")
                _agcThreshold = iValue
                didChangeValue(forKey: "agcThreshold")
            
            case .anfEnabled:
                willChangeValue(forKey: "anfEnabled")
                _anfEnabled = bValue
                didChangeValue(forKey: "anfEnabled")
            
            case .anfLevel:
                willChangeValue(forKey: "anfLevel")
                _anfLevel = iValue
                didChangeValue(forKey: "anfLevel")
            
            case .apfEnabled:
                willChangeValue(forKey: "apfEnabled")
                _apfEnabled = bValue
                didChangeValue(forKey: "apfEnabled")
            
            case .apfLevel:
                willChangeValue(forKey: "apfLevel")
                _apfLevel = iValue
                didChangeValue(forKey: "apfLevel")
            
            case .audioGain:
                willChangeValue(forKey: "audioGain")
                _audioGain = iValue
                didChangeValue(forKey: "audioGain")
            
            case .audioMute:
                willChangeValue(forKey: "audioMute")
                _audioMute = bValue
                didChangeValue(forKey: "audioMute")
            
            case .audioPan:
                willChangeValue(forKey: "audioPan")
                _audioPan = iValue
                didChangeValue(forKey: "audioPan")
            
            case .daxChannel:
                willChangeValue(forKey: "daxChannel")
                _daxChannel = iValue
                didChangeValue(forKey: "daxChannel")
            
            case .daxTxEnabled:
                willChangeValue(forKey: "daxTxEnabled")
                _daxTxEnabled = bValue
                didChangeValue(forKey: "daxTxEnabled")
            
            case .dfmPreDeEmphasisEnabled:
                willChangeValue(forKey: "dfmPreDeEmphasisEnabled")
                _dfmPreDeEmphasisEnabled = bValue
                didChangeValue(forKey: "dfmPreDeEmphasisEnabled")
            
            case .digitalLowerOffset:
                willChangeValue(forKey: "digitalLowerOffset")
                _digitalLowerOffset = iValue
                didChangeValue(forKey: "digitalLowerOffset")
            
            case .digitalUpperOffset:
                willChangeValue(forKey: "digitalUpperOffset")
                _digitalUpperOffset = iValue
                didChangeValue(forKey: "digitalUpperOffset")
            
            case .diversityEnabled:
                willChangeValue(forKey: "diversityEnabled")
                _diversityEnabled = bValue
                didChangeValue(forKey: "diversityEnabled")
            
            case .diversityChild:
                willChangeValue(forKey: "diversityChild")
                _diversityChild = bValue
                didChangeValue(forKey: "diversityChild")
            
            case .diversityIndex:
                willChangeValue(forKey: "diversityIndex")
                _diversityIndex = iValue
                didChangeValue(forKey: "diversityIndex")
                
            case .filterHigh:
                willChangeValue(forKey: "filterHigh")
                _filterHigh = iValue
                didChangeValue(forKey: "filterHigh")

            case .filterLow:
                willChangeValue(forKey: "filterLow")
                _filterLow = iValue
                didChangeValue(forKey: "filterLow")
            
            case .fmDeviation:
                willChangeValue(forKey: "fmDeviation")
                _fmDeviation = iValue
                didChangeValue(forKey: "fmDeviation")
                
            case .fmRepeaterOffset:
                willChangeValue(forKey: "fmRepeaterOffset")
                _fmRepeaterOffset = fValue
                didChangeValue(forKey: "fmRepeaterOffset")
            
            case .fmToneBurstEnabled:
                willChangeValue(forKey: "fmToneBurstEnabled")
                _fmToneBurstEnabled = bValue
                didChangeValue(forKey: "fmToneBurstEnabled")
            
            case .fmToneMode:
                willChangeValue(forKey: "fmToneMode")
                _fmToneMode = kv.value
                didChangeValue(forKey: "fmToneMode")
            
            case .fmToneFreq:
                willChangeValue(forKey: "fmToneFreq")
                _fmToneFreq = fValue
                didChangeValue(forKey: "fmToneFreq")
            
            case .frequency:
                willChangeValue(forKey: "frequency")
                _frequency = kv.value.mhzToHz()
                didChangeValue(forKey: "frequency")
            
            case .ghost:
                // FIXME: Is this needed?
                _log.msg("Unknown token - \(kv.key)", level: .debug, function: #function, file: #file, line: #line)
            
            case .inUse:
                willChangeValue(forKey: "inUse")
                _inUse = bValue
                didChangeValue(forKey: "inUse")
            
            case .locked:
                willChangeValue(forKey: "locked")
                _locked = bValue
                didChangeValue(forKey: "locked")
            
            case .loopAEnabled:
                willChangeValue(forKey: "loopAEnabled")
                _loopAEnabled = bValue
                didChangeValue(forKey: "loopAEnabled")
            
            case .loopBEnabled:
                willChangeValue(forKey: "loopBEnabled")
                _loopBEnabled = bValue
                didChangeValue(forKey: "loopBEnabled")
            
            case .mode:
                willChangeValue(forKey: "mode")
                _mode = kv.value
                didChangeValue(forKey: "mode")
            
            case .modeList:
                willChangeValue(forKey: "modeList")
                _modeList = kv.value.components(separatedBy: ",")
                didChangeValue(forKey: "modeList")
            
            case .nbEnabled:
                willChangeValue(forKey: "nbEnabled")
                _nbEnabled = bValue
                didChangeValue(forKey: "nbEnabled")
            
            case .nbLevel:
                willChangeValue(forKey: "nbLevel")
                _nbLevel = iValue
                didChangeValue(forKey: "nbLevel")
            
            case .nrEnabled:
                willChangeValue(forKey: "nrEnabled")
                _nrEnabled = bValue
                didChangeValue(forKey: "nrEnabled")
            
            case .nrLevel:
                willChangeValue(forKey: "nrLevel")
                _nrLevel = iValue
                didChangeValue(forKey: "nrLevel")
            
            case .owner:
                willChangeValue(forKey: "owner")
                _owner = iValue
                didChangeValue(forKey: "owner")
            
            case .panadapterId:
                //get the streamId (remove the "0x" prefix)
                willChangeValue(forKey: "panadapterId")
                _panadapterId = String(kv.value.characters.dropFirst(2))
                didChangeValue(forKey: "panadapterId")
            
            case .playbackEnabled:
                willChangeValue(forKey: "playbackEnabled")
                _playbackEnabled = (kv.value == "enabled") || (kv.value == "1")
                didChangeValue(forKey: "playbackEnabled")
            
            case .postDemodBypassEnabled:
                willChangeValue(forKey: "postDemodBypassEnabled")
                _postDemodBypassEnabled = bValue
                didChangeValue(forKey: "postDemodBypassEnabled")
            
            case .postDemodLow:
                willChangeValue(forKey: "postDemodLow")
                _postDemodLow = iValue
                didChangeValue(forKey: "postDemodLow")
            
            case .postDemodHigh:
                willChangeValue(forKey: "postDemodHigh")
                _postDemodHigh = iValue
                didChangeValue(forKey: "postDemodHigh")
            
            case .qskEnabled:
                willChangeValue(forKey: "qskEnabled")
                _qskEnabled = bValue
                didChangeValue(forKey: "qskEnabled")
            
            case .recordEnabled:
                willChangeValue(forKey: "recordEnabled")
                _recordEnabled = bValue
                didChangeValue(forKey: "recordEnabled")
            
            case .repeaterOffsetDirection:
                willChangeValue(forKey: "repeaterOffsetDirection")
                _repeaterOffsetDirection = kv.value
                didChangeValue(forKey: "repeaterOffsetDirection")
            
            case .rfGain:
                willChangeValue(forKey: "rfGain")
                _rfGain = iValue
                didChangeValue(forKey: "rfGain")
                
            case .ritOffset:
                willChangeValue(forKey: "ritOffset")
                _ritOffset = iValue
                didChangeValue(forKey: "ritOffset")
            
            case .ritEnabled:
                willChangeValue(forKey: "ritEnabled")
                _ritEnabled = bValue
                didChangeValue(forKey: "ritEnabled")
            
            case .rttyMark:
                willChangeValue(forKey: "rttyMark")
                _rttyMark = iValue
                didChangeValue(forKey: "rttyMark")
            
            case .rttyShift:
                willChangeValue(forKey: "rttyShift")
                _rttyShift = iValue
                didChangeValue(forKey: "rttyShift")
                
            case .rxAnt:
                willChangeValue(forKey: "rxAnt")
                _rxAnt = kv.value
                didChangeValue(forKey: "rxAnt")
            
            case .rxAntList:
                willChangeValue(forKey: "rxAntList")
                _rxAntList = kv.value.components(separatedBy: ",")
                didChangeValue(forKey: "rxAntList")
                
            case .squelchEnabled:
                willChangeValue(forKey: "squelchEnabled")
                _squelchEnabled = bValue
                didChangeValue(forKey: "squelchEnabled")
            
            case .squelchLevel:
                willChangeValue(forKey: "squelchLevel")
                _squelchLevel = iValue
                didChangeValue(forKey: "squelchLevel")
            
            case .step:
                willChangeValue(forKey: "step")
                _step = iValue
                didChangeValue(forKey: "step")
            
            case .stepList:
                willChangeValue(forKey: "stepList")
                _stepList = kv.value
                didChangeValue(forKey: "stepList")
            
            case .txEnabled:
                
                //                // disable all TX
                //                _radio?.disableTx()
                
                // enable it on this Slice
                willChangeValue(forKey: "txEnabled")
                _txEnabled = bValue
                didChangeValue(forKey: "txEnabled")
                
            case .txAnt:
                willChangeValue(forKey: "txAnt")
                _txAnt = kv.value
                didChangeValue(forKey: "txAnt")
                
            case .txOffsetFreq:
                willChangeValue(forKey: "txOffsetFreq")
                _txOffsetFreq = fValue
                didChangeValue(forKey: "txOffsetFreq")
                
            case .wide:
                willChangeValue(forKey: "wide")
                _wide = bValue
                didChangeValue(forKey: "wide")
                
            case .wnbEnabled:
                willChangeValue(forKey: "wnbEnabled")
                _wnbEnabled = bValue
                didChangeValue(forKey: "wnbEnabled")
                
            case .wnbLevel:
                willChangeValue(forKey: "wnbLevel")
                _wnbLevel = iValue
                didChangeValue(forKey: "wnbLevel")
                
            case .xitOffset:
                willChangeValue(forKey: "xitOffset")
                _xitOffset = iValue
                didChangeValue(forKey: "xitOffset")
                
            case .xitEnabled:
                willChangeValue(forKey: "xitEnabled")
                _xitEnabled = bValue
                didChangeValue(forKey: "xitEnabled")
                
            case .daxClients, .diversityParent, .recordTime:
                // ignore these
                break
            }
        }
        // if this is not yet initialized and inUse becomes true and panadapterId & frequency are set
        if _initialized == false && inUse == true && panadapterId != "" && frequency != 0 && mode != "" {
            
            // mark it as initialized
            _initialized = true
            
            // notify all observers
            NC.post(.sliceHasBeenAdded, object: self)
        }
    }
}

// --------------------------------------------------------------------------------
// MARK: - Slice Class extensions
//              - Synchronized internal properties
//              - Public properties, no message to Radio
//              - Slice related enums
// --------------------------------------------------------------------------------

extension xFlexAPI.Slice {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties - with synchronization
    
    // listed in alphabetical order
    internal var _active: Bool {
        get { return _sliceQ.sync { __active } }
        set { _sliceQ.sync(flags: .barrier) {__active = newValue } } }
    
    internal var _agcMode: String {
        get { return _sliceQ.sync { __agcMode } }
        set { _sliceQ.sync(flags: .barrier) { __agcMode = newValue } } }
    
    internal var _agcOffLevel: Int {
        get { return _sliceQ.sync { __agcOffLevel } }
        set { _sliceQ.sync(flags: .barrier) { __agcOffLevel = newValue } } }
    
    internal var _agcThreshold: Int {
        get { return _sliceQ.sync { __agcThreshold } }
        set { _sliceQ.sync(flags: .barrier) { __agcThreshold = newValue } } }
    
    internal var _anfEnabled: Bool {
        get { return _sliceQ.sync { __anfEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __anfEnabled = newValue } } }
    
    internal var _anfLevel: Int {
        get { return _sliceQ.sync { __anfLevel } }
        set { _sliceQ.sync(flags: .barrier) { __anfLevel = newValue } } }
    
    internal var _apfEnabled: Bool {
        get { return _sliceQ.sync { __apfEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __apfEnabled = newValue } } }
    
    internal var _apfLevel: Int {
        get { return _sliceQ.sync { __apfLevel } }
        set { _sliceQ.sync(flags: .barrier) { __apfLevel = newValue } } }
    
    internal var _audioGain: Int {
        get { return _sliceQ.sync { __audioGain } }
        set { _sliceQ.sync(flags: .barrier) { __audioGain = newValue } } }
    
    internal var _audioMute: Bool {
        get { return _sliceQ.sync { __audioMute } }
        set { _sliceQ.sync(flags: .barrier) { __audioMute = newValue } } }
    
    internal var _audioPan: Int {
        get { return _sliceQ.sync { __audioPan } }
        set { _sliceQ.sync(flags: .barrier) { __audioPan = newValue } } }
    
    internal var _daxChannel: Int {
        get { return _sliceQ.sync { __daxChannel } }
        set { _sliceQ.sync(flags: .barrier) { __daxChannel = newValue } } }
    
    internal var _daxClients: Int {
        get { return _sliceQ.sync { __daxClients } }
        set { _sliceQ.sync(flags: .barrier) { __daxClients = newValue } } }
    
    internal var _dfmPreDeEmphasisEnabled: Bool {
        get { return _sliceQ.sync { __dfmPreDeEmphasisEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __dfmPreDeEmphasisEnabled = newValue } } }
    
    internal var _daxTxEnabled: Bool {
        get { return _sliceQ.sync { __daxTxEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __daxTxEnabled = newValue } } }
    
    internal var _digitalLowerOffset: Int {
        get { return _sliceQ.sync { __digitalLowerOffset } }
        set { _sliceQ.sync(flags: .barrier) { __digitalLowerOffset = newValue } } }
    
    internal var _digitalUpperOffset: Int {
        get { return _sliceQ.sync { __digitalUpperOffset } }
        set { _sliceQ.sync(flags: .barrier) { __digitalUpperOffset = newValue } } }
    
    internal var _diversityChild: Bool {
        get { return _sliceQ.sync { __diversityChild } }
        set { _sliceQ.sync(flags: .barrier) { __diversityChild = newValue } } }
    
    internal var _diversityEnabled: Bool {
        get { return _sliceQ.sync { __diversityEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __diversityEnabled = newValue } } }
    
    internal var _diversityIndex: Int {
        get { return _sliceQ.sync { __diversityIndex } }
        set { _sliceQ.sync(flags: .barrier) { __diversityIndex = newValue } } }
    
    internal var _diversityParent: Bool {
        get { return _sliceQ.sync { __diversityParent } }
        set { _sliceQ.sync(flags: .barrier) { __diversityParent = newValue } } }
    
    internal var _filterHigh: Int {
        get { return _sliceQ.sync { __filterHigh } }
        set { _sliceQ.sync(flags: .barrier) { __filterHigh = newValue } } }
    
    internal var _filterLow: Int {
        get { return _sliceQ.sync { __filterLow } }
        set {_sliceQ.sync(flags: .barrier) { __filterLow = newValue } } }
    
    internal var _fmDeviation: Int {
        get { return _sliceQ.sync { __fmDeviation } }
        set { _sliceQ.sync(flags: .barrier) { __fmDeviation = newValue } } }
    
    internal var _fmRepeaterOffset: Float {
        get { return _sliceQ.sync { __fmRepeaterOffset } }
        set { _sliceQ.sync(flags: .barrier) { __fmRepeaterOffset = newValue } } }
    
    internal var _fmToneBurstEnabled: Bool {
        get { return _sliceQ.sync { __fmToneBurstEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __fmToneBurstEnabled = newValue } } }
    
    internal var _fmToneFreq: Float {
        get { return _sliceQ.sync { __fmToneFreq } }
        set { _sliceQ.sync(flags: .barrier) { __fmToneFreq = newValue } } }
    
    internal var _fmToneMode: String {
        get { return _sliceQ.sync { __fmToneMode } }
        set { _sliceQ.sync(flags: .barrier) { __fmToneMode = newValue } } }
    
    internal var _frequency: Int {
        get { return _sliceQ.sync { __frequency } }
        set { _sliceQ.sync(flags: .barrier) { __frequency = newValue } } }
    
    internal var _inUse: Bool {
        get { return _sliceQ.sync { __inUse } }
        set { _sliceQ.sync(flags: .barrier) { __inUse = newValue } } }
    
    internal var _locked: Bool {
        get { return _sliceQ.sync { __locked } }
        set { _sliceQ.sync(flags: .barrier) { __locked = newValue } } }
    
    internal var _loopAEnabled: Bool {
        get { return _sliceQ.sync { __loopAEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __loopAEnabled = newValue } } }
    
    internal var _loopBEnabled: Bool {
        get { return _sliceQ.sync { __loopBEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __loopBEnabled = newValue } } }
    
    internal var _mode: String {
        get { return _sliceQ.sync { __mode } }
        set { _sliceQ.sync(flags: .barrier) { __mode = newValue } } }
    
    internal var _modeList: [String] {
        get { return _sliceQ.sync { __modeList } }
        set { _sliceQ.sync(flags: .barrier) { __modeList = newValue } } }
    
    internal var _nbEnabled: Bool {
        get { return _sliceQ.sync { __nbEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __nbEnabled = newValue } } }
    
    internal var _nbLevel: Int {
        get { return _sliceQ.sync { __nbLevel } }
        set { _sliceQ.sync(flags: .barrier) { __nbLevel = newValue } } }
    
    internal var _nrEnabled: Bool {
        get { return _sliceQ.sync { __nrEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __nrEnabled = newValue } } }
    
    internal var _nrLevel: Int {
        get { return _sliceQ.sync { __nrLevel } }
        set { _sliceQ.sync(flags: .barrier) { __nrLevel = newValue } } }
    
    internal var _owner: Int {
        get { return _sliceQ.sync { __owner } }
        set { _sliceQ.sync(flags: .barrier) { __owner = newValue } } }
    
    internal var _panadapterId: String {
        get { return _sliceQ.sync { __panadapterId } }
        set { _sliceQ.sync(flags: .barrier) { __panadapterId = newValue } } }
    
    internal var _panControl: Int {
        get { return _sliceQ.sync { __audioPan } }
        set { _sliceQ.sync(flags: .barrier) { __audioPan = newValue } } }
    
    internal var _playbackEnabled: Bool {
        get { return _sliceQ.sync { __playbackEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __playbackEnabled = newValue } } }
    
    internal var _postDemodBypassEnabled: Bool {
        get { return _sliceQ.sync { __postDemodBypassEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __postDemodBypassEnabled = newValue } } }
    
    internal var _postDemodHigh: Int {
        get { return _sliceQ.sync { __postDemodHigh } }
        set { _sliceQ.sync(flags: .barrier) { __postDemodHigh = newValue } } }
    
    internal var _postDemodLow: Int {
        get { return _sliceQ.sync { __postDemodLow } }
        set { _sliceQ.sync(flags: .barrier) { __postDemodLow = newValue } } }
    
    internal var _qskEnabled: Bool {
        get { return _sliceQ.sync { __qskEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __qskEnabled = newValue } } }
    
    internal var _recordEnabled: Bool {
        get { return _sliceQ.sync { __recordEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __recordEnabled = newValue } } }
    
    internal var _recordLength: Float {
        get { return _sliceQ.sync { __recordLength } }
        set { _sliceQ.sync(flags: .barrier) { __recordLength = newValue } } }
    
    internal var _repeaterOffsetDirection: String {
        get { return _sliceQ.sync { __repeaterOffsetDirection } }
        set { _sliceQ.sync(flags: .barrier) { __repeaterOffsetDirection = newValue } } }
    
    internal var _rfGain: Int {
        get { return _sliceQ.sync { __rfGain } }
        set { _sliceQ.sync(flags: .barrier) { __rfGain = newValue } } }
    
    internal var _ritEnabled: Bool {
        get { return _sliceQ.sync { __ritEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __ritEnabled = newValue } } }
    
    internal var _ritOffset: Int {
        get { return _sliceQ.sync { __ritOffset } }
        set { _sliceQ.sync(flags: .barrier) { __ritOffset = newValue } } }
    
    internal var _rttyMark: Int {
        get { return _sliceQ.sync { __rttyMark } }
        set { _sliceQ.sync(flags: .barrier) { __rttyMark = newValue } } }
    
    internal var _rttyShift: Int {
        get { return _sliceQ.sync { __rttyShift } }
        set { _sliceQ.sync(flags: .barrier) { __rttyShift = newValue } } }
    
    internal var _rxAnt: Radio.AntennaPort {
        get { return _sliceQ.sync { __rxAnt } }
        set { _sliceQ.sync(flags: .barrier) { __rxAnt = newValue } } }
    
    internal var _rxAntList: [Radio.AntennaPort] {
        get { return _sliceQ.sync { __rxAntList } }
        set { _sliceQ.sync(flags: .barrier) { __rxAntList = newValue } } }
    
    internal var _step: Int {
        get { return _sliceQ.sync { __step } }
        set { _sliceQ.sync(flags: .barrier) { __step = newValue } } }
    
    internal var _stepList: String {
        get { return _sliceQ.sync { __stepList } }
        set { _sliceQ.sync(flags: .barrier) { __stepList = newValue } } }
    
    internal var _squelchEnabled: Bool {
        get { return _sliceQ.sync { __squelchEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __squelchEnabled = newValue } } }
    
    internal var _squelchLevel: Int {
        get { return _sliceQ.sync { __squelchLevel } }
        set { _sliceQ.sync(flags: .barrier) { __squelchLevel = newValue } } }
    
    internal var _txAnt: String {
        get { return _sliceQ.sync { __txAnt } }
        set { _sliceQ.sync(flags: .barrier) { __txAnt = newValue } } }
    
    internal var _txEnabled: Bool {
        get { return _sliceQ.sync { __txEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __txEnabled = newValue } } }
    
    internal var _txOffsetFreq: Float {
        get { return _sliceQ.sync { __txOffsetFreq } }
        set { _sliceQ.sync(flags: .barrier) { __txOffsetFreq = newValue } } }
    
    internal var _wide: Bool {
        get { return _sliceQ.sync { __wide } }
        set { _sliceQ.sync(flags: .barrier) { __wide = newValue } } }
    
    internal var _wnbEnabled: Bool {
        get { return _sliceQ.sync { __wnbEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __wnbEnabled = newValue } } }
    
    internal var _wnbLevel: Int {
        get { return _sliceQ.sync { __wnbLevel } }
        set { _sliceQ.sync(flags: .barrier) { __wnbLevel = newValue } } }
    
    internal var _xitEnabled: Bool {
        get { return _sliceQ.sync { __xitEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __xitEnabled = newValue } } }
    
    internal var _xitOffset: Int {
        get { return _sliceQ.sync { __xitOffset } }
        set { _sliceQ.sync(flags: .barrier) { __xitOffset = newValue } } }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (no message to Radio)
    
    // FIXME: Should any of these send a message to the Radio?
    //          If yes, implement it, if not should they be "get" only?
    
    // listed in alphabetical order
    @objc dynamic public var daxClients: Int {
        get { return _daxClients }
        set { if _daxClients != newValue {  _daxClients = newValue } } }
    
    @objc dynamic public var daxTxEnabled: Bool {
        get { return _daxTxEnabled }
        set { if _daxTxEnabled != newValue { _daxTxEnabled = newValue } } }
    
    @objc dynamic public var diversityChild: Bool {
        get { return _diversityChild }
        set { if _diversityChild != newValue { if _diversityIsAllowed { _diversityChild = newValue } } } }
    
    @objc dynamic public var diversityIndex: Int {
        get { return _diversityIndex }
        set { if _diversityIndex != newValue { if _diversityIsAllowed { _diversityIndex = newValue } } } }
    
    @objc dynamic public var diversityParent: Bool {
        get { return _diversityParent }
        set { if _diversityParent != newValue { if _diversityIsAllowed { _diversityParent = newValue } } } }
    
    @objc dynamic public var inUse: Bool {
        return _inUse }
    
    @objc dynamic public var modeList: [String] {
        get { return _modeList }
        set { if _modeList != newValue { _modeList = newValue } } }
    
    @objc dynamic public var owner: Int {
        get { return _owner }
        set { if _owner != newValue { _owner = newValue } } }
    
    @objc dynamic public var panadapterId: String {
        get { return _panadapterId }
        set {if _panadapterId != newValue {  _panadapterId = newValue } } }
    
    @objc dynamic public var postDemodBypassEnabled: Bool {
        get { return _postDemodBypassEnabled }
        set { if _postDemodBypassEnabled != newValue { _postDemodBypassEnabled = newValue } } }
    
    @objc dynamic public var postDemodHigh: Int {
        get { return _postDemodHigh }
        set { if _postDemodHigh != newValue { _postDemodHigh = newValue } } }
    
    @objc dynamic public var postDemodLow: Int {
        get { return _postDemodLow }
        set { if _postDemodLow != newValue { _postDemodLow = newValue } } }
    
    @objc dynamic public var qskEnabled: Bool {
        get { return _qskEnabled }
        set { if _qskEnabled != newValue { _qskEnabled = newValue } } }
    
    @objc dynamic public var recordLength: Float {
        get { return _recordLength }
        set { if _recordLength != newValue { _recordLength = newValue } } }
    
    @objc dynamic public var rxAntList: [Radio.AntennaPort] {
        get { return _rxAntList }
        set { _rxAntList = newValue } }
    
    @objc dynamic public var wide: Bool {
        get { return _wide }
        set { _wide = newValue } }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - NON KVO compliant Setters / Getters with synchronization
    
    public var meters: [String: Meter] {                                               // meters
        get { return _meters } 
        set { _meters = newValue } }
    
    // ----------------------------------------------------------------------------
    // Mark: - Other Slice related enums
    
    public enum RepeaterOffsetDirection : String {
        case up
        case down
        case simplex
    }
    
    public enum AgcMode : String {
        case off
        case slow
        case medium
        case fast
    }
    
    public enum Mode : String {
        case am
        case cw
        case dfm
        case digl
        case digu
        case dsb
        case dstr
        case fdv
        case fm
        case lsb
        case nfm
        case rtty
        case sam
        case usb
    }

}
