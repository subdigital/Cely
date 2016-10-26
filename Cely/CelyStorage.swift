//
//  CelyStorage.swift
//  Cely
//
//  Created by Fabian Buentello on 10/14/16.
//  Copyright © 2016 Fabian Buentello. All rights reserved.
//

import Foundation
import Locksmith

internal let kCelyDomain = "cely.storage"
internal let kCelyLocksmithAccount = "cely.secure.storage"
internal let kCelyLocksmithService = "cely.secure.service"
internal let kStore = "store"
internal let kPersisted = "persisted"

public class CelyStorage: CelyStorageProtocol {
    // MARK: - Variables
    static let sharedInstance = CelyStorage()

    var secureStorage: [String : Any] = [:]
    var storage: [String : [String : Any]]  = [:]
    public init() {

        let launchedBefore = UserDefaults.standard.bool(forKey: "launchedBefore")
        if !launchedBefore {
            UserDefaults.standard.set(true, forKey: "launchedBefore")
            removeAllData()
        }

        setupStorage()
        setupSecureStorage()
    }

    fileprivate func setupStorage() {
        let store = UserDefaults.standard.persistentDomain(forName: kCelyDomain) ?? [kStore: [:]]
        UserDefaults.standard.setPersistentDomain(store, forName: kCelyDomain)
        UserDefaults.standard.synchronize()
        if let store = store as? [String : [String : Any]] {
            storage = store
        }
    }

    fileprivate func setupSecureStorage() {
        if let userData = Locksmith.loadDataForUserAccount(userAccount: kCelyLocksmithAccount, inService: kCelyLocksmithService) {
            secureStorage = userData
        }
    }

    /// Removes all data from both `secureStorage` and regular `storage`
    public func removeAllData() {
        CelyStorage.sharedInstance.secureStorage = [:]
        CelyStorage.sharedInstance.storage[kStore] = [:]
        UserDefaults.standard.setPersistentDomain(CelyStorage.sharedInstance.storage, forName: kCelyDomain)
        UserDefaults.standard.synchronize()
        CelyStorage.sharedInstance.storage = [:]
        do {
            try Locksmith.deleteDataForUserAccount(userAccount: kCelyLocksmithAccount, inService: kCelyLocksmithService)
        } catch let error as NSError {
            // handle the error
            print("error: \(error.localizedDescription)")
        }
    }

    /// Saves data to storage
    ///
    /// - parameter value:  `Any?` object you want to save
    /// - parameter key:    `String`
    /// - parameter secure: `Boolean`: If you want to store the data securely. Set to `True` by default
    ///
    /// - returns: `Boolean` on whether or not it successfully saved
    public func set(_ value: Any?, forKey key: String, securely secure: Bool = false, persisted: Bool = false) -> StorageResult {
        guard let val = value else { return .Fail(.undefined) }
        if secure {
            var currentStorage = CelyStorage.sharedInstance.secureStorage
            currentStorage[key] = val
            CelyStorage.sharedInstance.secureStorage = currentStorage
            do {
                // If testing, user `saveData` instead of `updateData`
                if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
                    try Locksmith.saveData(data: currentStorage, forUserAccount: kCelyLocksmithAccount, inService: kCelyLocksmithService)
                    return .Success
                }

                try Locksmith.updateData(data: currentStorage, forUserAccount: kCelyLocksmithAccount, inService: kCelyLocksmithService)
                return .Success
            } catch let storageError as LocksmithError {
                return .Fail(storageError)
            } catch {
                return .Fail(.undefined)
            }
        } else {
            let storage = persisted ? kPersisted : kStore
            CelyStorage.sharedInstance.storage[storage]?[key] = val
            UserDefaults.standard.setPersistentDomain(CelyStorage.sharedInstance.storage, forName: kCelyDomain)
            UserDefaults.standard.synchronize()
        }
        return .Success
    }

    /// Retrieve user data from key
    ///
    /// - parameter key: String
    ///
    /// - returns: Data For key value
    public func get(_ key: String) -> Any? {
        if let value = CelyStorage.sharedInstance.secureStorage[key] {
            return value
        } else if let value = CelyStorage.sharedInstance.storage[kStore]?[key] {
            return value
        } else if let value = CelyStorage.sharedInstance.storage[kPersisted]?[key] {
            return value
        }

        return nil
    }
}
