Pod::Spec.new do |spec|
  spec.name = 'AnyPopup'
  spec.version = '0.1.0'
  spec.summary = 'Typed, responsive popup infrastructure for SwiftUI.'
  spec.description = <<-DESC
    AnyPopup provides command-style popup presentation, typed configuration
    domains, unified stacking, anchored geometry, and interaction routing.
  DESC
  spec.homepage = 'https://github.com/videni/AnyPopup'
  spec.license = { :type => 'Apache License 2.0', :file => 'LICENSE' }
  spec.author = { 'videni' => 'videni@users.noreply.github.com' }
  spec.source = { :git => 'https://github.com/videni/AnyPopup.git', :tag => spec.version.to_s }
  spec.ios.deployment_target = '26.0'
  spec.swift_version = '6.0'
  spec.source_files = 'Sources/AnyPopup/**/*.swift'
  spec.frameworks = 'SwiftUI', 'Foundation'
end
