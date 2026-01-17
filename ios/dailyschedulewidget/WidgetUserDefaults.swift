//
//  WidgetUserDefaults.swift
//  Runner
//
//  Created by xamarin build on 10.12.20.
//  Copyright © 2020 The Chromium Authors. All rights reserved.
//

import Foundation

public class WidgetUserDefaults {
    private let groupName: String = "group.de.bennik2000.dhbwstudentapp"
    private let defaultsKey: String = "isWidgetEnabled"
    
    func isWidgetEnabled() -> Bool {
        return true
    }
    
    func enableWidget() {
        if let userDefaults = UserDefaults(suiteName: groupName) {
            userDefaults.set(true, forKey: defaultsKey)
        }
    }
    
    func disableWidget() {
        if let userDefaults = UserDefaults(suiteName: groupName) {
            userDefaults.set(false, forKey: defaultsKey)
        }
    }
}
