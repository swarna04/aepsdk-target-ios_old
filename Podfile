# Uncomment the next line to define a global platform for your project
platform :ios, '10.0'

# Comment the next line if you don't want to use dynamic frameworks
use_frameworks!

workspace 'AEPTarget'
project 'AEPTarget.xcodeproj'

target 'AEPTarget' do
  pod 'AEPCore'
end

target 'AEPTargetDemoApp' do
  pod 'AEPCore'
  pod 'AEPIdentity'
  pod 'AEPLifecycle'
  pod 'AEPSignal'
  pod 'AEPAssurance'
  pod 'AEPAnalytics'
end
  
target 'AEPTargetDemoObjCApp' do
  pod 'AEPCore'
  pod 'AEPIdentity'
  pod 'AEPLifecycle'
  pod 'AEPAssurance'
  pod 'AEPAnalytics'
end

target 'AEPTargetTests' do
  pod 'AEPCore'
  pod 'AEPIdentity'
  pod 'AEPLifecycle'
  pod 'AEPAnalytics'
  pod 'SwiftyJSON', '~> 4.0'
end
