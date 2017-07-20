//
//  TnfCommands.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 7/19/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Tnf Class extensions
//              - Dynamic public properties
//              - Tnf message enum
// --------------------------------------------------------------------------------

extension Tnf {
        
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (with message sent to Radio)
    
    // listed in alphabetical order
    @objc dynamic public var depth: Int {
        get { return _depth }
        set { if _depth != newValue { if depth.within(Depth.normal.rawValue, Depth.veryDeep.rawValue) {
            _depth = newValue ; _radio!.send(kTnfSetCmd + "\(id) " + TnfToken.depth.rawValue + "=\(newValue)") } } } }
    
    @objc dynamic public var frequency: Int {
        get { return _frequency }
        set { if _frequency != newValue { _frequency = newValue ; _radio!.send(kTnfSetCmd + "\(id) " + TnfToken.frequency.rawValue + "=\(newValue.hzToMhz())") } } }
    
    @objc dynamic public var permanent: Bool {
        get { return _permanent }
        set { if _permanent != newValue { _permanent = newValue ; _radio!.send(kTnfSetCmd + "\(id) " + TnfToken.permanent.rawValue + "=\(newValue.asNumber())") } } }
    
    @objc dynamic public var width: Int {
        get { return _width  }
        set { if _width != newValue { if width.within(minWidth, maxWidth) { _width = newValue ; _radio!.send(kTnfSetCmd + "\(id) " + TnfToken.width.rawValue + "=\(newValue.hzToMhz())") } } } }
    
    
    // ----------------------------------------------------------------------------
    // MARK: - Tokens for Tnf messages 
    
    internal enum TnfToken : String {
        case depth
        case frequency = "freq"
        case permanent
        case width
    }
    
    public enum Depth : Int {
        case normal = 1
        case deep = 2
        case veryDeep = 3
    }
}
