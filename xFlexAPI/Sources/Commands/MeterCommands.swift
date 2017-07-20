//
//  MeterCommands.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 7/20/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

// --------------------------------------------------------------------------------
// MARK: - Meter Class extensions
//              - Dynamic public properties that send commands to the Radio
//              - Meter message enum
// --------------------------------------------------------------------------------

extension Meter {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties - KVO compliant (with message sent to Radio)
    
        // ----- NONE -----
    
    // ----------------------------------------------------------------------------
    // MARK: - Tokens for Meter messages
    
    internal enum MeterToken : String {
        case desc
        case fps
        case high = "hi"
        case low
        case name = "nam"
        case number = "num"
        case source = "src"
        case units = "unit"
    }
}
