//
//  Log.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 9/6/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Foundation

// ----------------------------------------------------------------------------
// MARK: - Log implementation
// ----------------------------------------------------------------------------

public final class Log {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    public var maxCommands = 512
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    // FIXME: public only for debugging purposes, change to private later
    
    public var _entries =   [LogEntry]()            // log entries, serialized by the _logQ
    public var _commands =  [String]()              // commands, serialized by the _commandsQ

    // constants
    private let _logQ =         DispatchQueue(label: kApiId + ".logQ", attributes: [.concurrent])
    private let _commandsQ =    DispatchQueue(label: kApiId + ".commandsQ", attributes: [.concurrent])
    
    private let kLogFile =              "XFlexAPILog"
    private let kCommandsFile =         "XFlexAPICommandsDict"
    private let kErrorWritingLog =      "Error writing Log to file: "
    private let kErrorWritingCommands = "Error writing Commands to file: "
    private let kErrorWritingDict =     "Error writing Dictionary to file: "
    
    // ----------------------------------------------------------------------------
    // MARK: - Singleton
    
    /// Provide access to the Log singleton
    ///
    public static var sharedInstance = Log()
    
    private init() {
        // "private" prevents others from calling init()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    /// Create an entry in the Log. May be called from any thread, Log Queue assures sequence
    ///
    /// - parameter msg:    a Description
    /// - parameter level:  an Error Level
    /// - parameter source: the Source of the message
    ///
    public func entry(_ msg: String, level: MessageLevel, source: String ) {
        var logEntry: LogEntry!
        
        // use the logQ (concurrent, sync, barrier)
        _logQ.sync(flags: .barrier) { [unowned self] in
            
            // populate & append a Log entry
            logEntry = LogEntry( message:(level == .token) ? "Unexpected token " + msg : msg, level: level, source: source)
            self._entries.append(logEntry)

            // notify all observers
            NC.post(.logEntryWasAdded, object: logEntry as Any?)
        }
    }
    /// Return a copy of the Log array
    ///
    /// - returns: an array of Log Entries
    ///
    public func logCopy() -> [LogEntry] {
        var entries = [LogEntry]()
        
        // use the concurrent logQ to obtain the value
        _logQ.sync { [unowned self] in
            entries = self._entries
        }
        return entries
    }
    /// Return a copy of the Command array
    ///
    /// - returns: an array of Command Entries
    ///
    public func commandCopy() -> [String] {
        var commands = [String]()
        
        // use the concurrent logQ to obtain the value
        _logQ.sync { [unowned self] in
            commands = self._commands
        }
        return commands
    }
    /// Create an entry in the Commands. May be called from any thread
    ///
    /// - parameter command: a Command string
    ///
    public func command(_ command: String) {
        
        // don't log Replies with a "0" response code or commands containing "ping"
        if !(command.lowercased().hasPrefix("r") && command.contains("|0|")) && !(command.lowercased().contains("ping")) {
            
            // use the concurrent commandsQ (with a barrier) to update the value
            _commandsQ.async(flags: .barrier) { [unowned self] in
                
                // don't exceedd the maximum number of commands
                if self._commands.count >= self.maxCommands {
                    self._commands.removeFirst()
                }
                self._commands.append(command)
                
                // notify all observers
                NC.post(.commandEntryWasAdded, object: command as Any?)
            }
        }
    }
    /// Return a copy of the Commands array
    ///
    /// - returns: an array of Command Entries
    ///
    public func commandsCopy() -> [String] {
        var commands = [String]()
        
        // use the concurrent commandsQ to obtain the value
        _commandsQ.sync { [unowned self] in
            commands = self._commands
        }
        return commands
    }
    /// Write the Log to App Support folder (optionally filter it)
    ///
    /// - parameter filterBy: a MessageLevel
    ///
    public func writeLogToAppFolderURL(number: Int, _ filterBy: MessageLevel? = nil) {
        
        let url = FileHelper.appFolder().appendingPathComponent(kLogFile + "_\(number).txt")
        
        writeLogToFileURL(url, filterBy: filterBy)
    }
    /// Write the Commands Dictionary to App Support folder
    ///
    /// - parameter cmdDict: a dictionary of Commands
    ///
    public func writeDictToAppFolderURL(_ cmdDict: [String:String]) {
        
        let url = FileHelper.appFolder().appendingPathComponent(kCommandsFile + ".txt")
        
        writeDictToFileURL(url, cmdDict: cmdDict)
    }
    /// Write the Log to a fileURL (optionally filter it)
    ///
    /// - parameter fileURL:  a URL for the file
    /// - parameter filterBy: a MessageLevel
    ///
    public func writeLogToFileURL(_ fileURL: URL, filterBy: MessageLevel? = nil) {
        var fileString = ""
        
        if let filterBy = filterBy {
            
            // get the Log Entries (filtered by the current FilterBy selection)
            let filteredLog = logCopy().filter { $0.level >= filterBy }
            
            // build a string of all the filtered entries
            for entry in filteredLog {
                fileString += "\(entry.timeStamp), \(entry.message), \(entry.level.name), \(entry.source)\n"
            }
        
        } else {
            
            // build a string of all the entries
            for entry in logCopy() {
                fileString += "\(entry.timeStamp), \(entry.message), \(entry.level.name), \(entry.source)\n"
            }
        }
        
        // write the file
        do {
            try fileString.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
        } catch let error as NSError {
            fatalError(kErrorWritingLog + "\(error.localizedDescription)")
        } catch {
            fatalError(kErrorWritingLog)
        }
    }
    /// Write the Commands to a fileURL
    ///
    /// - parameter fileURL: a URL for the file
    ///
    public func writeCommandsToFileURL(_ fileURL: URL) {
        
        let commandsString = commandsCopy().reduce("", {$0 + $1 + "\n"})
        
        // write the file
        do {
            try commandsString.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
        } catch let error as NSError {
            fatalError(kErrorWritingCommands + "\(error.localizedDescription)")
        } catch {
            fatalError(kErrorWritingCommands)
        }
    }
    /// Write the Commands Dictionary to a fileUR
    ///
    /// - parameter fileURL: a URL for the file
    /// - parameter cmdDict: a dictionary of Commands
    ///
    public func writeDictToFileURL(_ fileURL: URL, cmdDict: [String:String]) {
        var dictString = ""
        
        // sort the Commands
        let keys = Array(cmdDict.keys)
        let sortedKeys = keys.sorted { return $0 < $1 }
        
        // make the sorted Commands into a string
        for key in sortedKeys {
            dictString = dictString + key + "\n" + cmdDict[key]! + "\n"
        }
        
        // write the string to the URL
        do {
            try dictString.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
        } catch let error as NSError {
            fatalError(kErrorWritingDict + "\(error.localizedDescription)")
        } catch {
            fatalError(kErrorWritingDict)
        }
    }

}

