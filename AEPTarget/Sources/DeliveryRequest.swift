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
import AEPIdentity
import AEPServices
import Foundation

class DeliveryRequestBuilder {
    private static let CHANNEL_MOBILE = "mobile"
    private static let COLOR_DEPTH_32 = 32

    private static var systemInfoService: SystemInfoService {
        ServiceProvider.shared.systemInfoService
    }

    static func build(tntid: String?, thirdPartyId: String?, identitySharedState: [String: Any], configurationSharedState _: [String: Any], lifecycleSharedState: [String: Any], targetPrefetchArray: [TargetPrefetch], targetParameters: TargetParameters?) -> DeliveryRequest? {
        let targetIDs = generateTargetIDsBy(tntid: tntid, thirdPartyId: thirdPartyId, identitySharedState: identitySharedState)
        let prefetch = generatePrefetchBy(targetPrefetchArray: targetPrefetchArray, lifecycleSharedState: lifecycleSharedState, globalParameters: targetParameters)
        let experienceCloud = generateExperienceCloudInfoBy(identitySharedState)
        guard let context = generateTargetContextBy() else {
            return nil
        }
        return DeliveryRequest(id: targetIDs, context: context, experienceCloud: experienceCloud, prefetch: prefetch)
    }

    private static func generateTargetIDsBy(tntid: String?, thirdPartyId: String?, identitySharedState: [String: Any]) -> TargetIDs? {
        let customerIds = identitySharedState[TargetConstants.IDENTITY.SharedState.Keys.VISITOR_ID_MID] as? [CustomIdentity]
        return TargetIDs(tntId: tntid, thirdPartyId: thirdPartyId, marketingCloudVisitorId: identitySharedState[TargetConstants.IDENTITY.SharedState.Keys.VISITOR_ID_MID] as? String, customerIds: CustomerID.from(customIdentities: customerIds))
    }

    private static func generateExperienceCloudInfoBy(_ identitySharedState: [String: Any]) -> ExperienceCloudInfo? {
        let audienceManager = AudienceManagerInfo(blob: identitySharedState[TargetConstants.IDENTITY.SharedState.Keys.VISITOR_ID_BLOB] as? String, locationHint: identitySharedState[TargetConstants.IDENTITY.SharedState.Keys.VISITOR_ID_LOCATION_HINT] as? Int)
        let analytics = AnalyticsInfo(logging: .client_side)
        return ExperienceCloudInfo(audienceManager: audienceManager, analytics: analytics)
    }

    private static func generateTargetContextBy() -> TargetContext? {
        // TODO: systemInfoService.getDeviceType() ??
        let mobilePlatform = MobilePlatform(deviceName: systemInfoService.getDeviceName(), deviceType: .phone, platformType: .ios)
        // TODO: systemInfoService.getApplicationPackageName() ???
        // TODO: systemInfoService.getApplicationVersion() ??
        let application = AppInfo(id: nil, name: systemInfoService.getApplicationName(), version: nil)
        // TODO: systemInfoService.getCurrentOrientation() ??
        let screen = Screen(colorDepth: COLOR_DEPTH_32, width: systemInfoService.getDisplayInformation().width, height: systemInfoService.getDisplayInformation().height, orientation: nil)
        return TargetContext(channel: CHANNEL_MOBILE, userAgent: systemInfoService.getDefaultUserAgent(), mobilePlatform: mobilePlatform, application: application, screen: screen, timeOffsetInMinutes: Date().getUnixTimeInSeconds())
    }

    private static func generatePrefetchBy(targetPrefetchArray: [TargetPrefetch], lifecycleSharedState: [String: Any], globalParameters: TargetParameters?) -> Prefetch? {
        guard let lifecycleDataDict = lifecycleSharedState as? [String: String] else {
            // TODO: log
            return nil
        }

        var mboxes = [Mbox]()

        for (index, prefetch) in targetPrefetchArray.enumerated() {
            let parameterWithLifecycleData = merge(newDictionary: lifecycleDataDict, to: prefetch.targetParameters?.parameters)
            let parameters = merge(newDictionary: globalParameters?.parameters, to: parameterWithLifecycleData)
            let profileParameters = merge(newDictionary: globalParameters?.profileParameters, to: prefetch.targetParameters?.profileParameters)
            let order = findFirstExistingOrder(order: prefetch.targetParameters?.order, globalOrder: globalParameters?.order)
            let product = findFirstExistingProduct(product: prefetch.targetParameters?.product, globalProduct: globalParameters?.product)
            let mbox = Mbox(name: prefetch.name, index: index, parameters: parameters, profileParameters: profileParameters, order: order, product: product)
            mboxes.append(mbox)
        }
        return Prefetch(mboxes: mboxes)
    }

    private static func merge(newDictionary: [String: String]?, to dictionary: [String: String]?) -> [String: String]? {
        if let newDictionary = newDictionary, let dictionary = dictionary {
            return dictionary.merging(newDictionary) { _, new in new }
        }

        if let newDictionary = newDictionary {
            return newDictionary
        }

        if let dictionary = dictionary {
            return dictionary
        }

        return nil
    }

    private static func findFirstExistingOrder(order: TargetOrder?, globalOrder: TargetOrder?) -> Order? {
        if let order = order {
            return order.convert()
        }
        if let globalOrder = globalOrder {
            return globalOrder.convert()
        }
        return nil
    }

    private static func findFirstExistingProduct(product: TargetProduct?, globalProduct: TargetProduct?) -> Product? {
        if let product = product {
            return product.convert()
        }
        if let globalProduct = globalProduct {
            return globalProduct.convert()
        }
        return nil
    }
}

struct DeliveryRequest: Codable {
    var id: TargetIDs?
    var context: TargetContext
    var experienceCloud: ExperienceCloudInfo?
    var prefetch: Prefetch?
    func toJSON() -> String? {
        return nil
    }
}

struct ExperienceCloudInfo: Codable {
    var audienceManager: AudienceManagerInfo?
    var analytics: AnalyticsInfo?
}

struct AudienceManagerInfo: Codable {
    var blob: String?
    var locationHint: Int?

    init?(blob: String?, locationHint: Int?) {
        if blob == nil, locationHint == nil {
            return nil
        }
        self.blob = blob
        self.locationHint = locationHint
    }
}

struct AnalyticsInfo: Codable {
    var logging: AnalyticsLogging?
}

enum AnalyticsLogging: String, Codable {
    case server_side
    case client_side
}

struct TargetIDs: Codable {
    var tntId: String?
    var thirdPartyId: String?
    var marketingCloudVisitorId: String?
    var customerIds: [CustomerID]?
}

struct CustomerID: Codable {
    var id: String
    var integrationCode: String
    var authenticatedState: AuthenticatedState

    static func from(customIdentities: [CustomIdentity]?) -> [CustomerID]? {
        guard let customIdentities = customIdentities else {
            return nil
        }

        var customerIDs = [CustomerID]()
        for customIdentity in customIdentities {
            guard let id = customIdentity.identifier, let code = customIdentity.type else {
                continue
            }
            customerIDs.append(CustomerID(id: id, integrationCode: code, authenticatedState: AuthenticatedState.from(authenticationState: customIdentity.authenticationState)))
        }
        return customerIDs
    }
}

enum AuthenticatedState: String, Codable {
    case unknown
    case authenticated
    case logged_out
    static func from(authenticationState: MobileVisitorAuthenticationState) -> AuthenticatedState {
        switch authenticationState {
        case .authenticated:
            return AuthenticatedState.authenticated
        case .loggedOut:
            return AuthenticatedState.logged_out
        default:
            return AuthenticatedState.unknown
        }
    }
}

struct TargetContext: Codable {
    var channel: String
    var userAgent: String?
    var mobilePlatform: MobilePlatform?
    var application: AppInfo?
    var screen: Screen?
    var timeOffsetInMinutes: Int64?
}

struct Screen: Codable {
    var colorDepth: Int?
    var width: Int?
    var height: Int?
    var orientation: AppOrientation?
}

enum AppOrientation: String, Codable {
    case portrait
    case landscape
}

struct MobilePlatform: Codable {
    var deviceName: String?
    var deviceType: DeviceType
    var platformType: PlatformType
}

struct AppInfo: Codable {
    var id: String?
    var name: String?
    var version: String?
}

enum DeviceType: String, Codable {
    case phone
    case tablet
}

enum PlatformType: String, Codable {
    case android
    case ios
}

struct Mbox: Codable {
    var name: String?
    var index: Int
    var parameters: [String: String]?
    var profileParameters: [String: String]?
    var order: Order?
    var product: Product?
}

struct Notification: Codable {
    var id: String
    var timestamp: String
    var type: String
    var mbox: String?
}

struct Product: Codable {
    var id: String?
    var categoryId: String?
}

struct Order: Codable {
    var id: String
    var total: Double?
    var purchasedProductIds: [String]?
}

struct Prefetch: Codable {
    var mboxes: [Mbox]?
}
