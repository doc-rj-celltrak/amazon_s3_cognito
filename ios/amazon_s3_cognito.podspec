#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'amazon_s3_cognito'
  s.version          = '0.2.4'
  s.summary          = 'This plugin allows users to upload and delete image and files for amazon s3 cognito'
  s.description      = <<-DESC
This plugin allows users to upload and delete image for amazon s3 cognito
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Fam Properties' => 'no-reply@famproperties.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.dependency 'AWSS3', '~> 2.27.15'
  s.dependency 'AWSCore', '~> 2.27.15'
  s.dependency 'AWSCognitoIdentityProvider', '~> 2.27.15'

  s.ios.deployment_target = '12.0'
end
