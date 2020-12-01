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

struct DeliveryResponse {
    let responseJson: [String: Any]

    var errorMessage: String? {
        responseJson[TargetResponse.JSONKeys.MESSAGE] as? String
    }

    var tntId: String? {
        guard let ids = responseJson[TargetResponse.JSONKeys.ID] as? [String: String] else {
            return nil
        }
        return ids[TargetResponse.JSONKeys.TNT_ID]
    }

    var edgeHost: String? {
        responseJson[TargetResponse.JSONKeys.EDGE_HOST] as? String
    }

    var mboxes: [[String: Any]]? {
        if let prefetch = responseJson[TargetResponse.JSONKeys.PREFETCH] as? [String: Any], let mboxes = prefetch[TargetResponse.JSONKeys.MBOXES] as? [[String: Any]] {
            return mboxes
        }
        return nil
    }
}

enum TargetResponse {
    enum JSONKeys {
        static let MESSAGE = "message"
        static let ID = "id"
        // ---- id -----
        static let TNT_ID = "tntId"
        // ---- id -----
        static let EDGE_HOST = "edgeHost"
        static let PREFETCH = "prefetch"
        // ---- prefetch -----
        static let MBOXES = "mboxes"
        // ---- prefetch -----
    }
}
