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

public class Slice : NSObject, KeyValueParser {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    public private(set) var id = ""                     // Id that uniquely identifies this Slice
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private var _radio: Radio?                          // The Radio that owns this Slice
    private var _sliceQ: DispatchQueue                  // GCD queue that guards this object
    private var _initialized = false                    // True if initialized by Radio (hardware)
    private var _diversityIsAllowed: Bool
        { return _radio?.selectedRadio?.model == "FLEX-6700" || _radio?.selectedRadio?.model == "FLEX-6700R" }

    // constants
    private let _log = Log.sharedInstance               // shared Log
    private let kAudioClientCommand = "audio client 0 slice "   // command prefixes
    private let kFilterCommand = "filt "
    private let kSliceCommand = "slice "
    private let kSliceSetCommand = "slice set "
    private let kSliceTuneCommand = "slice tune "
    private let kMinLevel = 0                           // control range
    private let kMaxLevel = 100
    private let kMinOffset = -99_999                    // frequency offset range
    private let kMaxOffset = 99_999
    private let kNoError = "0"                          // response without error
    private let kTuneStepList =                         // tuning steps
        [1, 10, 50, 100, 500, 1_000, 2_000, 3_000]
    
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY, USE PUBLICS IN THE EXTENSION ------
    //                                                                                              //
    private var _meters = [String: Meter]()         // Dictionary of Meters (on this Slice)         //
                                                                                                    //
    private var __daxClients = 0                    // DAX clients for this slice                   //
                                                                                                    //
    private var __active = false                    //                                              //
    private var __agcMode = AgcMode.off.rawValue    //                                              //
    private var __agcOffLevel = 0                   // Slice AGC Off level                          //
    private var __agcThreshold = 0                  //                                              //
    private var __anfEnabled = false                //                                              //
    private var __anfLevel = 0                      //                                              //
    private var __apfEnabled = false                //                                              //
    private var __apfLevel = 0                      // DSP APF Level (0 - 100)                      //
    private var __audioGain = 0                     // Slice audio gain (0 - 100)                   //
    private var __audioMute = false                 // State of slice audio MUTE                    //
    private var __audioPan = 50                     // Slice audio pan (0 - 100)                    //
    private var __daxChannel = 0                    // DAX channel for this slice (1-8)             //
    private var __daxTxEnabled = false              // DAX for transmit                             //
    private var __dfmPreDeEmphasisEnabled = false   //                                              //
    private var __digitalLowerOffset = 0            //                                              //
    private var __digitalUpperOffset = 0            //                                              //
    private var __diversityChild = false            // Slice is the child of the pair               //
    private var __diversityEnabled = false          // Slice is part of a diversity pair            //
    private var __diversityIndex = 0                // Slice number of the other slice              //
    private var __diversityParent = false           // Slice is the parent of the pair              //
    private var __filterHigh = 0                    // RX filter high frequency                     //
    private var __filterLow = 0                     // RX filter low frequency                      //
    private var __fmDeviation = 0                   // FM deviation                                 //
    private var __fmRepeaterOffset: Float = 0.0     // FM repeater offset                           //
    private var __fmToneBurstEnabled = false        // FM tone burst                                //
    private var __fmToneFreq: Float = 0.0           // FM CTCSS tone frequency                      //
    private var __fmToneMode: String = ""           // FM CTCSS tone mode (ON | OFF)                //
    private var __frequency = 0                     // Slice frequency in Hz                        //
    private var __inUse = false                     // True = being used                            //
    private var __locked = false                    // Slice frequency locked                       //
    private var __loopAEnabled = false              // Loop A enable                                //
    private var __loopBEnabled = false              // Loop B enable                                //
    private var __mode = Mode.lsb.rawValue          // Slice mode                                   //
    private var __modeList = [String]()             // Array of Strings with available modes        //
    private var __nbEnabled = false                 // State of DSP Noise Blanker                   //
    private var __nbLevel = 0                       // DSP Noise Blanker level (0 -100)             //
    private var __nrEnabled = false                 // State of DSP Noise Reduction                 //
    private var __nrLevel = 0                       // DSP Noise Reduction level (0 - 100)          //
    private var __owner = 0                         // Slice owner - RESERVED for FUTURE use        //
    private var __panadapterId = ""                 // Panadaptor StreamID for this slice           //
    private var __playbackEnabled = false           // Quick playback enable                        //
    private var __postDemodBypassEnabled = false    //                                              //
    private var __postDemodHigh = 0                 //                                              //
    private var __postDemodLow = 0                  //                                              //
    private var __qskEnabled = false                // QSK capable on slice                         //
    private var __recordEnabled = false             // Quick record enable                          //
    private var __recordLength: Float = 0.0         // Length of quick recording (seconds)          //
    private var __repeaterOffsetDirection = RepeaterOffsetDirection.simplex.rawValue // Repeater offset direction (DOWN, UP, SIMPLEX)
    private var __rfGain = 0                        // RF Gain                                      //
    private var __ritEnabled = false                // RIT enabled                                  //
    private var __ritOffset = 0                     // RIT offset value                             //
    private var __rttyMark = 0                      // Rtty Mark                                    //
    private var __rttyShift = 0                     // Rtty Shift                                   //
    private var __rxAnt = ""                        // RX Antenna port for this slice               //
    private var __rxAntList = [String]()            // Array of available Antenna ports             //
    private var __step = 0                          // Frequency step value                         //
    private var __squelchEnabled = false            // Squelch enabled                              //
    private var __squelchLevel = 0                  // Squelch level (0 - 100)                      //
    private var __stepList = ""                     // Available Step values                        //
    private var __txAnt: String = ""                // TX Antenna port for this slice               //
    private var __txEnabled = false                 // TX on ths slice frequency/mode               //
    private var __txOffsetFreq: Float = 0.0         // TX Offset Frequency                          //
    private var __wide = false                      // State of slice bandpass filter               //
    private var __wnbEnabled = false                // Wideband noise blanking enabled              //
    private var __wnbLevel = 0                      // Wideband noise blanking level                //
    private var __xitEnabled = false                // XIT enable                                   //
    private var __xitOffset = 0                     // XIT offset value                             //
    //                                                                                              //
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
    public func parseKeyValues(_ keyValues: Radio.KeyValuesArray) {
        
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
//              - Dynamic public properties
//              - Slice message enum
//              - Other Slice related enums
// --------------------------------------------------------------------------------

extension xFlexAPI.Slice {
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties - with synchronization
    
    // listed in alphabetical order
    private var _active: Bool {
        get { return _sliceQ.sync { __active } }
        set { _sliceQ.sync(flags: .barrier) {__active = newValue } } }
    
    private var _agcMode: String {
        get { return _sliceQ.sync { __agcMode } }
        set { _sliceQ.sync(flags: .barrier) { __agcMode = newValue } } }
    
    private var _agcOffLevel: Int {
        get { return _sliceQ.sync { __agcOffLevel } }
        set { _sliceQ.sync(flags: .barrier) { __agcOffLevel = newValue } } }
    
    private var _agcThreshold: Int {
        get { return _sliceQ.sync { __agcThreshold } }
        set { _sliceQ.sync(flags: .barrier) { __agcThreshold = newValue } } }
    
    private var _anfEnabled: Bool {
        get { return _sliceQ.sync { __anfEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __anfEnabled = newValue } } }
    
    private var _anfLevel: Int {
        get { return _sliceQ.sync { __anfLevel } }
        set { _sliceQ.sync(flags: .barrier) { __anfLevel = newValue } } }
    
    private var _apfEnabled: Bool {
        get { return _sliceQ.sync { __apfEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __apfEnabled = newValue } } }
    
    private var _apfLevel: Int {
        get { return _sliceQ.sync { __apfLevel } }
        set { _sliceQ.sync(flags: .barrier) { __apfLevel = newValue } } }
    
    private var _audioGain: Int {
        get { return _sliceQ.sync { __audioGain } }
        set { _sliceQ.sync(flags: .barrier) { __audioGain = newValue } } }
    
    private var _audioMute: Bool {
        get { return _sliceQ.sync { __audioMute } }
        set { _sliceQ.sync(flags: .barrier) { __audioMute = newValue } } }
    
    private var _audioPan: Int {
        get { return _sliceQ.sync { __audioPan } }
        set { _sliceQ.sync(flags: .barrier) { __audioPan = newValue } } }
    
    private var _daxChannel: Int {
        get { return _sliceQ.sync { __daxChannel } }
        set { _sliceQ.sync(flags: .barrier) { __daxChannel = newValue } } }
    
    private var _daxClients: Int {
        get { return _sliceQ.sync { __daxClients } }
        set { _sliceQ.sync(flags: .barrier) { __daxClients = newValue } } }
    
    private var _dfmPreDeEmphasisEnabled: Bool {
        get { return _sliceQ.sync { __dfmPreDeEmphasisEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __dfmPreDeEmphasisEnabled = newValue } } }
    
    private var _daxTxEnabled: Bool {
        get { return _sliceQ.sync { __daxTxEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __daxTxEnabled = newValue } } }
    
    private var _digitalLowerOffset: Int {
        get { return _sliceQ.sync { __digitalLowerOffset } }
        set { _sliceQ.sync(flags: .barrier) { __digitalLowerOffset = newValue } } }
    
    private var _digitalUpperOffset: Int {
        get { return _sliceQ.sync { __digitalUpperOffset } }
        set { _sliceQ.sync(flags: .barrier) { __digitalUpperOffset = newValue } } }
    
    private var _diversityChild: Bool {
        get { return _sliceQ.sync { __diversityChild } }
        set { _sliceQ.sync(flags: .barrier) { __diversityChild = newValue } } }
    
    private var _diversityEnabled: Bool {
        get { return _sliceQ.sync { __diversityEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __diversityEnabled = newValue } } }
    
    private var _diversityIndex: Int {
        get { return _sliceQ.sync { __diversityIndex } }
        set { _sliceQ.sync(flags: .barrier) { __diversityIndex = newValue } } }
    
    private var _diversityParent: Bool {
        get { return _sliceQ.sync { __diversityParent } }
        set { _sliceQ.sync(flags: .barrier) { __diversityParent = newValue } } }
    
    private var _filterHigh: Int {
        get { return _sliceQ.sync { __filterHigh } }
        set { _sliceQ.sync(flags: .barrier) { __filterHigh = newValue } } }
    
    private var _filterLow: Int {
        get { return _sliceQ.sync { __filterLow } }
        set {_sliceQ.sync(flags: .barrier) { __filterLow = newValue } } }
    
    private var _fmDeviation: Int {
        get { return _sliceQ.sync { __fmDeviation } }
        set { _sliceQ.sync(flags: .barrier) { __fmDeviation = newValue } } }
    
    private var _fmRepeaterOffset: Float {
        get { return _sliceQ.sync { __fmRepeaterOffset } }
        set { _sliceQ.sync(flags: .barrier) { __fmRepeaterOffset = newValue } } }
    
    private var _fmToneBurstEnabled: Bool {
        get { return _sliceQ.sync { __fmToneBurstEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __fmToneBurstEnabled = newValue } } }
    
    private var _fmToneFreq: Float {
        get { return _sliceQ.sync { __fmToneFreq } }
        set { _sliceQ.sync(flags: .barrier) { __fmToneFreq = newValue } } }
    
    private var _fmToneMode: String {
        get { return _sliceQ.sync { __fmToneMode } }
        set { _sliceQ.sync(flags: .barrier) { __fmToneMode = newValue } } }
    
    private var _frequency: Int {
        get { return _sliceQ.sync { __frequency } }
        set { _sliceQ.sync(flags: .barrier) { __frequency = newValue } } }
    
    private var _inUse: Bool {
        get { return _sliceQ.sync { __inUse } }
        set { _sliceQ.sync(flags: .barrier) { __inUse = newValue } } }
    
    private var _locked: Bool {
        get { return _sliceQ.sync { __locked } }
        set { _sliceQ.sync(flags: .barrier) { __locked = newValue } } }
    
    private var _loopAEnabled: Bool {
        get { return _sliceQ.sync { __loopAEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __loopAEnabled = newValue } } }
    
    private var _loopBEnabled: Bool {
        get { return _sliceQ.sync { __loopBEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __loopBEnabled = newValue } } }
    
    private var _mode: String {
        get { return _sliceQ.sync { __mode } }
        set { _sliceQ.sync(flags: .barrier) { __mode = newValue } } }
    
    private var _modeList: [String] {
        get { return _sliceQ.sync { __modeList } }
        set { _sliceQ.sync(flags: .barrier) { __modeList = newValue } } }
    
    private var _nbEnabled: Bool {
        get { return _sliceQ.sync { __nbEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __nbEnabled = newValue } } }
    
    private var _nbLevel: Int {
        get { return _sliceQ.sync { __nbLevel } }
        set { _sliceQ.sync(flags: .barrier) { __nbLevel = newValue } } }
    
    private var _nrEnabled: Bool {
        get { return _sliceQ.sync { __nrEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __nrEnabled = newValue } } }
    
    private var _nrLevel: Int {
        get { return _sliceQ.sync { __nrLevel } }
        set { _sliceQ.sync(flags: .barrier) { __nrLevel = newValue } } }
    
    private var _owner: Int {
        get { return _sliceQ.sync { __owner } }
        set { _sliceQ.sync(flags: .barrier) { __owner = newValue } } }
    
    private var _panadapterId: String {
        get { return _sliceQ.sync { __panadapterId } }
        set { _sliceQ.sync(flags: .barrier) { __panadapterId = newValue } } }
    
    private var _panControl: Int {
        get { return _sliceQ.sync { __audioPan } }
        set { _sliceQ.sync(flags: .barrier) { __audioPan = newValue } } }
    
    private var _playbackEnabled: Bool {
        get { return _sliceQ.sync { __playbackEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __playbackEnabled = newValue } } }
    
    private var _postDemodBypassEnabled: Bool {
        get { return _sliceQ.sync { __postDemodBypassEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __postDemodBypassEnabled = newValue } } }
    
    private var _postDemodHigh: Int {
        get { return _sliceQ.sync { __postDemodHigh } }
        set { _sliceQ.sync(flags: .barrier) { __postDemodHigh = newValue } } }
    
    private var _postDemodLow: Int {
        get { return _sliceQ.sync { __postDemodLow } }
        set { _sliceQ.sync(flags: .barrier) { __postDemodLow = newValue } } }
    
    private var _qskEnabled: Bool {
        get { return _sliceQ.sync { __qskEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __qskEnabled = newValue } } }
    
    private var _recordEnabled: Bool {
        get { return _sliceQ.sync { __recordEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __recordEnabled = newValue } } }
    
    private var _recordLength: Float {
        get { return _sliceQ.sync { __recordLength } }
        set { _sliceQ.sync(flags: .barrier) { __recordLength = newValue } } }
    
    private var _repeaterOffsetDirection: String {
        get { return _sliceQ.sync { __repeaterOffsetDirection } }
        set { _sliceQ.sync(flags: .barrier) { __repeaterOffsetDirection = newValue } } }
    
    private var _rfGain: Int {
        get { return _sliceQ.sync { __rfGain } }
        set { _sliceQ.sync(flags: .barrier) { __rfGain = newValue } } }
    
    private var _ritEnabled: Bool {
        get { return _sliceQ.sync { __ritEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __ritEnabled = newValue } } }
    
    private var _ritOffset: Int {
        get { return _sliceQ.sync { __ritOffset } }
        set { _sliceQ.sync(flags: .barrier) { __ritOffset = newValue } } }
    
    private var _rttyMark: Int {
        get { return _sliceQ.sync { __rttyMark } }
        set { _sliceQ.sync(flags: .barrier) { __rttyMark = newValue } } }
    
    private var _rttyShift: Int {
        get { return _sliceQ.sync { __rttyShift } }
        set { _sliceQ.sync(flags: .barrier) { __rttyShift = newValue } } }
    
    private var _rxAnt: Radio.AntennaPort {
        get { return _sliceQ.sync { __rxAnt } }
        set { _sliceQ.sync(flags: .barrier) { __rxAnt = newValue } } }
    
    private var _rxAntList: [Radio.AntennaPort] {
        get { return _sliceQ.sync { __rxAntList } }
        set { _sliceQ.sync(flags: .barrier) { __rxAntList = newValue } } }
    
    private var _step: Int {
        get { return _sliceQ.sync { __step } }
        set { _sliceQ.sync(flags: .barrier) { __step = newValue } } }
    
    private var _stepList: String {
        get { return _sliceQ.sync { __stepList } }
        set { _sliceQ.sync(flags: .barrier) { __stepList = newValue } } }
    
    private var _squelchEnabled: Bool {
        get { return _sliceQ.sync { __squelchEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __squelchEnabled = newValue } } }
    
    private var _squelchLevel: Int {
        get { return _sliceQ.sync { __squelchLevel } }
        set { _sliceQ.sync(flags: .barrier) { __squelchLevel = newValue } } }
    
    private var _txAnt: String {
        get { return _sliceQ.sync { __txAnt } }
        set { _sliceQ.sync(flags: .barrier) { __txAnt = newValue } } }
    
    private var _txEnabled: Bool {
        get { return _sliceQ.sync { __txEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __txEnabled = newValue } } }
    
    private var _txOffsetFreq: Float {
        get { return _sliceQ.sync { __txOffsetFreq } }
        set { _sliceQ.sync(flags: .barrier) { __txOffsetFreq = newValue } } }
    
    private var _wide: Bool {
        get { return _sliceQ.sync { __wide } }
        set { _sliceQ.sync(flags: .barrier) { __wide = newValue } } }
    
    private var _wnbEnabled: Bool {
        get { return _sliceQ.sync { __wnbEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __wnbEnabled = newValue } } }
    
    private var _wnbLevel: Int {
        get { return _sliceQ.sync { __wnbLevel } }
        set { _sliceQ.sync(flags: .barrier) { __wnbLevel = newValue } } }
    
    private var _xitEnabled: Bool {
        get { return _sliceQ.sync { __xitEnabled } }
        set { _sliceQ.sync(flags: .barrier) { __xitEnabled = newValue } } }
    
    private var _xitOffset: Int {
        get { return _sliceQ.sync { __xitOffset } }
        set { _sliceQ.sync(flags: .barrier) { __xitOffset = newValue } } }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (with message sent to Radio)
    
    // listed in alphabetical order
    @objc dynamic public var active: Bool {
        get { return _active }
        set { if _active != newValue { _active = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.active.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var agcMode: String {
        get { return _agcMode }
        set { if _agcMode != newValue { _agcMode = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.agcMode.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var agcOffLevel: Int {
        get { return _agcOffLevel }
        set { if _agcOffLevel != newValue { if newValue.within(kMinLevel, kMaxLevel) {  _agcOffLevel = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.agcOffLevel.rawValue + "=\(newValue)") } } } }
    
    @objc dynamic public var agcThreshold: Int {
        get { return _agcThreshold }
        set { if _agcThreshold != newValue { if newValue.within(kMinLevel, kMaxLevel) { _agcThreshold = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.agcThreshold.rawValue + "=\(newValue)") } } } }
    
    @objc dynamic public var anfEnabled: Bool {
        get { return _anfEnabled }
        set { if _anfEnabled != newValue { _anfEnabled = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.anfEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var anfLevel: Int {
        get { return _anfLevel }
        set { if _anfLevel != newValue { if newValue.within(kMinLevel, kMaxLevel) { _anfLevel = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.anfLevel.rawValue + "=\(newValue)") } } } }
    
    @objc dynamic public var apfEnabled: Bool {
        get { return _apfEnabled }
        set { if _apfEnabled != newValue { _apfEnabled = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.apfEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var apfLevel: Int {
        get { return _apfLevel }
        set { if _apfLevel != newValue { if newValue.within(kMinLevel, kMaxLevel) { _apfLevel = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.apfLevel.rawValue + "=\(newValue)") } } } }
    
    @objc dynamic public var audioGain: Int {
        get { return _audioGain }
        set { if _audioGain != newValue { if newValue.within(kMinLevel, kMaxLevel) { _audioGain = newValue ; _radio!.send(kAudioClientCommand + "\(id) " + SliceToken.audioGain.rawValue + "=\(newValue)") } } } }
    
    @objc dynamic public var audioMute: Bool {
        get { return _audioMute }
        set { if _audioMute != newValue { _audioMute = newValue ; _radio!.send(kAudioClientCommand + "\(id) " + SliceToken.audioMute.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var audioPan: Int {
        get { return _audioPan }
        set { if _audioPan != newValue { _audioPan = newValue ; _radio!.send(kAudioClientCommand + "\(id) " + SliceToken.audioPan.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var daxChannel: Int {
        get { return _daxChannel }
        set { if _daxChannel != newValue { _daxChannel = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.daxChannel.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var dfmPreDeEmphasisEnabled: Bool {
        get { return _dfmPreDeEmphasisEnabled }
        set { if _dfmPreDeEmphasisEnabled != newValue { _dfmPreDeEmphasisEnabled = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.dfmPreDeEmphasisEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var digitalLowerOffset: Int {
        get { return _digitalLowerOffset }
        set { if _digitalLowerOffset != newValue { _digitalLowerOffset = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.digitalLowerOffset.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var digitalUpperOffset: Int {
        get { return _digitalUpperOffset }
        set { if _digitalUpperOffset != newValue { _digitalUpperOffset = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.digitalUpperOffset.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var diversityEnabled: Bool {
        get { return _diversityEnabled }
        set { if _diversityEnabled != newValue { if _diversityIsAllowed { _diversityEnabled = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.diversityEnabled.rawValue + "=\(newValue.asNumber())") } } } }
    
    @objc dynamic public var filterHigh: Int {
        get { return _filterHigh }
        set { if _filterHigh != newValue { let value = filterHighLimits(newValue) ; _filterHigh = value ; _radio!.send(kFilterCommand + "0x\(id) \(filterLow) \(value)") } } }
    
    @objc dynamic public var filterLow: Int {
        get { return _filterLow }
        set { if _filterLow != newValue { let value = filterLowLimits(newValue) ; _filterLow = value ; _radio!.send(kFilterCommand + "0x\(id) \(value) \(filterHigh)") } } }
    
    @objc dynamic public var fmDeviation: Int {
        get { return _fmDeviation }
        set { if _fmDeviation != newValue { _fmDeviation = newValue ; _radio!.send(kSliceSetCommand + "0x\(id)  " + SliceToken.fmDeviation.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var fmRepeaterOffset: Float {
        get { return _fmRepeaterOffset }
        set { if _fmRepeaterOffset != newValue { _fmRepeaterOffset = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.fmRepeaterOffset.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var fmToneBurstEnabled: Bool {
        get { return _fmToneBurstEnabled }
        set { if _fmToneBurstEnabled != newValue { _fmToneBurstEnabled = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.fmToneBurstEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var fmToneFreq: Float {
        get { return _fmToneFreq }
        set { if _fmToneFreq != newValue { _fmToneFreq = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.fmToneFreq.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var fmToneMode: String {
        get { return _fmToneMode }
        set { if _fmToneMode != newValue { _fmToneMode = newValue ; _radio!.send(kSliceSetCommand + "0x\(id)  " + SliceToken.fmToneMode.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var frequency: Int {
        get { return _frequency }
        set { if !_locked { if _frequency != newValue { _frequency = newValue ; _radio!.send(kSliceTuneCommand + "\(id) \(newValue.hzToMhz())") } } } }
    
    @objc dynamic public var locked: Bool {
        get { return _locked }
        set { if _locked != newValue { _locked = newValue ; _radio!.send(kSliceCommand + "\(newValue == true ? "lock" : "unlock")" + " 0x\(id)") } } }
    
    @objc dynamic public var loopAEnabled: Bool {
        get { return _loopAEnabled }
        set { if _loopAEnabled != newValue { _loopAEnabled = newValue ; _radio!.send(kSliceCommand + "0x\(id) " + SliceToken.loopAEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var loopBEnabled: Bool {
        get { return _loopBEnabled }
        set { if _loopBEnabled != newValue { _loopBEnabled = newValue ; _radio!.send(kSliceCommand + "0x\(id) " + SliceToken.loopBEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var mode: String {
        get { return _mode }
        set { if _mode != newValue { _mode = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.mode.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var nbEnabled: Bool {
        get { return _nbEnabled }
        set { if _nbEnabled != newValue { _nbEnabled = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.nbEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var nbLevel: Int {
        get { return _nbLevel }
        set { if _nbLevel != newValue { if newValue.within(kMinLevel, kMaxLevel) {  _nbLevel = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.nbLevel.rawValue + "=\(newValue)") } } } }
    
    @objc dynamic public var nrEnabled: Bool {
        get { return _nrEnabled }
        set { if _nrEnabled != newValue { _nrEnabled = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.nrEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var nrLevel: Int {
        get { return _nrLevel }
        set { if _nrLevel != newValue { if newValue.within(kMinLevel, kMaxLevel) {  _nrLevel = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.nrLevel.rawValue + "=\(newValue)") } } } }
    
    @objc dynamic public var playbackEnabled: Bool {
        get { return _playbackEnabled }
        set { if _playbackEnabled != newValue { _playbackEnabled = newValue ; _radio!.send(kSliceSetCommand + "0x\(id)  " + SliceToken.playbackEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var recordEnabled: Bool {
        get { return _recordEnabled }
        set { if _recordEnabled != newValue { _recordEnabled = newValue ; _radio!.send(kSliceSetCommand + "0x\(id)  " + SliceToken.recordEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var repeaterOffsetDirection: String {
        get { return _repeaterOffsetDirection }
        set { if _repeaterOffsetDirection != newValue { _repeaterOffsetDirection = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.repeaterOffsetDirection.rawValue + "=\(newValue)")} } }
    
    @objc dynamic public var rfGain: Int {
        get { return _rfGain }
        set { if _rfGain != newValue { _rfGain = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.rfGain.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var ritEnabled: Bool {
        get { return _ritEnabled }
        set { if _ritEnabled != newValue { _ritEnabled = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.ritEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var ritOffset: Int {
        get { return _ritOffset }
        set { if _ritOffset != newValue { if newValue.within(kMinOffset, kMaxOffset) {  _ritOffset = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.ritOffset.rawValue + "=\(newValue)") } } } }
    
    @objc dynamic public var rttyMark: Int {
        get { return _rttyMark }
        set { if _rttyMark != newValue { _rttyMark = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.rttyMark.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var rttyShift: Int {
        get { return _rttyShift }
        set { if _rttyShift != newValue { _rttyShift = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.rttyShift.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var rxAnt: Radio.AntennaPort {
        get { return _rxAnt }
        set { if _rxAnt != newValue { _rxAnt = newValue ; _radio!.send(kSliceSetCommand + "\(id) " + SliceToken.rxAnt.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var step: Int {
        get { return _step }
        set { if _step != newValue { _step = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.step.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var stepList: String {
        get { return _stepList }
        set { if _stepList != newValue { _stepList = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.stepList.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var squelchEnabled: Bool {
        get { return _squelchEnabled }
        set { if _squelchEnabled != newValue { _squelchEnabled = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.squelchEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var squelchLevel: Int {
        get { return _squelchLevel }
        set { if _squelchLevel != newValue { if newValue.within(kMinLevel, kMaxLevel) {  _squelchLevel = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.squelchLevel.rawValue + "=\(newValue)") } } } }
    
    @objc dynamic public var txAnt: String {
        get { return _txAnt }
        set { if _txAnt != newValue { _txAnt = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.txAnt.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var txEnabled: Bool {
        get { return _txEnabled }
        set { if _txEnabled != newValue { _txEnabled = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.txEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var txOffsetFreq: Float {
        get { return _txOffsetFreq }
        set { if _txOffsetFreq != newValue { _txOffsetFreq = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.txOffsetFreq.rawValue + "=\(newValue)") } } }
    
    @objc dynamic public var wnbEnabled: Bool {
        get { return _wnbEnabled }
        set { if _wnbEnabled != newValue { _wnbEnabled = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.wnbEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var wnbLevel: Int {
        get { return _wnbLevel }
        set { if wnbLevel != newValue { if newValue.within(kMinLevel, kMaxLevel) {  _wnbLevel = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.wnbLevel.rawValue + "=\(newValue)") } } } }
    
    @objc dynamic public var xitEnabled: Bool {
        get { return _xitEnabled }
        set { if _xitEnabled != newValue { _xitEnabled = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.xitEnabled.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var xitOffset: Int {
        get { return _xitOffset }
        set { if _xitOffset != newValue { if newValue.within(kMinOffset, kMaxOffset) {  _xitOffset = newValue ; _radio!.send(kSliceSetCommand + "0x\(id) " + SliceToken.xitOffset.rawValue + "=\(newValue)") } } } }
    
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
    // Mark: - Tokens for Slice messages (only populate values that != case value)
    
    internal enum SliceToken : String {
        case active
        case agcMode = "agc_mode"
        case agcOffLevel = "agc_off_level"
        case agcThreshold = "agc_threshold"
        case anfEnabled = "anf"
        case anfLevel = "anf_level"
        case apfEnabled = "apf"
        case apfLevel = "apf_level"
        case audioGain = "audio_gain"
        case audioMute = "audio_mute"
        case audioPan = "audio_pan"
        case daxChannel = "dax"
        case daxClients = "dax_clients"
        case daxTxEnabled = "dax_tx"
        case dfmPreDeEmphasisEnabled = "dfm_pre_de_emphasis"
        case digitalLowerOffset = "digl_offset"
        case digitalUpperOffset = "digu_offset"
        case diversityEnabled = "diversity"
        case diversityChild = "diversity_child"
        case diversityIndex = "diversity_index"
        case diversityParent = "diversity_parent"
        case filterHigh = "filter_hi"
        case filterLow = "filter_lo"
        case fmDeviation = "fm_deviation"
        case fmRepeaterOffset = "fm_repeater_offset_freq"
        case fmToneBurstEnabled = "fm_tone_burst"
        case fmToneMode = "fm_tone_mode"
        case fmToneFreq = "fm_tone_value"
        case frequency = "rf_frequency"
        case ghost
        case inUse = "in_use"
        case locked = "lock"
        case loopAEnabled = "loopa"
        case loopBEnabled = "loopb"
        case mode
        case modeList = "mode_list"
        case nbEnabled = "nb"
        case nbLevel = "nb_level"
        case nrEnabled = "nr"
        case nrLevel = "nr_level"
        case owner
        case panadapterId = "pan"
        case playbackEnabled = "play"
        case postDemodBypassEnabled = "post_demod_bypass"
        case postDemodHigh = "post_demod_high"
        case postDemodLow = "post_demod_low"
        case qskEnabled = "qsk"
        case recordEnabled = "record"
        case recordTime = "record_time"
        case repeaterOffsetDirection = "repeater_offset_dir"
        case rfGain = "rfgain"
        case ritEnabled = "rit_on"
        case ritOffset = "rit_freq"
        case rttyMark = "rtty_mark"
        case rttyShift = "rtty_shift"
        case rxAnt = "rxant"
        case rxAntList = "ant_list"
        case squelchEnabled = "squelch"
        case squelchLevel = "squelch_level"
        case step
        case stepList = "step_list"
        case txEnabled = "tx"
        case txAnt = "txant"
        case txOffsetFreq = "tx_offset_freq"
        case wide
        case wnbEnabled = "wnb"
        case wnbLevel = "wnb_level"
        case xitEnabled = "xit_on"
        case xitOffset = "xit_freq"
    }
    
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
