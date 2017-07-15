//
//  UdpManager.swift
//  xFlexAPI
//
//  Created by Douglas Adams on 8/15/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Foundation

// ------------------------------------------------------------------------------
// MARK: - UDP Manager Class implementation
//
//      manages all Udp communication between the API and the Radio (hardware)
//
// ------------------------------------------------------------------------------

protocol UdpManagerDelegate {
    
    // if any of theses are not needed, implement a stub in the delegate that does nothing
    
    func udpState(bound: Bool, port: UInt16, error: String)
    func udpStream(active: Bool)
    func udpError(_ message: String)

    // Vita handler methods
    func meterVitaHandler(_ vitaPacket: Vita)
    func panadapterVitaHandler(_ vitaPacket: Vita)
    func waterfallVitaHandler(_ vitaPacket: Vita)
    func opusVitaHandler(_ vitapacket: Vita)
    func daxVitaHandler(_ vitapacket: Vita)
    func daxIqVitaHandler(_ vitapacket: Vita)
}

public final class UdpManager: NSObject, GCDAsyncUdpSocketDelegate {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    public private(set) var port: UInt16 = 0            // actual Vita port number
    public private(set) var canBroadcast = true         // True if Broadcast permitted
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private var _parameters: RadioParameters            // Struct of Radio parameters
    private var _udpReceiveQ: DispatchQueue!            // serial GCD Queue for inbound UDP traffic
    private var _udpSendQ: DispatchQueue!               // serial GCD Queue for outbound UDP traffic
    private var _delegate: UdpManagerDelegate           // class to receive UDP data

    private var _udpSocket: GCDAsyncUdpSocket!          // socket for Vita UDP data
    private var _udpSendSocket: GCDAsyncUdpSocket?      // socket for sending Vita UDP data
    private var _streamTimer: DispatchSourceTimer!      // periodic timer for stream activity
    
    // constants
    private let kBroadcastAddress = "255.255.255.255"
    private let kUdpSendPort: UInt16 = 4991
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    /// Initialize a UdpManager
    ///
    /// - Parameters:
    ///   - radioParameters:    a RadioParameters tuple
    ///   - udpReceiveQ:        a serial Q for GCDAsyncUdpSocket activity
    ///
    init(radioParameters: RadioParameters, udpReceiveQ: DispatchQueue, udpSendQ: DispatchQueue, delegate: UdpManagerDelegate, udpPort: UInt16 = 4991, enableBroadcast: Bool = false) {
        
        _parameters = radioParameters
        _udpReceiveQ = udpReceiveQ
        _udpSendQ = udpSendQ
        _delegate = delegate
        port = udpPort
        
        super.init()
        
        // create the timer's dispatch source
        _streamTimer = DispatchSource.makeTimerSource(flags: [.strict], queue: _udpReceiveQ)
        
        // get a socket
        _udpSocket = GCDAsyncUdpSocket(delegate: self, delegateQueue: _udpReceiveQ)
        _udpSocket.setIPv4Enabled(true)
        _udpSocket.setIPv6Enabled(false)
        
        if enableBroadcast {
            do {
                try _udpSocket.enableBroadcast(true)
            } catch {
                canBroadcast = false
            }
        }
        
        // get a socket for sending Vita Data
        _udpSendSocket = GCDAsyncUdpSocket(delegate: self, delegateQueue: _udpSendQ)
        _udpSendSocket?.setIPv4Enabled(true)
        _udpSendSocket?.setIPv6Enabled(false)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    /// Send a Broadcast
    ///
    /// - Parameters:
    ///   - data:       a Vita-49 packet as Data
    ///
    public func sendBroadcast(data: Data) {
        
        _udpSendSocket?.send(data, toHost: kBroadcastAddress, port: port, withTimeout: -1, tag: 0)
    }
    /// Send Vita packet to radio
    ///
    /// - Parameters:
    ///   - data:       a Vita-49 packet as Data
    ///
    public func sendData(_ data: Data) {
        
        _udpSendSocket?.send(data, withTimeout: -1, tag: 0)
    }
    /// Bind to the UDP Port
    ///
    public func bind() {
        var success = false
        
        // start from the Vita Default port number
        var tmpPort = port
        
        // Find a port, scan from the default Port Number up looking for an available port
        for _ in 0..<20 {
            do {
                try _udpSocket.bind(toPort: tmpPort)
                
                success = true
                break
                
            } catch let error {
                
                // We didn't get the port we wanted
                _delegate.udpError("Unable to bind to UDP port = \(tmpPort) - \(error.localizedDescription)")
                
                // try the next Port Number
                tmpPort += 1
            }
        }
        // capture the number of the actual port in use
        port = tmpPort
        
        // connect send socket
        do {
            try _udpSendSocket?.connect(toHost: _parameters.ipAddress, onPort: kUdpSendPort)
        } catch let error {
            
            _delegate.udpError("Unable to connect to UDP address = \(_parameters.ipAddress ) (port \(kUdpSendPort)) - \(error.localizedDescription)")
            // FIXME: implement logic to try again later
            _udpSendSocket?.close()
            _udpSendSocket = nil
        }
        // change the state
        _delegate.udpState(bound: success, port: port, error: success ? "" : "Unable to bind")
        _delegate.udpStream(active: success)
    }
    
    public func beginReceiving() {
        
        do {
            // Begin receiving
            try _udpSocket.beginReceiving()
            
        } catch let error {
            // read error
            _delegate.udpError("beginReceiving error - \(error.localizedDescription)")
        }
    }
    /// Unbind from the UDP port
    ///
    public func unbind() {
        
        // tell the receive socket to close
        _udpSocket.close()
        
        // tell the send socket to close
        _udpSendSocket?.close()
        _udpSendSocket = nil

        _delegate.udpState(bound: false, port: 0, error: "")
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - GCDAsyncUdpSocket Protocol methods methods
    //     Note: called on the udpReceiveQ Queue
    
    /// Called when data has been read from the UDP connection
    ///
    /// - Parameters:
    ///   - sock:          the receiving socket
    ///   - data:          the data received
    ///   - address:       the Host address
    ///   - filterContext: a filter context (if any)
    ///
    @objc public func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        
        if let vitaPacket = Vita.decode(vitaPacket: data) {
            
            // restart the timer
            _streamTimer.scheduleRepeating(deadline: DispatchTime.now(), interval: .seconds(1), leeway: .milliseconds(100))      // Every second +/- 10%
            
            // set the event handler
            _streamTimer.setEventHandler { [ unowned self] in
                
                // timer fired, UDP stream timed out, tell the delegate
                self._delegate.udpStream(active: false)
            }
            
            // TODO: Packet statistics - received, dropped
            
            // TODO: check OUI
            
            switch vitaPacket.packetType {
                
            case .ifData, .extData, .ifContext, .extContext:
                // pass the error to the delegate
                _delegate.udpError("Unexpected packetType - \(vitaPacket.packetType.rawValue)")
                
            case .ifDataWithStream:
                
                // Stream of data - figure out what type and call the dispatcher
                switch (vitaPacket.classCode) {
                    
                case .daxIq24, .daxIq48, .daxIq96, .daxIq192:
                    // pass the data to the vita handler
                    _delegate.daxIqVitaHandler(vitaPacket)
                
                default:
                    // pass the error to the delegate
                    _delegate.udpError("IfDataWithStream with unexpected packetType - \(vitaPacket.packetType.rawValue)")
                }
                
            case .extDataWithStream:
                
                // Stream of data - figure out what type and call the dispatcher
                switch (vitaPacket.classCode) {
                    
                case .daxAudio:
                    // pass the data to the vita handler
                    _delegate.daxVitaHandler(vitaPacket)
                    
//                case .discovery:
//                    // FIXME: Class Code not in use
//                    print("UDP - discovery")
//                    break
                    
                case .meter:
                    // pass the data to the vita handler
                    _delegate.meterVitaHandler(vitaPacket)
                    
                case .opus:
                    // pass the data to the vita handler
                    _delegate.opusVitaHandler(vitaPacket)
                    
                case .panadapter:
                    // pass the data to the vita handler
                    _delegate.panadapterVitaHandler(vitaPacket)
                    
                case .waterfall:
                    // pass the data to the vita handler
                    _delegate.waterfallVitaHandler(vitaPacket)
                    
                default:
                    // pass the error to the delegate
                    _delegate.udpError("ExtDataWithStream with unexpected packetType - \(vitaPacket.packetType.rawValue)")
                }
            }
        } else {
            // pass the error to the delegate
            _delegate.udpError("Invalid packet received")
        }
    }
    
}
