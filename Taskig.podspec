Pod::Spec.new do |s|
  s.name             = 'Taskig'
  s.version          = '0.2.4'
  s.summary          = 'An asynchronous programming library for Swift.'
  s.description      = <<-DESC
An asynchronous programming library for Swift that is composable and protocol oriented.
                       DESC
  s.homepage         = 'https://github.com/stendahls/Taskig'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Thomas Sempf' => 'thomas.sempf@stendahls.se' }
  s.source           = { :git => 'https://github.com/stendahls/Taskig.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/tsempf'

  s.ios.deployment_target = '9.0'
  s.osx.deployment_target = "10.12"
  s.tvos.deployment_target = "9.0"
  s.watchos.deployment_target = '3.0'

  s.swift_version = '5.0'

  s.source_files = 'TaskigSource/Base/*.swift'
  s.requires_arc = true
end
