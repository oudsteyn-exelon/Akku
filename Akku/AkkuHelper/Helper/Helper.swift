//
//  Helper.swift
//  SwiftPrivilegedHelper / Akku
//
//  Copyright © 2018 Erik Berglund. All rights reserved.
//  Copyright © 2018 Jari Zwarts. All rights reserved.
//

import Foundation

class Helper: NSObject, NSXPCListenerDelegate, HelperProtocol {

    // MARK: -
    // MARK: Private Constant Variables

    private let listener: NSXPCListener

    // MARK: -
    // MARK: Private Variables

    private var connections = [NSXPCConnection]()
    private var shouldQuit = false
    private var shouldQuitCheckInterval = 1.0
    private var driver: Driver? = nil

    // MARK: -
    // MARK: Initialization

    override init() {
        self.listener = NSXPCListener(machServiceName: HelperConstants.machServiceName)
        super.init()
        self.listener.delegate = self
    }

    public func run() {
        self.listener.resume()
        
        // --- HACK ---
        startListening { (_) in
            print("listening")
        }
        // ------------

        // Keep the helper tool running until the variable shouldQuit is set to true.
        // The variable should be changed in the "listener(_ listener:shoudlAcceptNewConnection:)" function.

        while !self.shouldQuit {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: self.shouldQuitCheckInterval))
        }
    }

    // MARK: -
    // MARK: NSXPCListenerDelegate Methods

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {

        // Verify that the calling application is signed using the same code signing certificate as the helper
        guard self.isValid(connection: connection) else {
            return false
        }

        // Set the protocol that the calling application conforms to.
        connection.remoteObjectInterface = NSXPCInterface(with: AppProtocol.self)

        // Set the protocol that the helper conforms to.
        connection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.exportedObject = self

        // Set the invalidation handler to remove this connection when it's work is completed.
        connection.invalidationHandler = {
            if let connectionIndex = self.connections.firstIndex(of: connection) {
                self.connections.remove(at: connectionIndex)
            }

            if self.connections.isEmpty {
                self.shouldQuit = true
            }
        }

        self.connections.append(connection)
        connection.resume()

        return true
    }

    // MARK: -
    // MARK: HelperProtocol Methods

    func getVersion(completion: (String) -> Void) {
        completion(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0")
    }

    func startListening(completion: @escaping (Error?) -> Void) {
        let driver = Driver()
        do {
            try driver.open()
            try driver.process()
            try driver.waitForData()
        } catch {
            completion(error)
            return
        }
        self.driver = driver
        completion(nil)
    }

    // MARK: -
    // MARK: Private Helper Methods

    private func isValid(connection: NSXPCConnection) -> Bool {
        do {
            return try CodesignCheck.codeSigningMatches(pid: connection.processIdentifier)
        } catch {
            NSLog("Code signing check failed with error: \(error)")
            return false
        }
    }

    private func connection() -> NSXPCConnection? {
        return self.connections.last
    }
}