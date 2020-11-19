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
import Foundation

struct TargetJson: Codable {
    var id: TargetId?
    var context: TargetContext?
    var prefetch: Prefetch?
//    var mboxes: [Mbox]?
//    var aamParameters: AAMParametersNode?
}

struct TargetId: Codable {
    var tntId: String?
    var thirdPartyId: String?
    var marketingCloudVisitorId: String?
    var customerIds: [CustomerId]?
}

struct CustomerId: Codable {
    var id: String
    var integrationCode: String
    var authenticatedState: String
}

struct TargetContext: Codable {}

struct AAMParameters: Codable {}
struct Mbox: Codable {
    var name: String?
    var index: Int?
    var state: String?
    var at_property: String?
    var parameters: [String: String]?
    var profileParameters: [String: String]?
    var order: Order?
    var product: Product?
}

struct Option: Codable {
    var type: String?
    var content: String?
}

struct Metric: Codable {
    var type: MetricType?
    var eventToken: String?
}

enum MetricType: String, Codable {
    case display
    case click
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
