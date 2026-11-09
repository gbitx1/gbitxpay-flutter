Pod::Spec.new do |s|
  s.name             = 'gbitx_pay_flutter'
  s.version          = '0.2.0'
  s.summary          = 'GbitXPay Flutter plugin — hardened native crypto checkout.'
  s.description       = <<-DESC
    Opens the hardened GbitXPay hosted checkout via the native iOS SDK (GbitXPay
    pod). Fulfilment is driven by the signed server webhook; SDK results are UX only.
  DESC
  s.homepage         = 'https://doc.gbitxpay.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'GBIT TECHNOLOGIES LIMITED COMPANY' => 'support@gbitx.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'

  s.dependency 'Flutter'
  # The audited native SDK, pinned to an EXACT version so a downgraded/forked
  # GbitXPay can never satisfy the build (the plugin's security posture traces to
  # this specific audited release). Resolves from CocoaPods trunk once published;
  # before that, the CONSUMING app's Podfile must add
  #   pod 'GbitXPay', :path => '…/sdk/ios'   (or :git => …)
  s.dependency 'GbitXPay', '0.2.0'

  s.platform         = :ios, '15.0'
  s.swift_version    = '5.9'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
