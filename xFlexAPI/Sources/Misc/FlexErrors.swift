//
//  FlexErrors.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 12/23/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Foundation

// ----------------------------------------------------------------------------
// MARK: - FlexErrors enum
// ----------------------------------------------------------------------------

public enum FlexErrors: UInt32 {
    
    // Error codes from http://wiki.flexradio.com/index.php?title=Known_API_Responses
    
    // SL_ERROR_BASE = 0x50000000
    // SL_INFO = 0x10000000
    // SL_WARNING = 0x31000000
    // SL_ERROR = 0xE2000000
    // SL_FATAL = 0xF3000000
    // SL_RESP_UNKNOWN = SL_ERROR_BASE + 0x00001000
    
    case SL_RESP_UNKNOWN = 0x50001000
    case SLM_I_UNKNOWN_CLIENT = 0x10000002
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    func description() -> String {
        switch self {
        case .SL_RESP_UNKNOWN: return "Response unknown"
        case .SLM_I_UNKNOWN_CLIENT: return "Unknown client"
        }
    }
}
