/*
 Copyright 2020 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import AEPServices
import Foundation

/// Represents the state of the `Target` extension
class TargetState {
    private(set) var tntId: String?
    private(set) var thirdPartyId: String?
    private(set) var edgeHost: String?
    private(set) var clientCode: String?
    private(set) var prefetchedMboxJsonDicts = [String: [String: Any]]()
    private(set) var sessionTimestamp: Int64?
    private(set) var sessionTimeout: Int
    private var storedSessionId: String

    var sessionId: String {
        if isSessionExpired() { storedSessionId = UUID().uuidString }
        return storedSessionId
    }

    private let dataStore: NamedCollectionDataStore

    /// Loads the TNT ID and the edge host string from the data store when initializing the `TargetState` object
    init() {
        dataStore = NamedCollectionDataStore(name: TargetConstants.DATASTORE_NAME)
        tntId = dataStore.getString(key: TargetConstants.StorageKeys.TNT_ID)
        edgeHost = dataStore.getString(key: TargetConstants.StorageKeys.EDGE_HOST)
        sessionTimestamp = dataStore.getLong(key: TargetConstants.StorageKeys.SESSION_TIMESTAMP)
        storedSessionId = dataStore.getString(key: TargetConstants.StorageKeys.SESSION_ID) ?? UUID().uuidString
        if let sessionTimeout = dataStore.getInt(key: TargetConstants.StorageKeys.SESSION_TIMEOUT) {
            self.sessionTimeout = sessionTimeout
        } else {
            sessionTimeout = TargetConstants.DEFAULT_SESSION_TIMEOUT
        }
    }

    /// Updates the session timestamp of the latest target API call in memory and in the data store
    func updateSessionTimestamp() {
        sessionTimestamp = Date().getUnixTimeInSeconds()
        dataStore.set(key: TargetConstants.StorageKeys.SESSION_TIMESTAMP, value: sessionTimestamp)
    }

    /// Updates the TNT ID in memory and in the data store
    func updateTntId(_ tntId: String) {
        self.tntId = tntId
        dataStore.set(key: TargetConstants.StorageKeys.TNT_ID, value: tntId)
    }

    /// Updates the edge host in memory and in the data store
    func updateEdgeHost(_ edgeHost: String) {
        self.edgeHost = edgeHost
        dataStore.set(key: TargetConstants.StorageKeys.EDGE_HOST, value: edgeHost)
    }

    /// Generates a `Target` shared state with the stored TNT ID and third party id.
    func generateSharedState() -> [String: Any] {
        var eventData = [String: Any]()
        if tntId != nil { eventData[TargetConstants.EventDataKeys.TNT_ID] = tntId }
        if thirdPartyId != nil { eventData[TargetConstants.EventDataKeys.THIRD_PARTY_ID] = thirdPartyId }
        return eventData
    }

    /// Combines the prefetched mboxes with the cached mboxes
    func mergePrefetchedMboxJson(mboxesDictionary: [String: [String: Any]]) {
        prefetchedMboxJsonDicts = prefetchedMboxJsonDicts.merging(mboxesDictionary) { _, new in new }
    }

    /// Verifies if current target session is expired.
    /// - Returns: whether Target session has expired
    private func isSessionExpired() -> Bool {
        guard let sessionTimestamp = self.sessionTimestamp else {
            return false
        }
        let currentTimestamp = Date().getUnixTimeInSeconds()
        return (currentTimestamp - sessionTimestamp) > sessionTimeout
    }
}
