# Uncomment the next line to define a global platform for your project
platform :ios, '13.0'

target 'Pure Pets' do
  use_frameworks!
  
  pod 'SDWebImage', '~> 5.0'
  
  pod 'HXPhotoPicker', :path => '../HXPhotoPicker-master'
  pod 'IQKeyboardManager'
  pod 'TZImagePickerController'
  pod 'AFNetworking', '~> 4.0'
  #pod 'SDWebImage', '~> 5.0'
 
  pod 'Masonry'
  #pod 'GoogleSignIn'
  #pod 'AppAuth'
  pod 'KVOController', '1.2.0'
  pod 'WJFrameLayout'  # only once
  pod 'MMSCameraViewController',  '~> 1.4.0'
  pod 'GoogleMaps'
  pod 'lottie-ios_Oc'
  #pod 'YYKit'
  pod 'SSZipArchive'
  pod 'TOCropViewController'
  #pod 'RNFrostedSidebar', '~> 0.2.0'
  pod 'MDRadialProgress'
 
 
end


post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
      config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'

      # Enable building for simulator
      config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'
      
      if config.name == 'Debug'
        config.build_settings['DEBUG_INFORMATION_FORMAT'] = 'dwarf-with-dsym'
        config.build_settings['STRIP_INSTALLED_PRODUCT'] = 'NO'
        config.build_settings['DEPLOYMENT_POSTPROCESSING'] = 'NO'
      end
      
      # Remove arm64 from excluded architectures for simulator
      if config.name.include?("SIMULATOR")
        config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
      end
    end
  end

  # Fix AFNetworking private header error: remove #import <netinet6/in6.h> from all implementation files
  af_dir = File.join(installer.sandbox.root.to_s, 'AFNetworking', 'AFNetworking')
  if Dir.exist?(af_dir)
    Dir.glob(File.join(af_dir, '*.m')).each do |file_path|
      content = File.read(file_path)
      patched = content.gsub(%r{^#import\s+<netinet6/in6\.h>\s*\n}, '')
      File.write(file_path, patched) if patched != content
    end
  end

  # Xcode may still sandbox the CocoaPods rsync copy phase and block temp-file creation
  # (e.g. .AFNetworking.xxxxxx inside .app/Frameworks). Force rsync to copy in-place.
  Dir.glob(File.join(installer.sandbox.root.to_s, 'Target Support Files', '**', '*-frameworks.sh')).each do |script_path|
    next unless File.file?(script_path)

    content = File.read(script_path)
    patched = content.gsub('rsync --delete -av "${RSYNC_PROTECT_TMP_FILES[@]}"', 'rsync --inplace --delete -av "${RSYNC_PROTECT_TMP_FILES[@]}"')
                     .gsub('rsync -auv "${SWIFT_STDLIB_PATH}/${lib}" "${destination}"', 'rsync --inplace -auv "${SWIFT_STDLIB_PATH}/${lib}" "${destination}"')

    next if patched == content
    File.write(script_path, patched)
  end
end





