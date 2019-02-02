#
# Be sure to run `pod lib lint GRNetworkKit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'GRNetworkKit'
  s.version          = '0.5.11'
  s.summary          = 'Helpful code for making network requests'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
A network abstraction that allows easy network requests/responses and streamed-from-disk multi-part form-data POSTs.
                       DESC

  s.homepage         = 'https://github.com/jgrantr/GRNetworkKit'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Grant Robinson' => 'grant@zayda.com' }
  s.source           = { :git => 'https://github.com/jgrantr/GRNetworkKit.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'

  s.source_files = 'GRNetworkKit/Classes/**/*'
  
  # s.resource_bundles = {
  #   'GRNetworkKit' => ['GRNetworkKit/Assets/*.png']
  # }

  s.public_header_files = 'GRNetworkKit/Classes/GR*.h'
  s.frameworks = 'UIKit', 'Foundation'
  s.dependency 'PromiseKit'
  s.dependency 'CocoaLumberjack', '~> 3.2'

end
