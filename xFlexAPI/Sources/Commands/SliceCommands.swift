//
//  SliceCommands.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 7/19/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Slice Class extensions
//              - Dynamic public properties
//              - Slice message enum
// --------------------------------------------------------------------------------

extension xFlexAPI.Slice {
        
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (with message sent to Radio) - checked
    
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
        set { if _audioGain != newValue { if newValue.within(kMinLevel, kMaxLevel) { _audioGain = newValue ; _radio!.send(kAudioClientCommand + "\(id) gain" + "=\(newValue)") } } } }
    
    @objc dynamic public var audioMute: Bool {
        get { return _audioMute }
        set { if _audioMute != newValue { _audioMute = newValue ; _radio!.send(kAudioClientCommand + "\(id) mute" + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var audioPan: Int {
        get { return _audioPan }
        set { if _audioPan != newValue { _audioPan = newValue ; _radio!.send(kAudioClientCommand + "\(id) pan" + "=\(newValue)") } } }
    
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
        set { if !_locked { if _frequency != newValue { _frequency = newValue ; _radio!.send(kSliceTuneCommand + "\(id)" + " \(newValue.hzToMhz())") } } } }
    
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
    // MARK: - Tokens for Slice messages 
    
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
}
