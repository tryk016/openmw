find_library(FOUNDATION_FRAMEWORK Foundation REQUIRED)
find_library(UIKIT_FRAMEWORK UIKit REQUIRED)

option(OPENMW_IOS_ENABLE_CODE_SIGNING "Enable automatic Apple development signing" OFF)
set(OPENMW_IOS_DEVELOPMENT_TEAM "" CACHE STRING "Apple development team used for local Xcode installation")

add_executable(openmw-ios-bootstrap MACOSX_BUNDLE
    BootstrapStatus.cpp
    BootstrapStatus.hpp
    Main.mm
)

target_compile_features(openmw-ios-bootstrap PRIVATE cxx_std_20)
target_compile_options(openmw-ios-bootstrap PRIVATE
    "$<$<COMPILE_LANGUAGE:CXX,OBJCXX>:-Wall;-Wextra;-Wpedantic>"
)
target_link_libraries(openmw-ios-bootstrap PRIVATE
    ${FOUNDATION_FRAMEWORK}
    ${UIKIT_FRAMEWORK}
)

set_target_properties(openmw-ios-bootstrap PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in"
    MACOSX_BUNDLE_BUNDLE_NAME "OpenMW iOS Bootstrap"
    MACOSX_BUNDLE_GUI_IDENTIFIER "org.openmw.ios.bootstrap"
    MACOSX_BUNDLE_BUNDLE_VERSION "1"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
    OUTPUT_NAME "OpenMW"
    XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC "YES"
    XCODE_ATTRIBUTE_DEBUG_INFORMATION_FORMAT "dwarf-with-dsym"
    XCODE_ATTRIBUTE_ENABLE_TESTABILITY "YES"
    XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH "NO"
    XCODE_ATTRIBUTE_SUPPORTED_PLATFORMS "iphoneos iphonesimulator"
    XCODE_ATTRIBUTE_SUPPORTS_MACCATALYST "NO"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
)

if(OPENMW_IOS_ENABLE_CODE_SIGNING)
    set_target_properties(openmw-ios-bootstrap PROPERTIES
        XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "YES"
        XCODE_ATTRIBUTE_CODE_SIGN_STYLE "Automatic"
    )
    if(OPENMW_IOS_DEVELOPMENT_TEAM)
        set_target_properties(openmw-ios-bootstrap PROPERTIES
            XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "${OPENMW_IOS_DEVELOPMENT_TEAM}"
        )
    endif()
else()
    set_target_properties(openmw-ios-bootstrap PROPERTIES
        XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO"
        XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "NO"
    )
endif()

message(STATUS
    "Configuring OpenMW iOS bootstrap: "
    "sdk=${CMAKE_OSX_SYSROOT}, arch=${CMAKE_OSX_ARCHITECTURES}, "
    "minimum=${CMAKE_OSX_DEPLOYMENT_TARGET}, signing=${OPENMW_IOS_ENABLE_CODE_SIGNING}"
)
