//
//  TcpManager.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 8/15/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

public typealias ReplyHandler = (_ command: String, _ seqNum: String, _ responseValue: String, _ reply: String) -> Void
public typealias SequenceId = String
public typealias ReplyTuple = (replyTo: ReplyHandler?, command: String)

public protocol TcpManagerDelegate {
    
    func tcpState(connected: Bool, host: String, port: UInt16, error: String)
    func tcpError(_ message: String)
    func addReplyHandler(_ sequenceId: SequenceId, replyTuple: ReplyTuple)
    func sentMessage(_ text: String)
    func receivedMessage(_ text: String)
}

// ------------------------------------------------------------------------------
// MARK: - TcpManager Class implementation
//
//      manages all Tcp communication between the API and the Radio (hardware)
//
// ------------------------------------------------------------------------------

final class TcpManager: NSObject, GCDAsyncSocketDelegate {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    public var isConnected: Bool {
        return _tcpSocket.isConnected
    }
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private var _tcpQ: DispatchQueue                // serial GCD Queue for sending/receiving Radio Commands
    private var _delegate: TcpManagerDelegate       // class to receive TCP data
    private var _tcpSocket: GCDAsyncSocket!         // GCDAsync TCP socket object
    private var seqNum = 0                          // Sequence number
    
    // constants
    private let sendQ = DispatchQueue(label: "FlexAPITester" + ".sendQ") // Queue for sending commands
    private let kConnectionTimeout = 0.5            // timeout in seconds
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    /// Initialize a TcpManager
    ///
    /// - Parameters:
    ///   - tcpQ:       a RadioParameters tuple
    ///   - delegate:   a serial Queue for GCDAsyncSocket activity
    ///
    init(tcpQ: DispatchQueue, delegate: TcpManagerDelegate) {
        
        self._tcpQ = tcpQ
        self._delegate = delegate
        
        super.init()
        
        // get a socket & set it's parameters
        _tcpSocket = GCDAsyncSocket(delegate: self, delegateQueue: _tcpQ)
        _tcpSocket.isIPv4PreferredOverIPv6 = true
        _tcpSocket.isIPv6Enabled = false
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    /// Attempt to connect to the Radio (hardware)
    ///
    /// - Parameters:
    ///   - radioParameters:        a RadioParameters instance
    /// - Returns:                  success / failure
    ///
    public func connect(radioParameters: RadioParameters) -> Bool {
        var success = true
        
        seqNum = 0
        
        do {
            // attempt to connect to the Radio (with timeout)
            try _tcpSocket.connect(toHost: radioParameters.ipAddress, onPort: UInt16(radioParameters.port), withTimeout: kConnectionTimeout)
            
        } catch _ {
            
            success = false
        }
        return success
    }
    /// Disconnect from the Radio (hardware)
    ///
    public func disconnect() {
        
        // tell the socket to close
        _tcpSocket.disconnect()
    }
    /// Send a Command to the Radio (hardware), optionally register to be Notified upon receipt of a Reply
    ///
    /// - Parameters:
    ///   - cmd:            a Command string
    ///   - diagnostic:     whether to add "D" suffix
    ///   - replyTo:        ReplyHandler (if any)
    /// - Returns:          the Sequence Number of the Command
    ///
    public func send(_ cmd: String, diagnostic: Bool = false, replyTo callback: ReplyHandler? = nil) -> Int {
        var lastSeqNum = 0
        var command = ""
        
        sendQ.sync {
            
            // assemble the command
            command =  "C" + "\(diagnostic ? "D" : "")" + "\(self.seqNum)|" + cmd + "\n"
            
//            // optionally, register to be notified
//            if let callback = callback { _delegate.addReplyHandler( String(self.seqNum), replyTuple: (replyTo: callback, command: cmd) ) }
            // register to be notified
            _delegate.addReplyHandler( String(self.seqNum), replyTuple: (replyTo: callback, command: cmd) )
            
            // send it, no timeout, tag = segNum
            self._tcpSocket.write(command.data(using: String.Encoding.utf8, allowLossyConversion: false)!, withTimeout: -1, tag: self.seqNum)
            
            lastSeqNum = seqNum
            
            // increment the Sequence Number
            seqNum += 1
        }
        self._delegate.sentMessage(command)
        
        // return the Sequence Number of the last command
        return lastSeqNum
    }
    /// Read the next data block (with an indefinite timeout)
    ///
    public func readNext() {
        
        _tcpSocket.readData(to: GCDAsyncSocket.lfData(), withTimeout: -1, tag: 0)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - GCDAsyncSocket Delegate methods
    //      Note: all are called on the _tcpQ
    
    /// Called when the TCP/IP connection has been disconnected
    ///
    /// - Parameters:
    ///   - sock:       the disconnected socket
    ///   - err:        the error
    ///
    @objc public func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        
        // Disconnected
        _delegate.tcpState(connected: false, host: sock.connectedHost ?? "", port: sock.connectedPort, error: (err == nil) ? "" : err!.localizedDescription)
    }
    /// Called after the TCP/IP connection has been established
    ///
    /// - Parameters:
    ///   - sock:       the socket
    ///   - host:       the host
    ///   - port:       the port
    ///
    @objc public func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        
        // Connected
        _delegate.tcpState(connected: true, host: sock.connectedHost ?? "", port: sock.connectedPort, error: "")
    }
    /// Called when data has been read from the TCP/IP connection
    ///
    /// - Parameters:
    ///   - sock:       the socket data was received on
    ///   - data:       the Data
    ///   - tag:        the Tag associated with this receipt
    ///
    @objc public func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        
        // get the bytes that were read
        let text = String(data: data, encoding: .ascii)!
        
        // pass them to our delegate
        _delegate.receivedMessage(text)
        
        // trigger the next read
        readNext()
    }
}
