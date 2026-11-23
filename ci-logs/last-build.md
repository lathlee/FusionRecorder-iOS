# FusionRecorder iOS 最后一次构建

- 结果: **success**
- 提交: `b47b0f3ae088252d6068f77583a245dfb558f9a4`
- 时间: 2026-11-23 08:27:33 UTC

## 错误摘要

```
```

## 编译日志（末尾 2000 行）

```
Command line invocation:
    /Applications/Xcode_26.6.app/Contents/Developer/usr/bin/xcodebuild build -project FusionRecorder.xcodeproj -scheme FusionRecorder -configuration Release -sdk iphoneos -derivedDataPath /Users/runner/work/_temp/dd CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= CODE_SIGN_ENTITLEMENTS= ONLY_ACTIVE_ARCH=NO

Build settings from command line:
    CODE_SIGN_ENTITLEMENTS = 
    CODE_SIGN_IDENTITY = 
    CODE_SIGNING_ALLOWED = NO
    CODE_SIGNING_REQUIRED = NO
    ONLY_ACTIVE_ARCH = NO
    SDKROOT = iphoneos26.5

--- xcodebuild: WARNING: Using the first of multiple matching destinations:
{ platform:iOS, id:dvtdevice-DVTiPhonePlaceholder-iphoneos:placeholder, name:Any iOS Device }
{ platform:macOS, arch:arm64, variant:Designed for [iPad,iPhone], id:3bf4bbf680049d8d3fa02b550c50f4f5952d6f0e, name:My Mac }
{ platform:iOS Simulator, id:dvtdevice-DVTiOSDeviceSimulatorPlaceholder-iphonesimulator:placeholder, name:Any iOS Simulator Device }
{ platform:visionOS Simulator, arch:arm64, variant:Designed for [iPad,iPhone], id:9C68DD66-0BB9-4C08-B7BF-9A91F7FA547B, OS:26.2, name:Apple Vision Pro }
{ platform:visionOS Simulator, arch:arm64, variant:Designed for [iPad,iPhone], id:3D06C66B-45C9-4FD2-B9AF-D85A173707A6, OS:26.4.1, name:Apple Vision Pro }
{ platform:visionOS Simulator, arch:arm64, variant:Designed for [iPad,iPhone], id:6023AC0F-9C55-4618-95B5-F1C3C17A5E60, OS:26.5, name:Apple Vision Pro }
{ platform:iOS Simulator, arch:arm64, id:6D181590-D19F-48F6-AC2F-8C98F5F77D34, OS:26.2, name:iPad (A16) }
{ platform:iOS Simulator, arch:x86_64, id:6D181590-D19F-48F6-AC2F-8C98F5F77D34, OS:26.2, name:iPad (A16) }
{ platform:iOS Simulator, arch:arm64, id:BB9BCE9B-E401-40A3-A0C1-F8B13C50F459, OS:26.4.1, name:iPad (A16) }
{ platform:iOS Simulator, arch:x86_64, id:BB9BCE9B-E401-40A3-A0C1-F8B13C50F459, OS:26.4.1, name:iPad (A16) }
{ platform:iOS Simulator, arch:arm64, id:2C358D2A-D903-489E-9517-1EE4B2273E04, OS:26.5, name:iPad (A16) }
{ platform:iOS Simulator, arch:x86_64, id:2C358D2A-D903-489E-9517-1EE4B2273E04, OS:26.5, name:iPad (A16) }
{ platform:iOS Simulator, arch:arm64, id:ABF743D3-A9E9-4317-BB4C-DDCFB58C38DE, OS:26.2, name:iPad Air 11-inch (M3) }
{ platform:iOS Simulator, arch:x86_64, id:ABF743D3-A9E9-4317-BB4C-DDCFB58C38DE, OS:26.2, name:iPad Air 11-inch (M3) }
{ platform:iOS Simulator, arch:arm64, id:0BA81479-0013-4163-9C1B-8657B690465D, OS:26.4.1, name:iPad Air 11-inch (M4) }
{ platform:iOS Simulator, arch:x86_64, id:0BA81479-0013-4163-9C1B-8657B690465D, OS:26.4.1, name:iPad Air 11-inch (M4) }
{ platform:iOS Simulator, arch:arm64, id:B93AC885-30EF-40D3-911E-AFBFE471286C, OS:26.5, name:iPad Air 11-inch (M4) }
{ platform:iOS Simulator, arch:x86_64, id:B93AC885-30EF-40D3-911E-AFBFE471286C, OS:26.5, name:iPad Air 11-inch (M4) }
{ platform:iOS Simulator, arch:arm64, id:2DA453A7-F093-478D-A736-C479712036A4, OS:26.2, name:iPad Air 13-inch (M3) }
{ platform:iOS Simulator, arch:x86_64, id:2DA453A7-F093-478D-A736-C479712036A4, OS:26.2, name:iPad Air 13-inch (M3) }
{ platform:iOS Simulator, arch:arm64, id:D443F0B4-5BAC-4C52-B5C9-C4150281B9AF, OS:26.4.1, name:iPad Air 13-inch (M4) }
{ platform:iOS Simulator, arch:x86_64, id:D443F0B4-5BAC-4C52-B5C9-C4150281B9AF, OS:26.4.1, name:iPad Air 13-inch (M4) }
{ platform:iOS Simulator, arch:arm64, id:A3140D84-3F55-44CB-A4E0-BB0E256CBD79, OS:26.5, name:iPad Air 13-inch (M4) }
{ platform:iOS Simulator, arch:x86_64, id:A3140D84-3F55-44CB-A4E0-BB0E256CBD79, OS:26.5, name:iPad Air 13-inch (M4) }
{ platform:iOS Simulator, arch:arm64, id:EEF7FA09-1BF7-4CA0-A381-5F0A883FF632, OS:26.2, name:iPad Pro 11-inch (M5) }
{ platform:iOS Simulator, arch:x86_64, id:EEF7FA09-1BF7-4CA0-A381-5F0A883FF632, OS:26.2, name:iPad Pro 11-inch (M5) }
{ platform:iOS Simulator, arch:arm64, id:01CB0E86-839C-47B2-B57E-9431B8B2C21C, OS:26.4.1, name:iPad Pro 11-inch (M5) }
{ platform:iOS Simulator, arch:x86_64, id:01CB0E86-839C-47B2-B57E-9431B8B2C21C, OS:26.4.1, name:iPad Pro 11-inch (M5) }
{ platform:iOS Simulator, arch:arm64, id:E6D22F64-35F4-4792-92E9-462C0B7C23BA, OS:26.5, name:iPad Pro 11-inch (M5) }
{ platform:iOS Simulator, arch:x86_64, id:E6D22F64-35F4-4792-92E9-462C0B7C23BA, OS:26.5, name:iPad Pro 11-inch (M5) }
{ platform:iOS Simulator, arch:arm64, id:70A7952C-F289-459B-8875-D154D551E8CB, OS:26.2, name:iPad Pro 13-inch (M5) }
{ platform:iOS Simulator, arch:x86_64, id:70A7952C-F289-459B-8875-D154D551E8CB, OS:26.2, name:iPad Pro 13-inch (M5) }
{ platform:iOS Simulator, arch:arm64, id:2239CD22-6BE3-4D11-B927-9245F8915748, OS:26.4.1, name:iPad Pro 13-inch (M5) }
{ platform:iOS Simulator, arch:x86_64, id:2239CD22-6BE3-4D11-B927-9245F8915748, OS:26.4.1, name:iPad Pro 13-inch (M5) }
{ platform:iOS Simulator, arch:arm64, id:2A020491-3EBC-4783-8622-F8314CC00294, OS:26.5, name:iPad Pro 13-inch (M5) }
{ platform:iOS Simulator, arch:x86_64, id:2A020491-3EBC-4783-8622-F8314CC00294, OS:26.5, name:iPad Pro 13-inch (M5) }
{ platform:iOS Simulator, arch:arm64, id:706151BA-6C80-4F5B-97B9-6326F6122EB2, OS:26.2, name:iPad mini (A17 Pro) }
{ platform:iOS Simulator, arch:x86_64, id:706151BA-6C80-4F5B-97B9-6326F6122EB2, OS:26.2, name:iPad mini (A17 Pro) }
{ platform:iOS Simulator, arch:arm64, id:518E4C9C-4259-4885-AA50-B803C3DE2D05, OS:26.4.1, name:iPad mini (A17 Pro) }
{ platform:iOS Simulator, arch:x86_64, id:518E4C9C-4259-4885-AA50-B803C3DE2D05, OS:26.4.1, name:iPad mini (A17 Pro) }
{ platform:iOS Simulator, arch:arm64, id:BB3AAE9A-1B8F-4B6F-B536-0744287562C8, OS:26.5, name:iPad mini (A17 Pro) }
{ platform:iOS Simulator, arch:x86_64, id:BB3AAE9A-1B8F-4B6F-B536-0744287562C8, OS:26.5, name:iPad mini (A17 Pro) }
{ platform:iOS Simulator, arch:arm64, id:16AFAE62-8F15-4D89-8041-9A6510AE4913, OS:26.2, name:iPhone 16e }
{ platform:iOS Simulator, arch:x86_64, id:16AFAE62-8F15-4D89-8041-9A6510AE4913, OS:26.2, name:iPhone 16e }
{ platform:iOS Simulator, arch:arm64, id:44BD2F18-416F-4F70-B2C2-BE4EBA0C2F50, OS:26.2, name:iPhone 17 }
{ platform:iOS Simulator, arch:x86_64, id:44BD2F18-416F-4F70-B2C2-BE4EBA0C2F50, OS:26.2, name:iPhone 17 }
{ platform:iOS Simulator, arch:arm64, id:AC5CE080-DB21-4BF7-9D4E-7C217DE28A05, OS:26.4.1, name:iPhone 17 }
{ platform:iOS Simulator, arch:x86_64, id:AC5CE080-DB21-4BF7-9D4E-7C217DE28A05, OS:26.4.1, name:iPhone 17 }
{ platform:iOS Simulator, arch:arm64, id:8EBAA496-5654-45BF-897F-3C4FD73935F1, OS:26.5, name:iPhone 17 }
{ platform:iOS Simulator, arch:x86_64, id:8EBAA496-5654-45BF-897F-3C4FD73935F1, OS:26.5, name:iPhone 17 }
{ platform:iOS Simulator, arch:arm64, id:EED6FB0A-E273-43C6-B5DE-3DF739543042, OS:26.2, name:iPhone 17 Pro }
{ platform:iOS Simulator, arch:x86_64, id:EED6FB0A-E273-43C6-B5DE-3DF739543042, OS:26.2, name:iPhone 17 Pro }
{ platform:iOS Simulator, arch:arm64, id:27012C89-9706-4CDE-88BB-4B380B6C743A, OS:26.4.1, name:iPhone 17 Pro }
{ platform:iOS Simulator, arch:x86_64, id:27012C89-9706-4CDE-88BB-4B380B6C743A, OS:26.4.1, name:iPhone 17 Pro }
{ platform:iOS Simulator, arch:arm64, id:6478AFFB-AE17-412A-A1E5-51BCFFD300B6, OS:26.5, name:iPhone 17 Pro }
{ platform:iOS Simulator, arch:x86_64, id:6478AFFB-AE17-412A-A1E5-51BCFFD300B6, OS:26.5, name:iPhone 17 Pro }
{ platform:iOS Simulator, arch:arm64, id:0BF273CD-70D1-4646-BE79-A0E7EF224D18, OS:26.2, name:iPhone 17 Pro Max }
{ platform:iOS Simulator, arch:x86_64, id:0BF273CD-70D1-4646-BE79-A0E7EF224D18, OS:26.2, name:iPhone 17 Pro Max }
{ platform:iOS Simulator, arch:arm64, id:1F8E0003-51CF-4174-9E6D-318240CEC150, OS:26.4.1, name:iPhone 17 Pro Max }
{ platform:iOS Simulator, arch:x86_64, id:1F8E0003-51CF-4174-9E6D-318240CEC150, OS:26.4.1, name:iPhone 17 Pro Max }
{ platform:iOS Simulator, arch:arm64, id:F90353E4-F95D-488C-9F4E-B43F74E385F2, OS:26.5, name:iPhone 17 Pro Max }
{ platform:iOS Simulator, arch:x86_64, id:F90353E4-F95D-488C-9F4E-B43F74E385F2, OS:26.5, name:iPhone 17 Pro Max }
{ platform:iOS Simulator, arch:arm64, id:43DAE57B-B4CA-4DCA-A549-1B77CCB00A5C, OS:26.4.1, name:iPhone 17e }
{ platform:iOS Simulator, arch:x86_64, id:43DAE57B-B4CA-4DCA-A549-1B77CCB00A5C, OS:26.4.1, name:iPhone 17e }
{ platform:iOS Simulator, arch:arm64, id:229240FC-DED4-405A-8908-553295E30D59, OS:26.5, name:iPhone 17e }
{ platform:iOS Simulator, arch:x86_64, id:229240FC-DED4-405A-8908-553295E30D59, OS:26.5, name:iPhone 17e }
{ platform:iOS Simulator, arch:arm64, id:80B56851-B786-47DE-8EE4-83ACFC3CD092, OS:26.2, name:iPhone Air }
{ platform:iOS Simulator, arch:x86_64, id:80B56851-B786-47DE-8EE4-83ACFC3CD092, OS:26.2, name:iPhone Air }
{ platform:iOS Simulator, arch:arm64, id:0D8D9D1E-9F70-4295-B4D0-A00F03A97002, OS:26.4.1, name:iPhone Air }
{ platform:iOS Simulator, arch:x86_64, id:0D8D9D1E-9F70-4295-B4D0-A00F03A97002, OS:26.4.1, name:iPhone Air }
{ platform:iOS Simulator, arch:arm64, id:CE12A219-9F8C-4450-97EA-8C58715BECFC, OS:26.5, name:iPhone Air }
{ platform:iOS Simulator, arch:x86_64, id:CE12A219-9F8C-4450-97EA-8C58715BECFC, OS:26.5, name:iPhone Air }
note: Using codesigning identity override: 
ComputePackagePrebuildTargetDependencyGraph

Prepare packages

CreateBuildRequest

SendProjectDescription

CreateBuildOperation

ComputeTargetDependencyGraph
note: Building targets in dependency order
note: Target dependency graph (1 target)
    Target 'FusionRecorder' in project 'FusionRecorder' (no dependencies)

GatherProvisioningInputs

CreateBuildDescription

ExecuteExternalTool /Applications/Xcode_26.6.app/Contents/Developer/usr/bin/actool --print-asset-tag-combinations --output-format xml1 /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Assets.xcassets

ExecuteExternalTool /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang -v -E -dM -isysroot /Applications/Xcode_26.6.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk -x c -c /dev/null

ExecuteExternalTool /Applications/Xcode_26.6.app/Contents/Developer/usr/bin/actool --version --output-format xml1

ExecuteExternalTool /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc --version

ExecuteExternalTool /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/ld -version_details

Build description signature: caf282ce212b426b4a1401a4b793b843
Build description path: /Users/runner/work/_temp/dd/Build/Intermediates.noindex/XCBuildData/caf282ce212b426b4a1401a4b793b843.xcbuilddata
CreateBuildDirectory /Users/runner/work/_temp/dd/Build/Products
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder.xcodeproj
    builtin-create-build-directory /Users/runner/work/_temp/dd/Build/Products

CreateBuildDirectory /Users/runner/work/_temp/dd/Build/Intermediates.noindex
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder.xcodeproj
    builtin-create-build-directory /Users/runner/work/_temp/dd/Build/Intermediates.noindex

ClangStatCache /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang-stat-cache /Applications/Xcode_26.6.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk /Users/runner/work/_temp/dd/SDKStatCaches.noindex/iphoneos26.5-23F81a-688ef53f1462e2c8f657fdc38a81448fee66e23052a0157c865c76b268046726.sdkstatcache
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder.xcodeproj
    /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang-stat-cache /Applications/Xcode_26.6.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk -o /Users/runner/work/_temp/dd/SDKStatCaches.noindex/iphoneos26.5-23F81a-688ef53f1462e2c8f657fdc38a81448fee66e23052a0157c865c76b268046726.sdkstatcache

WriteAuxiliaryFile /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder-86cee7357ca544f40293a1c2ee9343f7-VFS-iphoneos/all-product-headers.yaml
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder.xcodeproj
    write-file /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder-86cee7357ca544f40293a1c2ee9343f7-VFS-iphoneos/all-product-headers.yaml

CreateBuildDirectory /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder.xcodeproj
    builtin-create-build-directory /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos

CreateBuildDirectory /Users/runner/work/_temp/dd/Build/Intermediates.noindex/SwiftExplicitPrecompiledModules
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder.xcodeproj
    builtin-create-build-directory /Users/runner/work/_temp/dd/Build/Intermediates.noindex/SwiftExplicitPrecompiledModules

CreateBuildDirectory /Users/runner/work/_temp/dd/Build/Intermediates.noindex/ExplicitPrecompiledModules
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder.xcodeproj
    builtin-create-build-directory /Users/runner/work/_temp/dd/Build/Intermediates.noindex/ExplicitPrecompiledModules

CreateBuildDirectory /Users/runner/work/_temp/dd/Build/Intermediates.noindex/EagerLinkingTBDs/Release-iphoneos
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder.xcodeproj
    builtin-create-build-directory /Users/runner/work/_temp/dd/Build/Intermediates.noindex/EagerLinkingTBDs/Release-iphoneos

WriteAuxiliaryFile /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder_const_extract_protocols.json (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    write-file /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder_const_extract_protocols.json

WriteAuxiliaryFile /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder.SwiftFileList (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    write-file /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder.SwiftFileList

WriteAuxiliaryFile /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder.SwiftConstValuesFileList (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    write-file /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder.SwiftConstValuesFileList

WriteAuxiliaryFile /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder.LinkFileList (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    write-file /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder.LinkFileList

WriteAuxiliaryFile /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder-OutputFileMap.json (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    write-file /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder-OutputFileMap.json

WriteAuxiliaryFile /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder.hmap (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    write-file /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder.hmap

WriteAuxiliaryFile /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder.DependencyStaticMetadataFileList (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    write-file /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder.DependencyStaticMetadataFileList

WriteAuxiliaryFile /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder.DependencyMetadataFileList (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    write-file /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder.DependencyMetadataFileList

WriteAuxiliaryFile /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder-project-headers.hmap (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    write-file /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder-project-headers.hmap

WriteAuxiliaryFile /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder-own-target-headers.hmap (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    write-file /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder-own-target-headers.hmap

WriteAuxiliaryFile /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder-generated-files.hmap (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    write-file /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder-generated-files.hmap

WriteAuxiliaryFile /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder-all-target-headers.hmap (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    write-file /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder-all-target-headers.hmap

WriteAuxiliaryFile /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder-all-non-framework-target-headers.hmap (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    write-file /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder-all-non-framework-target-headers.hmap

MkDir /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    /bin/mkdir -p /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app

MkDir /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/assetcatalog_output/unthinned (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    /bin/mkdir -p /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/assetcatalog_output/unthinned

MkDir /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/assetcatalog_output/thinned (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    /bin/mkdir -p /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/assetcatalog_output/thinned

GenerateAssetSymbols /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Assets.xcassets (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    /Applications/Xcode_26.6.app/Contents/Developer/usr/bin/actool /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Assets.xcassets --compile /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app --output-format human-readable-text --notices --warnings --export-dependency-info /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/assetcatalog_dependencies --output-partial-info-plist /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/assetcatalog_generated_info.plist --app-icon AppIcon --compress-pngs --enable-on-demand-resources YES --development-region en --target-device iphone --minimum-deployment-target 17.0 --platform iphoneos --bundle-identifier com.lath.fusionrecorder --generate-swift-asset-symbol-extensions NO --generate-swift-asset-symbols /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/DerivedSources/GeneratedAssetSymbols.swift --generate-objc-asset-symbols /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/DerivedSources/GeneratedAssetSymbols.h --generate-asset-symbol-index /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/DerivedSources/GeneratedAssetSymbols-Index.plist
/* com.apple.actool.compilation-results */
/Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/DerivedSources/GeneratedAssetSymbols-Index.plist
/Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/DerivedSources/GeneratedAssetSymbols.h
/Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/DerivedSources/GeneratedAssetSymbols.swift


CpResource /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app/screen-push.jar /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Resources/screen-push.jar (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    builtin-copy -exclude .DS_Store -exclude CVS -exclude .svn -exclude .git -exclude .hg -resolve-src-symlinks /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Resources/screen-push.jar /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app

CpResource /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app/fusion-capture.apk /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Resources/fusion-capture.apk (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    builtin-copy -exclude .DS_Store -exclude CVS -exclude .svn -exclude .git -exclude .hg -resolve-src-symlinks /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Resources/fusion-capture.apk /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app

CopyPNGFile /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app/sample_screen.png /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Resources/sample_screen.png (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    /Applications/Xcode_26.6.app/Contents/Developer/usr/bin/copypng -compress -strip-PNG-text /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Resources/sample_screen.png /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app/sample_screen.png

CopyPNGFile /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app/sample_camera.png /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Resources/sample_camera.png (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    /Applications/Xcode_26.6.app/Contents/Developer/usr/bin/copypng -compress -strip-PNG-text /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Resources/sample_camera.png /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app/sample_camera.png

CompileAssetCatalogVariant thinned /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Assets.xcassets (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    /Applications/Xcode_26.6.app/Contents/Developer/usr/bin/actool /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Assets.xcassets --compile /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/assetcatalog_output/thinned --output-format human-readable-text --notices --warnings --export-dependency-info /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/assetcatalog_dependencies_thinned --output-partial-info-plist /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/assetcatalog_generated_info.plist_thinned --app-icon AppIcon --compress-pngs --enable-on-demand-resources YES --development-region en --target-device iphone --minimum-deployment-target 17.0 --platform iphoneos
/* com.apple.actool.compilation-results */
/Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/assetcatalog_generated_info.plist_thinned
/Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/assetcatalog_output/thinned/AppIcon60x60@2x.png
/Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/assetcatalog_output/thinned/AppIcon76x76@2x~ipad.png
/Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/assetcatalog_output/thinned/Assets.car


SwiftDriver FusionRecorder normal arm64 com.apple.xcode.tools.swift.compiler (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    builtin-SwiftDriver -- /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc -module-name FusionRecorder -O -whole-module-optimization @/Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder.SwiftFileList -enable-bare-slash-regex -enable-experimental-feature DebugDescriptionMacro -sdk /Applications/Xcode_26.6.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk -target arm64-apple-ios17.0 -g -module-cache-path /Users/runner/work/_temp/dd/ModuleCache.noindex -Xfrontend -serialize-debugging-options -swift-version 5 -I /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos -F /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos -c -num-threads 3 -Xcc -ivfsstatcache -Xcc /Users/runner/work/_temp/dd/SDKStatCaches.noindex/iphoneos26.5-23F81a-688ef53f1462e2c8f657fdc38a81448fee66e23052a0157c865c76b268046726.sdkstatcache -output-file-map /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder-OutputFileMap.json -use-frontend-parseable-output -save-temps -no-color-diagnostics -explicit-module-build -module-cache-path /Users/runner/work/_temp/dd/Build/Intermediates.noindex/SwiftExplicitPrecompiledModules -clang-scanner-module-cache-path /Users/runner/work/_temp/dd/ModuleCache.noindex -sdk-module-cache-path /Users/runner/work/_temp/dd/ModuleCache.noindex -serialize-diagnostics -emit-dependencies -emit-module -emit-module-path /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder.swiftmodule -validate-clang-modules-once -clang-build-session-file /Users/runner/work/_temp/dd/ModuleCache.noindex/Session.modulevalidation -Xcc -I/Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/swift-overrides.hmap -emit-const-values -Xfrontend -const-gather-protocols-file -Xfrontend /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder_const_extract_protocols.json -Xcc -iquote -Xcc /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder-generated-files.hmap -Xcc -I/Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder-own-target-headers.hmap -Xcc -I/Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder-all-target-headers.hmap -Xcc -iquote -Xcc /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder-project-headers.hmap -Xcc -I/Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/include -Xcc -I/Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/DerivedSources-normal/arm64 -Xcc -I/Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/DerivedSources/arm64 -Xcc -I/Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/DerivedSources -emit-objc-header -emit-objc-header-path /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder-Swift.h -working-directory /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS -no-emit-module-separately-wmo

SwiftDriver\ Compilation FusionRecorder normal arm64 com.apple.xcode.tools.swift.compiler (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    builtin-Swift-Compilation -- /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc -module-name FusionRecorder -O -whole-module-optimization @/Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder.SwiftFileList -enable-bare-slash-regex -enable-experimental-feature DebugDescriptionMacro -sdk /Applications/Xcode_26.6.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk -target arm64-apple-ios17.0 -g -module-cache-path /Users/runner/work/_temp/dd/ModuleCache.noindex -Xfrontend -serialize-debugging-options -swift-version 5 -I /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos -F /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos -c -num-threads 3 -Xcc -ivfsstatcache -Xcc /Users/runner/work/_temp/dd/SDKStatCaches.noindex/iphoneos26.5-23F81a-688ef53f1462e2c8f657fdc38a81448fee66e23052a0157c865c76b268046726.sdkstatcache -output-file-map /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder-OutputFileMap.json -use-frontend-parseable-output -save-temps -no-color-diagnostics -explicit-module-build -module-cache-path /Users/runner/work/_temp/dd/Build/Intermediates.noindex/SwiftExplicitPrecompiledModules -clang-scanner-module-cache-path /Users/runner/work/_temp/dd/ModuleCache.noindex -sdk-module-cache-path /Users/runner/work/_temp/dd/ModuleCache.noindex -serialize-diagnostics -emit-dependencies -emit-module -emit-module-path /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder.swiftmodule -validate-clang-modules-once -clang-build-session-file /Users/runner/work/_temp/dd/ModuleCache.noindex/Session.modulevalidation -Xcc -I/Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/swift-overrides.hmap -emit-const-values -Xfrontend -const-gather-protocols-file -Xfrontend /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder_const_extract_protocols.json -Xcc -iquote -Xcc /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder-generated-files.hmap -Xcc -I/Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder-own-target-headers.hmap -Xcc -I/Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder-all-target-headers.hmap -Xcc -iquote -Xcc /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder-project-headers.hmap -Xcc -I/Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/include -Xcc -I/Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/DerivedSources-normal/arm64 -Xcc -I/Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/DerivedSources/arm64 -Xcc -I/Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/DerivedSources -emit-objc-header -emit-objc-header-path /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder-Swift.h -working-directory /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS -no-emit-module-separately-wmo

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/ptrauth-3JW4VV69235UYPQAU1Y9GSBLN.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/ptrcheck-C8MC9K1BP8T3OQJOAG1LT6J1C.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/SwiftShims-25J99BT6GN0E82BY0PHW6HXC8.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/_Builtin_stdbool-D76COSQZ1DODGKRXK8TFISAMA.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/_SwiftConcurrencyShims-9AE4DAUYKF682PWS9AM5N6MLZ.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/DeveloperToolsSupport-ACCIBO7KR77O8Y4ZGGMHL8Q4Q.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/_AvailabilityInternal-EE5DZEL6UAY4XUTOINJY4US6J.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/_Builtin_stddef-1OLFHJKBMLLBSJ9CNR38Q32WM.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/_Builtin_float-AQMXUP5O3BGHPGG6K7SSWCLNJ.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/_DarwinFoundation1-3RTNT9RWVVOI21BQTM2NRGJRY.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/_Builtin_stdarg-7VJDC0LF9BOWP15M6KYBUY5UJ.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/_Builtin_limits-K17DU31HEKPIBLY2F3GIAJXK.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/ExtensionFoundation-6LTKT6G2T4QJJ5WT8RYINZP5H.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/_DarwinFoundation2-8U51WUYVZPU5B3OJAKOA8HXEK.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/_Builtin_tgmath-C13QTAMQK1IRN5CUPN81TCGGP.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/sys_types-B06XLAHXF7GK8U4LLYDIOJ84L.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/_Builtin_stdint-AOA27QZ2DADCJY35BMAL8DYFY.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/_Builtin_intrinsics-1IW2XH7JCH3NDQW0JEY8R8Q70.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/_Builtin_stdatomic-DQMTWWBBSG0KEU3J1DTZRPXDL.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/_DarwinFoundation3-2K9GHQ5QGLJEGP0IZSNB3FFZT.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/_Builtin_inttypes-2R9BKW5AKSNBYY2PDJL8YQ5C2.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/Darwin-ATGCRW6UVH36TJ2PAAC9GQJ87.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/simd-9K6MS2LCUZ8U695C74G20BJVR.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/MachO-56Y08DMBT4N9R6JX2WRIUYUIY.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/ObjectiveC-532ES28E15T52VC0V9OGG1Y97.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/Spatial-7V1ESMQYY6D6OMKL04HWOLBHH.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/os_object-56HN07FEBZGTO9H8T2WMD1U79.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/os_workgroup-DUE2EWLAZZYA2NUWDQTPAQY4.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/Dispatch-1PCTTQ4RL5JF4H1JJ5ZR3QP4I.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/CoreFoundation-2OUUVC731DK3KJWVN79KVFN1X.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/XPC-2LR3NFSXWGG4HCSB7GP7MJQT9.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/dnssd-7AWUHGBLVLPEQAFG4OEO9AVST.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/Security-AAIT8LUEP9R34HJITM58JWIKK.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/CFNetwork-29YLQQCBVS7BA95QB1RS9QCPZ.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/CoreGraphics-BU3OY6UKNF3IQAF3LWCVOVL0Y.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/CoreAudioTypes-2CBKPMSZ0ALD05AEKTF1BXLHP.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/os-F1902MBH118VP3Y51WHT36IKG.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/Foundation-A6SOLY2RKYNJQC9DS7MH1PQM1.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/CoreAudio-CQZC0DEZL7Y1C20ACVBE00EWJ.pcm

LinkAssetCatalog /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Assets.xcassets (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    builtin-linkAssetCatalog --thinned /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/assetcatalog_output/thinned --thinned-dependencies /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/assetcatalog_dependencies_thinned --thinned-info-plist-content /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/assetcatalog_generated_info.plist_thinned --unthinned /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/assetcatalog_output/unthinned --unthinned-dependencies /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/assetcatalog_dependencies_unthinned --unthinned-info-plist-content /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/assetcatalog_generated_info.plist_unthinned --output /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app --plist-output /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/assetcatalog_generated_info.plist
note: Emplaced /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app/AppIcon76x76@2x~ipad.png (in target 'FusionRecorder' from project 'FusionRecorder')
note: Emplaced /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app/Assets.car (in target 'FusionRecorder' from project 'FusionRecorder')
note: Emplaced /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app/AppIcon60x60@2x.png (in target 'FusionRecorder' from project 'FusionRecorder')

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/ImageIO-CKS1UJN2RVA5PW3E3HKEBN8ZG.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/CoreText-1QAKH3E0SL2F1VBFGVFUPA8AF.pcm

ProcessInfoPlistFile /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app/Info.plist /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Info.plist (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    builtin-infoPlistUtility /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Info.plist -producttype com.apple.product-type.application -genpkginfo /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app/PkgInfo -expandbuildsettings -format binary -platform iphoneos -additionalcontentfile /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/assetcatalog_generated_info.plist -requiredArchitecture arm64 -o /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app/Info.plist

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/DataDetection-1XWGM9NUEP6794947BYT21WC3.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/_LocationEssentials-EHSIDUR2LNY2JYRSYLGGSYB2D.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/UniformTypeIdentifiers-9PLE3NN0QM7OVYW8B16JT4FSQ.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/IOSurface-F33DAMST5TF0HTQ8YJNPOH0JI.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/CoreData-CPW44149DCP3L11M8RUU2EVQY.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/CoreMIDI-9ABARRYCSPP8QHKQC5ZSOIKGQ.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/OSLog-5N15O6DRQQ0DDNOB8HFQA1X71.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/Metal-P5TCWM12H5WTL9QEDJ1SOODC.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/CoreLocation-BPNECTK3MPXQG4WOSUR3NKCU6.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/OpenGLES-7MCHRYNKWCJQGCY45SAR5IFKH.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/AudioToolbox-3DJ0FWS8CU1MR8A0GORPSZPY6.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/UserNotifications-36UWNE93ZPLKUE649FRAMUE.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/UIUtilities-DC50NXK2IAPRLFYJUFNLOJUJX.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/Accessibility-5T3VXXJ54MRI3IGHH4KH7CJJZ.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/CoreVideo-4IW0CM7VDX0Q1N2SB7AU2WM0D.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/FileProvider-8GSC9KGEM1PLSPT8WR1VFAS2O.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/Symbols-DEG4KD7FMPM4BWNYIRA8HPVQ.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/Network-7WAIBCBXJG8ZD7S1Y0RRPXIGY.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/CoreMedia-FBH31AWG7HPTXTMZW7Q7C3CS.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/CoreImage-772Z8BZB6BRFL1W5H3EJEL121.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/QuartzCore-HRDNOX9P3FRTKQVEX88C483P.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/AVRouting-2SEV6PIJ6UL3JTZHAUORR2J5I.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/AVFAudio-16QMG3UZ2SGM3DQBXG65Q8S0U.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/MediaToolbox-BMMPRH44QZ3D8OR8770DAZGYX.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/SwiftUICore-ESPZ4HUVQU7S6UIVTCDAISE0K.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/UIKit-ENZZCUIKNP1JE8HQNDLEDX385.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/CoreTransferable-3K8UQ6LT6JQ6ZTT82HS5B4GTG.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/VideoToolbox-7Q5V8M9ANPORZGE2Y9VDSE1L7.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/AVFoundation-2LTP3Z0HJRPI7NMJFLVWA0MCM.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/Photos-3R36PU6BCYM20368XVT7PYGUH.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/SwiftUI-DRQ57RJKI84SUAOP55Q2W2ZCK.pcm

SwiftExplicitDependencyGeneratePcm arm64 /Users/runner/work/_temp/dd/ModuleCache.noindex/PhotosUI-6BKQQ9OPF5NZIRQ7D5J0084M2.pcm

SwiftCompile normal arm64 Compiling\ ADBAuth.swift,\ ADBClient.swift,\ ADBPacket.swift,\ ADBSyncPuller.swift,\ ADBSyncPusher.swift,\ CaptureOrchestrator.swift,\ ContentView.swift,\ FrameStore.swift,\ FusionCompositor.swift,\ FusionParams.swift,\ FusionPreview.swift,\ FusionPtsParser.swift,\ FusionRecorderApp.swift,\ GlassesDiscovery.swift,\ H264FrameDecoder.swift,\ H264StreamListener.swift,\ H264StreamReceiver.swift,\ OfflineCompositor.swift,\ RecorderSession.swift,\ RecordingViews.swift,\ Theme.swift,\ VideoPipeline.swift,\ GeneratedAssetSymbols.swift /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/ADB/ADBAuth.swift /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/ADB/ADBClient.swift /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/ADB/ADBPacket.swift /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/ADB/ADBSyncPuller.swift /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/ADB/ADBSyncPusher.swift /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/ADB/CaptureOrchestrator.swift /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/UI/ContentView.swift /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Frame/FrameStore.swift /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Pipeline/FusionCompositor.swift /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Pipeline/FusionParams.swift /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/UI/FusionPreview.swift /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Pipeline/FusionPtsParser.swift /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/App/FusionRecorderApp.swift /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/ADB/GlassesDiscovery.swift /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Pipeline/H264FrameDecoder.swift /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Stream/H264StreamListener.swift /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Stream/H264StreamReceiver.swift /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Pipeline/OfflineCompositor.swift /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Session/RecorderSession.swift /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/UI/RecordingViews.swift /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/UI/Theme.swift /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Pipeline/VideoPipeline.swift /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/DerivedSources/GeneratedAssetSymbols.swift /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/SwiftUICore.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/Darwin.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/Distributed.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/QuartzCore.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/CoreMIDI.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/ObjectiveC.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/Network.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/_DarwinFoundation3.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/os.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/FileProvider.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/_Concurrency.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/Combine.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/simd.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/XPC.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/Symbols.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/_PhotosUI_SwiftUI.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/VideoToolbox.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/AudioToolbox.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/Observation.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/Synchronization.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/UIKit.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/CoreFoundation.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/OSLog.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/AVFAudio.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/Photos.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/DeveloperToolsSupport.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/System.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/CoreImage.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/Accessibility.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/Spatial.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/AVFoundation.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/CoreData.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/_DarwinFoundation1.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/CoreMedia.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/_StringProcessing.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/CoreGraphics.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/_Builtin_float.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/CoreVideo.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/CoreLocation.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/CoreAudio.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/SwiftUI.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/Foundation.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/Metal.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/DataDetection.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/CoreText.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/LightweightCodeRequirements.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/Dispatch.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/CoreTransferable.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/_DarwinFoundation2.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/ExtensionFoundation.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/UniformTypeIdentifiers.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/Swift.swiftmodule/arm64e-apple-ios.swiftmodule /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos/prebuilt-modules/26.5/PhotosUI.swiftmodule/arm64e-apple-ios.swiftmodule /Users/runner/work/_temp/dd/ModuleCache.noindex/ExtensionFoundation-6LTKT6G2T4QJJ5WT8RYINZP5H.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/_DarwinFoundation3-2K9GHQ5QGLJEGP0IZSNB3FFZT.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/os_workgroup-DUE2EWLAZZYA2NUWDQTPAQY4.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/os-F1902MBH118VP3Y51WHT36IKG.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/CoreMedia-FBH31AWG7HPTXTMZW7Q7C3CS.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/SwiftUICore-ESPZ4HUVQU7S6UIVTCDAISE0K.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/Security-AAIT8LUEP9R34HJITM58JWIKK.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/_Builtin_float-AQMXUP5O3BGHPGG6K7SSWCLNJ.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/SwiftShims-25J99BT6GN0E82BY0PHW6HXC8.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/Metal-P5TCWM12H5WTL9QEDJ1SOODC.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/Accessibility-5T3VXXJ54MRI3IGHH4KH7CJJZ.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/_LocationEssentials-EHSIDUR2LNY2JYRSYLGGSYB2D.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/Spatial-7V1ESMQYY6D6OMKL04HWOLBHH.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/os_object-56HN07FEBZGTO9H8T2WMD1U79.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/_Builtin_stdint-AOA27QZ2DADCJY35BMAL8DYFY.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/FileProvider-8GSC9KGEM1PLSPT8WR1VFAS2O.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/AVFoundation-2LTP3Z0HJRPI7NMJFLVWA0MCM.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/UniformTypeIdentifiers-9PLE3NN0QM7OVYW8B16JT4FSQ.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/Symbols-DEG4KD7FMPM4BWNYIRA8HPVQ.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/_Builtin_stdatomic-DQMTWWBBSG0KEU3J1DTZRPXDL.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/UIUtilities-DC50NXK2IAPRLFYJUFNLOJUJX.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/_DarwinFoundation2-8U51WUYVZPU5B3OJAKOA8HXEK.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/CoreLocation-BPNECTK3MPXQG4WOSUR3NKCU6.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/_Builtin_stddef-1OLFHJKBMLLBSJ9CNR38Q32WM.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/OSLog-5N15O6DRQQ0DDNOB8HFQA1X71.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/QuartzCore-HRDNOX9P3FRTKQVEX88C483P.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/_Builtin_inttypes-2R9BKW5AKSNBYY2PDJL8YQ5C2.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/Dispatch-1PCTTQ4RL5JF4H1JJ5ZR3QP4I.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/CoreImage-772Z8BZB6BRFL1W5H3EJEL121.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/ptrcheck-C8MC9K1BP8T3OQJOAG1LT6J1C.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/simd-9K6MS2LCUZ8U695C74G20BJVR.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/CoreMIDI-9ABARRYCSPP8QHKQC5ZSOIKGQ.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/VideoToolbox-7Q5V8M9ANPORZGE2Y9VDSE1L7.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/ImageIO-CKS1UJN2RVA5PW3E3HKEBN8ZG.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/_DarwinFoundation1-3RTNT9RWVVOI21BQTM2NRGJRY.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/UserNotifications-36UWNE93ZPLKUE649FRAMUE.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/CoreAudio-CQZC0DEZL7Y1C20ACVBE00EWJ.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/_AvailabilityInternal-EE5DZEL6UAY4XUTOINJY4US6J.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/Photos-3R36PU6BCYM20368XVT7PYGUH.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/CoreData-CPW44149DCP3L11M8RUU2EVQY.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/_Builtin_limits-K17DU31HEKPIBLY2F3GIAJXK.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/XPC-2LR3NFSXWGG4HCSB7GP7MJQT9.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/IOSurface-F33DAMST5TF0HTQ8YJNPOH0JI.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/MediaToolbox-BMMPRH44QZ3D8OR8770DAZGYX.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/_Builtin_stdarg-7VJDC0LF9BOWP15M6KYBUY5UJ.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/DeveloperToolsSupport-ACCIBO7KR77O8Y4ZGGMHL8Q4Q.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/ptrauth-3JW4VV69235UYPQAU1Y9GSBLN.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/CoreAudioTypes-2CBKPMSZ0ALD05AEKTF1BXLHP.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/CoreText-1QAKH3E0SL2F1VBFGVFUPA8AF.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/DataDetection-1XWGM9NUEP6794947BYT21WC3.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/_Builtin_tgmath-C13QTAMQK1IRN5CUPN81TCGGP.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/CoreGraphics-BU3OY6UKNF3IQAF3LWCVOVL0Y.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/_SwiftConcurrencyShims-9AE4DAUYKF682PWS9AM5N6MLZ.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/AudioToolbox-3DJ0FWS8CU1MR8A0GORPSZPY6.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/CoreVideo-4IW0CM7VDX0Q1N2SB7AU2WM0D.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/PhotosUI-6BKQQ9OPF5NZIRQ7D5J0084M2.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/CFNetwork-29YLQQCBVS7BA95QB1RS9QCPZ.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/CoreTransferable-3K8UQ6LT6JQ6ZTT82HS5B4GTG.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/ObjectiveC-532ES28E15T52VC0V9OGG1Y97.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/Darwin-ATGCRW6UVH36TJ2PAAC9GQJ87.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/Foundation-A6SOLY2RKYNJQC9DS7MH1PQM1.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/AVFAudio-16QMG3UZ2SGM3DQBXG65Q8S0U.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/UIKit-ENZZCUIKNP1JE8HQNDLEDX385.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/_Builtin_stdbool-D76COSQZ1DODGKRXK8TFISAMA.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/SwiftUI-DRQ57RJKI84SUAOP55Q2W2ZCK.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/dnssd-7AWUHGBLVLPEQAFG4OEO9AVST.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/_Builtin_intrinsics-1IW2XH7JCH3NDQW0JEY8R8Q70.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/OpenGLES-7MCHRYNKWCJQGCY45SAR5IFKH.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/MachO-56Y08DMBT4N9R6JX2WRIUYUIY.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/CoreFoundation-2OUUVC731DK3KJWVN79KVFN1X.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/Network-7WAIBCBXJG8ZD7S1Y0RRPXIGY.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/sys_types-B06XLAHXF7GK8U4LLYDIOJ84L.pcm /Users/runner/work/_temp/dd/ModuleCache.noindex/AVRouting-2SEV6PIJ6UL3JTZHAUORR2J5I.pcm /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder-dependencies-1.json (in target 'FusionRecorder' from project 'FusionRecorder')

CompileSwift normal arm64 (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    
/Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/ADB/CaptureOrchestrator.swift:304:34: warning: string interpolation produces a debug description for a function value; did you mean to make this explicit?
        append("本机接口：\(GlassesDiscovery.shared.interfaceDump)")
/Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/ADB/CaptureOrchestrator.swift:304:58: note: use 'String(describing:)' to silence this warning
        append("本机接口：\(GlassesDiscovery.shared.interfaceDump)")
/Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/UI/ContentView.swift:226:10: warning: 'onChange(of:perform:)' was deprecated in iOS 17.0: Use `onChange` with a two or zero parameter action closure instead.
        .onChange(of: fusionParams) { newValue in
         ^
/Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/UI/ContentView.swift:229:10: warning: 'onChange(of:perform:)' was deprecated in iOS 17.0: Use `onChange` with a two or zero parameter action closure instead.
        .onChange(of: scenePhase) { phase in
         ^
/Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/UI/ContentView.swift:238:10: warning: 'onChange(of:perform:)' was deprecated in iOS 17.0: Use `onChange` with a two or zero parameter action closure instead.
        .onChange(of: orchestrator.glassesIP) { newValue in
         ^
/Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/UI/ContentView.swift:249:10: warning: 'onChange(of:perform:)' was deprecated in iOS 17.0: Use `onChange` with a two or zero parameter action closure instead.
        .onChange(of: orchestrator.linkLost) { lost in
         ^
/Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/UI/ContentView.swift:256:10: warning: 'onChange(of:perform:)' was deprecated in iOS 17.0: Use `onChange` with a two or zero parameter action closure instead.
        .onChange(of: orchestrator.isConnected) { connected in
         ^
/Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/UI/ContentView.swift:263:10: warning: 'onChange(of:perform:)' was deprecated in iOS 17.0: Use `onChange` with a two or zero parameter action closure instead.
        .onChange(of: session.finishedMovieURL) { url in
         ^
/Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/UI/ContentView.swift:266:10: warning: 'onChange(of:perform:)' was deprecated in iOS 17.0: Use `onChange` with a two or zero parameter action closure instead.
        .onChange(of: session.recordError) { error in
         ^
/Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/UI/ContentView.swift:732:26: warning: 'onChange(of:perform:)' was deprecated in iOS 17.0: Use `onChange` with a two or zero parameter action closure instead.
                        .onChange(of: screenPicker) { item in
                         ^
/Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/UI/ContentView.swift:738:26: warning: 'onChange(of:perform:)' was deprecated in iOS 17.0: Use `onChange` with a two or zero parameter action closure instead.
                        .onChange(of: cameraPicker) { item in
                         ^
/Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/UI/FusionPreview.swift:57:10: warning: 'onChange(of:perform:)' was deprecated in iOS 17.0: Use `onChange` with a two or zero parameter action closure instead.
        .onChange(of: token) { _ in recompute() }
         ^
/Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Pipeline/OfflineCompositor.swift:90:30: warning: 'duration' was deprecated in iOS 16.0: Use load(.duration) instead
        let duration = asset.duration
                             ^
/Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Pipeline/OfflineCompositor.swift:94:33: warning: 'tracks(withMediaType:)' was deprecated in iOS 16.0: Use loadTracks(withMediaType:) instead
        guard let track = asset.tracks(withMediaType: .video).first else {
                                ^
/Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Pipeline/OfflineCompositor.swift:354:43: warning: 'tracks(withMediaType:)' was deprecated in iOS 16.0: Use loadTracks(withMediaType:) instead
        guard let audioTrack = audioAsset.tracks(withMediaType: .audio).first else {
                                          ^
/Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Pipeline/OfflineCompositor.swift:359:43: warning: 'tracks(withMediaType:)' was deprecated in iOS 16.0: Use loadTracks(withMediaType:) instead
        guard let videoTrack = videoAsset.tracks(withMediaType: .video).first else {
                                          ^
/Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Pipeline/OfflineCompositor.swift:371:73: warning: 'duration' was deprecated in iOS 16.0: Use load(.duration) instead
        let videoRange = CMTimeRange(start: .zero, duration: videoAsset.duration)
                                                                        ^
/Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Pipeline/OfflineCompositor.swift:385:37: warning: 'duration' was deprecated in iOS 16.0: Use load(.duration) instead
        let audioTotal = audioAsset.duration
                                    ^
/Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Session/RecorderSession.swift:845:23: warning: value 'self' was defined but never used; consider replacing with boolean test
            guard let self = self else { return }
                  ~~~~^~~~~~~
                                  != nil
/Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS/FusionRecorder/Session/RecorderSession.swift:866:23: warning: value 'self' was defined but never used; consider replacing with boolean test
            guard let self = self else { return }
                  ~~~~^~~~~~~
                                  != nil

SwiftDriverJobDiscovery normal arm64 Compiling ADBAuth.swift, ADBClient.swift, ADBPacket.swift, ADBSyncPuller.swift, ADBSyncPusher.swift, CaptureOrchestrator.swift, ContentView.swift, FrameStore.swift, FusionCompositor.swift, FusionParams.swift, FusionPreview.swift, FusionPtsParser.swift, FusionRecorderApp.swift, GlassesDiscovery.swift, H264FrameDecoder.swift, H264StreamListener.swift, H264StreamReceiver.swift, OfflineCompositor.swift, RecorderSession.swift, RecordingViews.swift, Theme.swift, VideoPipeline.swift, GeneratedAssetSymbols.swift (in target 'FusionRecorder' from project 'FusionRecorder')

SwiftDriver\ Compilation\ Requirements FusionRecorder normal arm64 com.apple.xcode.tools.swift.compiler (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    builtin-Swift-Compilation-Requirements -- /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc -module-name FusionRecorder -O -whole-module-optimization @/Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder.SwiftFileList -enable-bare-slash-regex -enable-experimental-feature DebugDescriptionMacro -sdk /Applications/Xcode_26.6.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk -target arm64-apple-ios17.0 -g -module-cache-path /Users/runner/work/_temp/dd/ModuleCache.noindex -Xfrontend -serialize-debugging-options -swift-version 5 -I /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos -F /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos -c -num-threads 3 -Xcc -ivfsstatcache -Xcc /Users/runner/work/_temp/dd/SDKStatCaches.noindex/iphoneos26.5-23F81a-688ef53f1462e2c8f657fdc38a81448fee66e23052a0157c865c76b268046726.sdkstatcache -output-file-map /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder-OutputFileMap.json -use-frontend-parseable-output -save-temps -no-color-diagnostics -explicit-module-build -module-cache-path /Users/runner/work/_temp/dd/Build/Intermediates.noindex/SwiftExplicitPrecompiledModules -clang-scanner-module-cache-path /Users/runner/work/_temp/dd/ModuleCache.noindex -sdk-module-cache-path /Users/runner/work/_temp/dd/ModuleCache.noindex -serialize-diagnostics -emit-dependencies -emit-module -emit-module-path /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder.swiftmodule -validate-clang-modules-once -clang-build-session-file /Users/runner/work/_temp/dd/ModuleCache.noindex/Session.modulevalidation -Xcc -I/Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/swift-overrides.hmap -emit-const-values -Xfrontend -const-gather-protocols-file -Xfrontend /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder_const_extract_protocols.json -Xcc -iquote -Xcc /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder-generated-files.hmap -Xcc -I/Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder-own-target-headers.hmap -Xcc -I/Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder-all-target-headers.hmap -Xcc -iquote -Xcc /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder-project-headers.hmap -Xcc -I/Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/include -Xcc -I/Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/DerivedSources-normal/arm64 -Xcc -I/Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/DerivedSources/arm64 -Xcc -I/Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/DerivedSources -emit-objc-header -emit-objc-header-path /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder-Swift.h -working-directory /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS -no-emit-module-separately-wmo

SwiftMergeGeneratedHeaders /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/DerivedSources/FusionRecorder-Swift.h /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder-Swift.h (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    builtin-swiftHeaderTool -arch arm64 /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder-Swift.h -o /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/DerivedSources/FusionRecorder-Swift.h

Copy /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.swiftmodule/arm64-apple-ios.swiftdoc /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder.swiftdoc (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    builtin-copy -exclude .DS_Store -exclude CVS -exclude .svn -exclude .git -exclude .hg -resolve-src-symlinks -rename /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder.swiftdoc /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.swiftmodule/arm64-apple-ios.swiftdoc

Copy /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.swiftmodule/arm64-apple-ios.swiftmodule /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder.swiftmodule (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    builtin-copy -exclude .DS_Store -exclude CVS -exclude .svn -exclude .git -exclude .hg -resolve-src-symlinks -rename /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder.swiftmodule /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.swiftmodule/arm64-apple-ios.swiftmodule

Copy /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.swiftmodule/arm64-apple-ios.abi.json /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder.abi.json (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    builtin-copy -exclude .DS_Store -exclude CVS -exclude .svn -exclude .git -exclude .hg -resolve-src-symlinks -rename /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder.abi.json /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.swiftmodule/arm64-apple-ios.abi.json

Copy /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.swiftmodule/Project/arm64-apple-ios.swiftsourceinfo /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder.swiftsourceinfo (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    builtin-copy -exclude .DS_Store -exclude CVS -exclude .svn -exclude .git -exclude .hg -resolve-src-symlinks -rename /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder.swiftsourceinfo /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.swiftmodule/Project/arm64-apple-ios.swiftsourceinfo

Ld /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app/FusionRecorder normal (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang -Xlinker -reproducible -target arm64-apple-ios17.0 -isysroot /Applications/Xcode_26.6.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk -Os -L/Users/runner/work/_temp/dd/Build/Intermediates.noindex/EagerLinkingTBDs/Release-iphoneos -L/Users/runner/work/_temp/dd/Build/Products/Release-iphoneos -F/Users/runner/work/_temp/dd/Build/Intermediates.noindex/EagerLinkingTBDs/Release-iphoneos -F/Users/runner/work/_temp/dd/Build/Products/Release-iphoneos -filelist /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder.LinkFileList -Xlinker -rpath -Xlinker /usr/lib/swift -Xlinker -rpath -Xlinker @executable_path/Frameworks -Xlinker -dead_strip -Xlinker -object_path_lto -Xlinker /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder_lto.o -Xlinker -dependency_info -Xlinker /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder_dependency_info.dat -fobjc-link-runtime -L/Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos -L/usr/lib/swift -Xlinker -add_ast_path -Xlinker /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder.swiftmodule @/Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder-linker-args.resp -o /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app/FusionRecorder

GenerateDSYMFile /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app.dSYM /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app/FusionRecorder (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/dsymutil /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app/FusionRecorder -o /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app.dSYM

CopySwiftLibs /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    builtin-swiftStdLibTool --copy --verbose --scan-executable /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app/FusionRecorder --scan-folder /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app/Frameworks --scan-folder /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app/PlugIns --scan-folder /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app/SystemExtensions --scan-folder /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app/Extensions --platform iphoneos --toolchain /var/run/com.apple.security.cryptexd/mnt/com.apple.MobileAsset.MetalToolchain-v17.6.109.0.SwnYgI/Metal.xctoolchain --toolchain /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain --destination /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app/Frameworks --strip-bitcode --strip-bitcode-tool /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/bitcode_strip --emit-dependency-info /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/SwiftStdLibToolInputDependencies.dep --filter-for-swift-os --back-deploy-swift-span
Ignoring --strip-bitcode because --sign was not passed

ExtractAppIntentsMetadata (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/appintentsmetadataprocessor --toolchain-dir /var/run/com.apple.security.cryptexd/mnt/com.apple.MobileAsset.MetalToolchain-v17.6.109.0.SwnYgI/Metal.xctoolchain --module-name FusionRecorder --sdk-root /Applications/Xcode_26.6.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk --xcode-version 17F113 --platform-family iOS --deployment-target 17.0 --bundle-identifier com.lath.fusionrecorder --output /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app --target-triple arm64-apple-ios17.0 --binary-file /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app/FusionRecorder --dependency-file /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder_dependency_info.dat --stringsdata-file /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/ExtractedAppShortcutsMetadata.stringsdata --source-file-list /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder.SwiftFileList --metadata-file-list /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder.DependencyMetadataFileList --static-metadata-file-list /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder.DependencyStaticMetadataFileList --swift-const-vals-list /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/Objects-normal/arm64/FusionRecorder.SwiftConstValuesFileList --compile-time-extraction --deployment-aware-processing --validate-assistant-intents --no-app-shortcuts-localization
2026-11-23 08:27:29.105 appintentsmetadataprocessor[2396:10611] Starting appintentsmetadataprocessor export
2026-11-23 08:27:29.118 appintentsmetadataprocessor[2396:10611] warning: Metadata extraction skipped. No AppIntents.framework dependency found.

AppIntentsSSUTraining (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    /Applications/Xcode_26.6.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/appintentsnltrainingprocessor --infoplist-path /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app/Info.plist --temp-dir-path /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/ssu --bundle-id com.lath.fusionrecorder --product-path /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app --extracted-metadata-path /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app/Metadata.appintents --metadata-file-list /Users/runner/work/_temp/dd/Build/Intermediates.noindex/FusionRecorder.build/Release-iphoneos/FusionRecorder.build/FusionRecorder.DependencyMetadataFileList --source-file /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app/Info.plist --archive-ssu-assets
2026-11-23 08:27:29.229 appintentsnltrainingprocessor[2397:10612] Parsing options for appintentsnltrainingprocessor
2026-11-23 08:27:29.232 appintentsnltrainingprocessor[2397:10612] Starting AppIntents SSU YAML Generation
2026-11-23 08:27:29.240 appintentsnltrainingprocessor[2397:10612] No AppShortcuts found - Skipping.

RegisterExecutionPolicyException /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    builtin-RegisterExecutionPolicyException /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app

Validate /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    builtin-validationUtility /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app -shallow-bundle -infoplist-subpath Info.plist

Touch /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app (in target 'FusionRecorder' from project 'FusionRecorder')
    cd /Users/runner/work/FusionRecorder-iOS/FusionRecorder-iOS
    /usr/bin/touch -c /Users/runner/work/_temp/dd/Build/Products/Release-iphoneos/FusionRecorder.app

** BUILD SUCCEEDED **

```
