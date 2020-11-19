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

    private let RESPONSE_JSON_KEY_MESSAGE = "message"

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
        guard let configuration = getSharedState(extensionName: TargetConstants.SharedState.CONFIGURATION, event: event), configuration.status == .set else { return false }
        guard getSharedState(extensionName: TargetConstants.SharedState.LIFECYCLE, event: event)?.status == .set else { return false }
        guard getSharedState(extensionName: TargetConstants.SharedState.IDENTITY, event: event)?.status == .set else { return false }
        guard let clientCode = configuration.value?[TargetConstants.SharedState.keys.TARGET_CLIENT_CODE] as? String, !clientCode.isEmpty else {
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
        guard let prefetchDictArray = event.data?[TargetConstants.EventDataKeys.PREFETCH_REQUESTS] as? [[String: Any]], let targetPrefetchArray = decodePrefetchDict(prefetchDictArray) else {
            dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Empty or null prefetch requests list")
            return
        }
        // eventData[TargetConstants.EventDataKeys.TARGET_PARAMETERS]

        guard let configuration = getSharedState(extensionName: TargetConstants.SharedState.CONFIGURATION, event: event)?.value else {
            dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Missing shared state - configuration")
            return
        }
        guard let privacy = configuration[TargetConstants.SharedState.keys.GLOBAL_CONFIG_PRIVACY] as? String, privacy == TargetConstants.SharedState.values.GLOBAL_CONFIG_PRIVACY_OPT_IN else {
            dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Privacy status is opted out")
            return
        }
        guard let lifecycle = getSharedState(extensionName: TargetConstants.SharedState.LIFECYCLE, event: event)?.value else {
            dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Missing shared state - lifecycle")
            return
        }
        guard let identity = getSharedState(extensionName: TargetConstants.SharedState.IDENTITY, event: event)?.value else {
            dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Missing shared state - identity")
            return
        }

        var mboxes = [Mbox]()
        for prefetch in targetPrefetchArray {
            mboxes.append(prefetch.convert())
        }
        let requestObj = TargetJson(id: nil, context: nil, prefetch: Prefetch(mboxes: mboxes))

        let headers = [HEADER_CONTENT_TYPE: HEADER_CONTENT_TYPE_JSON]
        let request = NetworkRequest(url: URL(string: "")!, httpMethod: .post, connectPayload: "", httpHeaders: headers, connectTimeout: DEFAULT_NETWORK_TIMEOUT, readTimeout: DEFAULT_NETWORK_TIMEOUT)
        networkService.connectAsync(networkRequest: request) { connection in
            guard let data = connection.data, let responseDict = try? JSONDecoder().decode([String: AnyCodable].self, from: data), let dict: [String: Any] = AnyCodable.toAnyDictionary(dictionary: responseDict) else {
                self.dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Target response parser initialization failed")
                return
            }

            if connection.responseCode != 200, let error = dict[self.RESPONSE_JSON_KEY_MESSAGE] as? String {
                self.dispatchPrefetchErrorEvent(triggerEvent: event, errorMessage: "Errors returned in Target response: \(error)")
            }
            
            if dict[]
            
            // TODO: updateSessionTimestamp
            // TODO: set tntid, edgehost
            // TODO: create shared state
            // TODO: retrieve batchedMboxes
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

    internal func decodePrefetchDict(_ dicts: [[String: Any]]) -> [TargetPrefetch]? {
        var prefetches = [TargetPrefetch]()
        for dict in dicts {
            if let prefetch = TargetPrefetch.from(dictionary: dict) {
                prefetches.append(prefetch)
            }
        }
        return prefetches
    }
}
