/*
 Copyright 2021 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0
 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import AEPAssurance
import AEPCore
import AEPServices
import AEPTarget
import SwiftUI

struct ContentView: View {
    @State var thirdPartyId: String = ""
    @State var updatedThirdPartyId: String = ""
    @State var tntId: String = ""
    @State var griffonUrl: String = TestConstants.GRIFFON_URL
    @State var fullscreenMessage: FullscreenPresentable?
    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: nil, content: {
                Group {
                    TextField("Griffon URL", text: $griffonUrl).multilineTextAlignment(.center)
                    Button("Connect to griffon") {
                        startGriffon()
                    }.padding(10)

                    Button("Prefetch") {
                        prefetch()
                    }.padding(10)

                    Button("GetLocations (using contentCallback)") {
                        getLocations1()
                    }.padding(10)

                    Button("GetLocations (using contentWithDataCallback)") {
                        getLocations2()
                    }.padding(10)

                    Button("Locations displayed") {
                        locationDisplayed()
                    }.padding(10)

                    Button("Location clicked") {
                        locationClicked()
                    }.padding(10)

                    Button("Reset Experience") {
                        resetExperience()
                    }.padding(10)
                }

                Group {
                    Text("Third Party ID - \(thirdPartyId)")
                    Button("Get Third Party Id") {
                        getThirdPartyId()
                    }.padding(10)

                    Text("Tnt id - \(tntId)")
                    Button("Get Tnt Id") {
                        getTntId()
                    }.padding(10)
                    TextField("Please enter thirdPartyId", text: $updatedThirdPartyId).multilineTextAlignment(.center)

                    Button("Set Third Party Id") {
                        setThirdPartyId()
                    }.padding(10)

                    Button("Clear prefetch cache") {
                        clearPrefetchCache()
                    }.padding(10)

                    Button("Enter Preview") {
                        enterPreview()
                    }.padding(10)
                }
            })
        }
    }

    func startGriffon() {
        if let url = URL(string: griffonUrl) {
            Assurance.startSession(url: url)
        }
    }

    func prefetch() {
        Target.prefetchContent(
            [
                TargetPrefetch(name: "aep-loc-1", targetParameters: nil),
                TargetPrefetch(name: "aep-loc-2", targetParameters: nil),
            ],
            nil
        )
    }

    func getLocations1() {
        Target.retrieveLocationContent([TargetRequest(mboxName: "aep-loc-1", defaultContent: "DefaultValue1", targetParameters: nil, contentCallback: { content in
                print("------")
                print("Content: \(content ?? "")")
            }),
                                        TargetRequest(mboxName: "aep-loc-2", defaultContent: "DefaultValue2", targetParameters: nil, contentCallback: { content in
                print("------")
                print("Content: \(content ?? "")")
            }),
                                        TargetRequest(mboxName: "aep-loc-x", defaultContent: "DefaultValuex", targetParameters: nil, contentCallback: { content in
               print("------")
               print("Content: \(content ?? "")")
           })],
                                       with: TargetParameters(parameters: ["mbox_parameter_key": "mbox_parameter_value"], profileParameters: ["name": "Smith"], order: TargetOrder(id: "id1", total: 1.0, purchasedProductIds: ["ppId1"]), product: TargetProduct(productId: "pId1", categoryId: "cId1")))
    }

    func getLocations2() {
        Target.retrieveLocationContent([
            TargetRequest(mboxName: "aep-loc-1", defaultContent: "DefaultValue1", targetParameters: nil, contentWithDataCallback: { content, data in
                print("------")
                print("Content: \(content ?? "")")

                let responseTokens = data?["responseTokens"] as? [String: String] ?? [:]
                print("Response tokens: \(responseTokens as AnyObject)")

                let analyticsPayload = data?["analytics.payload"] as? [String: String] ?? [:]
                print("Analytics payload: \(analyticsPayload as AnyObject)")

                let clickAnalyticsPayload = data?["clickmetric.analytics.payload"] as? [String: String] ?? [:]
                print("Metrics Analytics payload (click): \(clickAnalyticsPayload as AnyObject)")
            }),
            TargetRequest(mboxName: "aep-loc-2", defaultContent: "DefaultValue2", targetParameters: nil, contentWithDataCallback: { content, data in
                print("------")
                print("Content: \(content ?? "")")

                let responseTokens = data?["responseTokens"] as? [String: String] ?? [:]
                print("Response tokens: \(responseTokens as AnyObject)")

                let analyticsPayload = data?["analytics.payload"] as? [String: String] ?? [:]
                print("Analytics payload: \(analyticsPayload as AnyObject)")

                let clickAnalyticsPayload = data?["clickmetric.analytics.payload"] as? [String: String] ?? [:]
                print("Metrics Analytics payload (click): \(clickAnalyticsPayload as AnyObject)")
            }),
        ],
                                       with: TargetParameters(parameters: ["mbox_parameter_key": "mbox_parameter_value"], profileParameters: ["name": "Smith"], order: TargetOrder(id: "id1", total: 1.0, purchasedProductIds: ["ppId1"]), product: TargetProduct(productId: "pId1", categoryId: "cId1")))
    }

    func locationDisplayed() {
        Target.displayedLocations(["aep-loc-1", "aep-loc-2"], targetParameters: TargetParameters(parameters: ["mbox_parameter_key": "mbox_parameter_value"], profileParameters: ["name": "Smith"], order: TargetOrder(id: "id1", total: 1.0, purchasedProductIds: ["ppId1"]), product: TargetProduct(productId: "pId1", categoryId: "cId1")))
    }

    func locationClicked() {
        Target.clickedLocation("aep-loc-1", targetParameters: TargetParameters(parameters: ["mbox_parameter_key": "mbox_parameter_value"], profileParameters: ["name": "Smith"], order: TargetOrder(id: "id1", total: 1.0, purchasedProductIds: ["ppId1"]), product: TargetProduct(productId: "pId1", categoryId: "cId1")))
    }

    func resetExperience() {
        Target.resetExperience()
    }

    func clearPrefetchCache() {
        Target.clearPrefetchCache()
    }

    func getThirdPartyId() {
        Target.getThirdPartyId { id, err in
            if let id = id {
                self.thirdPartyId = id
            }
            if let err = err {
                Log.error(label: "AEPTargetDemoApp", "Error: \(err)")
            }
        }
    }

    func getTntId() {
        Target.getTntId { id, err in
            if let id = id {
                self.tntId = id
            }
            if let err = err {
                Log.error(label: "AEPTargetDemoApp", "Error: \(err)")
            }
        }
    }

    func setThirdPartyId() {
        Target.setThirdPartyId(updatedThirdPartyId)
    }

    func enterPreview() {
        MobileCore.collectLaunchInfo(["adb_deeplink": TestConstants.DEEP_LINK])
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
