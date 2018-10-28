//
//  StatusMenuController.swift
//  Akku
//
//  Created by Jari on 25/10/2018.
//  Copyright © 2018 JARI.IO. All rights reserved.
//

import Foundation
import Cocoa
import IOBluetooth

class StatusMenuController: NSObject {
    
    // MARK: Private vars
    
    private var popover: NSPopover?;
    private var menu: NSMenu?;
    
    // MARK: Private constants
    
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    // MARK: -
    // MARK: Lifecycle
    
    func initStatusItem () {
        // we don't initialize the statusitem on init
        // because we want to defer that until AppDelegate is done checking the helper status
        
        guard let button = statusItem.button else {
            return
        }
        button.image = #imageLiteral(resourceName: "akku_noconnect")
        button.target = self
        
        if let popover = self.popover, popover.isShown {
            self.closePopover(nil)
        }
        
        let delegate = NSApplication.shared.delegate as! AppDelegate
        OperationQueue.main.addOperation {
            if delegate.helperIsInstalled {
                self.initMenu()
            } else {
                button.action = #selector(StatusMenuController.togglePopover(_:))
                self.initPopover()
                self.showPopover()
            }
        }
    }
    
    // MARK: -
    // MARK: Menu control functions
    
    func initMenu () {
        menu = NSMenu(title: "Akku status")
        statusItem.menu = menu!;
        
        buildMenu()
        
        IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(buildMenu))
//        NotificationCenter.default.addObserver(self, selector: #selector(batteryStateChange(notification:)), name: Notification.Name("BatteryStateChange"), object: nil)
    }
    
//    @objc func batteryStateChange (notification: NSNotification) {
//        if let body = notification.object as? [String: String], let address = body["address"] {
//            batteryStates[address] = body["charge"]
//            buildMenu()
//        }
//    }
    
    @objc func warnSettingChange (sender: NSMenuItem) {
        UserDefaults.standard.set(sender.title, forKey: "warnAt")
        
        buildMenu()
    }
    
    @objc func buildMenu () {
        guard let menu = self.menu else {
            return
        }
        
        menu.removeAllItems()
        
        let devices = (IOBluetoothDevice.pairedDevices() as! [IOBluetoothDevice])
            .filter { $0.isConnected() && $0.isHandsFreeDevice }
        
        guard devices.count != 0 else {
            menu.addItem(withTitle: "No connected handsfree devices.", action: nil, keyEquivalent: "")
            statusItem.button!.image = NSImage(named: NSImage.Name("akku_noconnect"))
            buildSettings()
            return
        }
        
        for device in devices {
            menu.addItem(withTitle: device.name, action: nil, keyEquivalent: "")
            let batteryMenuItem = NSMenuItem()
//            if let rawState = batteryStates[device.addressString], let state = Double(rawState) {
//                let batteryViewController = storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("ViewController")) as! ViewController
//                batteryViewController.setProgress(value: state)
//                batteryMenuItem.view = batteryViewController.view
//                statusItem.button!.image = NSImage(named: NSImage.Name("akku_" + rawState))
//            } else {
                batteryMenuItem.title = "No reported battery state yet, try reconnecting."
                statusItem.button!.image = NSImage(named: NSImage.Name("akku_noconnect"))
//            }
            menu.addItem(batteryMenuItem)
            
            device.register(forDisconnectNotification: self, selector: #selector(buildMenu))
        }
        
        buildSettings()
    }
    
    func buildSettings () {
        guard let menu = self.menu else { return }
        
        menu.addItem(NSMenuItem.separator())
        
        let warnAtItem = NSMenuItem(title: "Show notification at...", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "Show notification at")
        func addWarnAtItem(value: String) {
            var warnAt = UserDefaults.standard.string(forKey: "warnAt")
            if warnAt == nil {
                warnAt = "10%"
            }
            let item = NSMenuItem(title: value, action: #selector(warnSettingChange(sender:)), keyEquivalent: "")
            item.target = self
            item.state = warnAt == value ? .on : .off
            submenu.addItem(item)
        }
        
        for i in 0...4 {
            addWarnAtItem(value: String(describing: i * 10) + "%")
        }
        
        warnAtItem.submenu = submenu
        menu.addItem(warnAtItem)
    }
    
    // MARK: -
    // MARK: Popover control functions
    
    func initPopover () {
        popover = NSPopover()
        popover!.contentViewController = HelperInstaller(nibName: NSNib.Name("HelperInstaller"), bundle: nil)
    }
    
    func showPopover () {
        guard let button = statusItem.button,
        let popover = self.popover else {
            return
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
    }
    
    func closePopover(_ sender: Any?) {
        popover!.performClose(sender)
    }
    
    @objc func togglePopover(_ sender: Any) {
        guard let popover = self.popover else { return }
        
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover()
        }
    }

}