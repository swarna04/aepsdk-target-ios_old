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

import AEPCore
import AEPServices
import Foundation

@objc(AEPMobileTarget)
public class Target: NSObject, Extension {
    static let LOG_TAG = "Target"

    private var DEFAULT_NETWORK_TIMEOUT: TimeInterval = 2.0

    private let HEADER_CONTENT_TYPE = "Content-Type"

    private let HEADER_CONTENT_TYPE_JSON = "application/json"

    private let dataStore: NamedCollectionDataStore

    private var tntId: String?

    private var thirdPartyId: String?

    private var edgeHost: String?

    private var clientCode: String?

    private var prefetchedMboxJsonDicts = [[String: Any]]()

    private var networkService: Networking {
        return ServiceProvider.shared.networkService
    }

    // MARK: - Extension

    public var name = TargetConstants.EXTENSION_NAME

    public var friendlyName = TargetConstants.FRIENDLY_NAME

    public static var extensionVersion = TargetConstants.EXTENSION_VERSION

    public var metadata: [String: String]?

    public var runtime: ExtensionRuntime

    public required init?(runtime: ExtensionRuntime) {
        self.runtime = runtime
        dataStore = NamedCollectionDataStore(name: TargetConstants.DATASTORE_NAME)
        super.init()
    }

    public func onRegistered() {
        registerListener(type: EventType.target, source: EventSource.requestContent) { event in
            switch event.name {
            case TargetConstants.EventName.PREFETCH_REQUESTS:
                self.prefetchContent(event)
            default:
                Log.debug(label: Target.LOG_TAG, "Unknown event: \(event)")
            }
        }
        registerListener(type: EventType.target, source: EventSource.requestReset, listener: handle)
        registerListener(type: EventType.target, source: EventSource.requestIdentity, listener: handle)
        registerListener(type: EventType.configuration, source: EventSource.responseContent, listener: handle)
        registerListener(type: EventType.genericData, source: EventSource.os, listener: handle)
    }

    public func onUnregistered() {}

    public func readyForEvent(_ event: Event) -> Bool {
        guard let configuration = getSharedState(extensionName: TargetConstants.CONFIGURATION.EXTENSION_NAME, event: event), configuration.status == .set else { return false }
        guard getSharedState(extensionName: TargetConstants.LIFECYCLE.EXTENSION_NAME, event: event)?.status == .set else { return false }
        guard getSharedState(extensionName: TargetConstants.IDENTITY.EXTENSION_NAME, event: event)?.status == .set else { return false }
        guard let clientCode = configuration.value?[TargetConstants.SharedState.Keys.TARGET_CLIENT_CODE] as? String, !clientCode.isEmpty else {
            return false
        }
        return true
    }

    // MARK: - Event Listeners

    private func handle(event _: Event) {}

    private func prefetchContent(_ event: Event) {
        guard !isInPreviewMode() else {
            dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Target prefetch can't be used while in preview mode")
            return
        }
        guard let targetPrefetchArray = TargetPrefetch.from(dicts: event.data?[TargetConstants.EventDataKeys.PREFETCH_REQUESTS] as? [[String: Any]]) else {
            dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Empty or null prefetch requests list")
            return
        }

        let targetParameters = TargetParameters.from(dictionary: event.data?[TargetConstants.EventDataKeys.TARGET_PARAMETERS] as? [String: Any])

        // eventData[TargetConstants.EventDataKeys.TARGET_PARAMETERS]

        guard let configurationSharedState = getSharedState(extensionName: TargetConstants.CONFIGURATION.EXTENSION_NAME, event: event)?.value else {
            dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Missing shared state - configuration")
            return
        }
        guard let privacy = configurationSharedState[TargetConstants.CONFIGURATION.SharedState.Keys.GLOBAL_CONFIG_PRIVACY] as? String, privacy == TargetConstants.CONFIGURATION.SharedState.Values.GLOBAL_CONFIG_PRIVACY_OPT_IN else {
            dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Privacy status is opted out")
            return
        }
        guard let lifecycleSharedState = getSharedState(extensionName: TargetConstants.LIFECYCLE.EXTENSION_NAME, event: event)?.value else {
            dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Missing shared state - lifecycle")
            return
        }
        guard let identitySharedState = getSharedState(extensionName: TargetConstants.IDENTITY.EXTENSION_NAME, event: event)?.value else {
            dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Missing shared state - identity")
            return
        }
        // TODO: retrieve tntid from prefetch response
        // TODO: retrieve thirdPartyId from public api call
        guard let requestJson = DeliveryRequestBuilder.build(tntid: nil, thirdPartyId: nil, identitySharedState: identitySharedState, configurationSharedState: configurationSharedState, lifecycleSharedState: lifecycleSharedState, targetPrefetchArray: targetPrefetchArray, targetParameters: targetParameters)?.toJSON() else {
            dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Failed to generate request parameter(JSON) for target delivery API")
            return
        }
        let headers = [HEADER_CONTENT_TYPE: HEADER_CONTENT_TYPE_JSON]
        // https://developers.adobetarget.com/api/delivery-api/#tag/Delivery-API
        let request = NetworkRequest(url: URL(string: "")!, httpMethod: .post, connectPayload: requestJson, httpHeaders: headers, connectTimeout: DEFAULT_NETWORK_TIMEOUT, readTimeout: DEFAULT_NETWORK_TIMEOUT)
        networkService.connectAsync(networkRequest: request) { connection in
            guard let data = connection.data, let responseDict = try? JSONDecoder().decode([String: AnyCodable].self, from: data), let dict: [String: Any] = AnyCodable.toAnyDictionary(dictionary: responseDict) else {
                self.dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Target response parser initialization failed")
                return
            }
            let response = DeliveryResponse(responseJson: dict)

            if connection.responseCode != 200, let error = response.errorMessage {
                self.dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Errors returned in Target response: \(error)")
            }

            self.updateSessionTimestamp()

            if let tntId = response.tntId {
                self.dataStore.set(key: TargetConstants.StorageKeys.TNT_ID, value: tntId)
                self.tntId = tntId
            }

            if let edgeHost = response.edgeHost {
                self.dataStore.set(key: TargetConstants.StorageKeys.EDGE_HOST, value: edgeHost)
                self.edgeHost = edgeHost
            }

            var eventData = [String: Any]()
            if self.tntId != nil { eventData[TargetConstants.EventDataKeys.TNT_ID] = self.tntId }
            if self.thirdPartyId != nil { eventData[TargetConstants.EventDataKeys.THIRD_PARTY_ID] = self.thirdPartyId }

            self.createSharedState(data: eventData, event: nil)
            
            if let mboxes = response.mboxes {
                for mbox in mboxes {
                    self.prefetchedMboxJsonDicts.append(mbox)
                }
            }

            // TODO: removeDuplicateLoadedMboxes
            // TODO: notifications.clear()
        }
    }

    // MARK: - Helpers

    private func dispatchPrefetchErrorEvent(triggerEvent: Event, errorMessage: String) {
        // TODO: log
        dispatch(event: triggerEvent.createResponseEvent(name: TargetConstants.EventName.PREFETCH_RESPOND, type: EventType.userProfile, source: EventSource.responseProfile, data: [TargetConstants.EventDataKeys.PREFETCH_ERROR: errorMessage]))
    }

    private func isInPreviewMode() -> Bool {
        // TODO:
        return false
    }

    private func updateSessionTimestamp() {
        let timestamp = Date().getUnixTimeInSeconds()
        dataStore.set(key: TargetConstants.StorageKeys.SESSION_TIMESTAMP, value: timestamp)
    }
}
