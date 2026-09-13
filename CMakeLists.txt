cmake_minimum_required(VERSION 3.21)

project(VideoDownloader VERSION 0.1.0 LANGUAGES CXX)

set(RECLIP_IOS OFF)
if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
    set(RECLIP_IOS ON)
endif()

if(APPLE AND NOT RECLIP_IOS)
    set(RECLIP_MACOS_DEPLOYMENT_TARGET "14.0" CACHE STRING
        "Minimum macOS version supported by Video Downloader")
    set(CMAKE_OSX_DEPLOYMENT_TARGET "${RECLIP_MACOS_DEPLOYMENT_TARGET}"
        CACHE STRING "Minimum macOS version supported by Video Downloader" FORCE)
    configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/packaging/macos/Info.plist.in"
        "${CMAKE_CURRENT_BINARY_DIR}/ReClipInfo.plist"
        @ONLY
    )
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

option(RECLIP_ENABLE_FFMPEG_SDK
    "Build the in-process FFmpeg SDK backend"
    OFF
)
set(RECLIP_FFMPEG_ROOT "" CACHE PATH
    "FFmpeg SDK root containing include/, lib/, and bin/"
)

set(RECLIP_HAS_FFMPEG_SDK OFF)
if(RECLIP_ENABLE_FFMPEG_SDK)
    if(NOT RECLIP_FFMPEG_ROOT AND DEFINED ENV{RECLIP_FFMPEG_ROOT})
        set(RECLIP_FFMPEG_ROOT "$ENV{RECLIP_FFMPEG_ROOT}" CACHE PATH
            "FFmpeg SDK root containing include/, lib/, and bin/"
            FORCE
        )
    endif()
    if(NOT RECLIP_FFMPEG_ROOT
        AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/.third_party/ffmpeg/windows-x64")
        set(RECLIP_FFMPEG_ROOT
            "${CMAKE_CURRENT_SOURCE_DIR}/.third_party/ffmpeg/windows-x64"
            CACHE PATH
            "FFmpeg SDK root containing include/, lib/, and bin/"
            FORCE
        )
    endif()

    find_package(FFmpeg REQUIRED)
    set(RECLIP_HAS_FFMPEG_SDK ON)
    message(STATUS "FFmpeg SDK enabled: ${RECLIP_FFMPEG_ROOT}")
else()
    message(STATUS "FFmpeg SDK disabled; using the existing process backend")
endif()

option(RECLIP_ENABLE_KIRIGAMI
    "Use KDE Kirigami for the adaptive application shell"
    ON
)
set(RECLIP_KIRIGAMI_PREFIX
    "${CMAKE_CURRENT_SOURCE_DIR}/.third_party/install"
    CACHE PATH
    "Prefix containing the locally built Kirigami and ECM packages"
)

set(RECLIP_HAS_KIRIGAMI OFF)
if(RECLIP_ENABLE_KIRIGAMI AND NOT RECLIP_IOS)
    if(EXISTS "${RECLIP_KIRIGAMI_PREFIX}")
        list(PREPEND CMAKE_PREFIX_PATH "${RECLIP_KIRIGAMI_PREFIX}")
    endif()

    find_package(KF6Kirigami 6.8 CONFIG QUIET)
    if(KF6Kirigami_FOUND)
        set(RECLIP_HAS_KIRIGAMI ON)
        set(RECLIP_KIRIGAMI_QML_DIR
            "${RECLIP_KIRIGAMI_PREFIX}/lib/qml"
            CACHE PATH
            "QML import directory installed by Kirigami"
        )
        if(NOT EXISTS "${RECLIP_KIRIGAMI_QML_DIR}/org")
            get_filename_component(RECLIP_KIRIGAMI_LIB_DIR
                "${KF6Kirigami_DIR}/../.."
                ABSOLUTE
            )
            get_filename_component(RECLIP_KIRIGAMI_PREFIX
                "${RECLIP_KIRIGAMI_LIB_DIR}/.."
                ABSOLUTE
            )
            set(RECLIP_KIRIGAMI_QML_DIR
                "${RECLIP_KIRIGAMI_LIB_DIR}/qml"
                CACHE PATH
                "QML import directory installed by Kirigami"
                FORCE
            )
        endif()
        message(STATUS "Kirigami ${KF6Kirigami_VERSION} enabled")
    else()
        message(STATUS "Kirigami not found; using the Qt Quick Controls 2 shell")
    endif()
elseif(RECLIP_IOS)
    message(STATUS "Kirigami disabled for iOS; using the native mobile shell")
else()
    message(STATUS "Kirigami disabled by RECLIP_ENABLE_KIRIGAMI=OFF")
endif()

find_package(Qt6 6.8 REQUIRED COMPONENTS Quick QuickControls2 Network)
if(RECLIP_HAS_FFMPEG_SDK)
    find_package(Qt6 6.8 REQUIRED COMPONENTS Concurrent)
endif()
if(RECLIP_HAS_KIRIGAMI)
    find_package(Qt6 6.8 REQUIRED COMPONENTS Svg Concurrent ShaderTools)
    set(QML_IMPORT_PATH "${RECLIP_KIRIGAMI_QML_DIR}")
endif()

qt_standard_project_setup(REQUIRES 6.8)

if(NOT RECLIP_IOS)
    include(cmake/YtDlp.cmake)
endif()

# Keep the generated QML module directory away from the Unix executable path.
# The module URI is ReClip, while the Linux linker also emits a ReClip binary.
set(QT_QML_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/qml")

set_source_files_properties(qml/Theme.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE
)

set(RECLIP_APP_TARGET ReClipApp)

qt_add_executable(${RECLIP_APP_TARGET}
    src/main.cpp
)

target_include_directories(${RECLIP_APP_TARGET} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)

set(RECLIP_QML_FILES
    qml/Main.qml
    qml/Theme.qml
    qml/components/ActivityPanel.qml
    qml/components/AppButton.qml
    qml/components/AppDialog.qml
    qml/components/AppSelect.qml
    qml/components/AppTextField.qml
    qml/components/DesktopSidebar.qml
    qml/components/DownloadRow.qml
    qml/components/DownloadStatusPanel.qml
    qml/components/InlineNotice.qml
    qml/components/IconGlyph.qml
    qml/components/LinkCapture.qml
    qml/components/MediaPreview.qml
    qml/components/MobileHeader.qml
    qml/components/MobileSettingsDrawer.qml
    qml/components/NavigationItem.qml
    qml/components/SignalTrace.qml
    qml/components/StatusPill.qml
    qml/vendor/QuickMaterial/Corner.qml
    qml/vendor/QuickMaterial/Metrics.qml
    qml/vendor/QuickMaterial/States.qml
    qml/pages/NewDownloadPage.qml
    qml/pages/QueuePage.qml
    qml/pages/IosSettingsPage.qml
    qml/pages/SettingsPage.qml
)

if(RECLIP_HAS_KIRIGAMI)
    list(APPEND RECLIP_QML_FILES
        qml/MainKirigami.qml
        qml/kirigami/KirigamiNewDownloadPage.qml
        qml/kirigami/KirigamiQueuePage.qml
        qml/kirigami/KirigamiSettingsPage.qml
    )
endif()

set(RECLIP_DOWNLOAD_MANAGER_SOURCE src/DownloadManager.cpp)
if(RECLIP_IOS)
    set(RECLIP_DOWNLOAD_MANAGER_SOURCE src/DownloadManagerIos.cpp)
endif()

qt_add_qml_module(${RECLIP_APP_TARGET}
    URI ReClip
    VERSION 1.0
    QML_FILES ${RECLIP_QML_FILES}
RESOURCES
    qml/vendor/QuickMaterial/qmldir
    SOURCES
        src/AppController.h
        src/AppController.cpp
        src/AndroidDownloadEngine.h
        src/AndroidDownloadEngine.cpp
        src/PlatformPaths.h
        src/PlatformPaths.cpp
        src/ToolLocator.h
        src/ToolLocator.cpp
        src/MediaInspector.h
        src/MediaInspector.cpp
        src/DownloadManager.h
        ${RECLIP_DOWNLOAD_MANAGER_SOURCE}
        src/DownloadQueue.h
        src/DownloadQueue.cpp
        src/AppSettings.h
        src/AppSettings.cpp
        src/PlatformStorage.h
        src/PlatformStorage.cpp
    )

if(RECLIP_HAS_FFMPEG_SDK)
    add_library(ReClipFfmpegSdk STATIC
        src/ffmpeg/FfmpegSdk.h
        src/ffmpeg/FfmpegSdk.cpp
        src/ffmpeg/FfmpegTypes.h
        src/ffmpeg/FfprobeService.h
        src/ffmpeg/FfprobeService.cpp
        src/ffmpeg/FfmpegService.h
        src/ffmpeg/FfmpegService.cpp
    )
    target_include_directories(ReClipFfmpegSdk PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/src
    )
    target_compile_features(ReClipFfmpegSdk PUBLIC cxx_std_17)
    target_compile_definitions(ReClipFfmpegSdk PUBLIC RECLIP_HAS_FFMPEG_SDK=1)
    target_link_libraries(ReClipFfmpegSdk
        PRIVATE
            FFmpeg::FFmpeg
            Qt6::Core
    )
endif()

set_target_properties(${RECLIP_APP_TARGET} PROPERTIES
    OUTPUT_NAME ReClip
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_BUNDLE_NAME "Video Downloader"
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.reclip.app"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
    MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
    WIN32_EXECUTABLE TRUE
)

if(RECLIP_IOS)
    set_target_properties(${RECLIP_APP_TARGET} PROPERTIES
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/packaging/Info.ios.plist.in"
        XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
    )
elseif(APPLE)
    set_target_properties(${RECLIP_APP_TARGET} PROPERTIES
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_BINARY_DIR}/ReClipInfo.plist"
    )
endif()

if(ANDROID)
    # Keep the default identity stable; a separate application ID permits
    # device testing without replacing an app signed on another workstation.
    set(RECLIP_ANDROID_APPLICATION_ID "com.reclip.videodownloader" CACHE STRING
        "Android application ID (override for a side-by-side development install)")
    set(RECLIP_ANDROID_PACKAGE_SOURCE_DIR
        "${CMAKE_CURRENT_SOURCE_DIR}/android"
        CACHE PATH
        "Android package source directory, optionally staged with runtime AARs"
    )
    set_target_properties(${RECLIP_APP_TARGET} PROPERTIES
        QT_ANDROID_PACKAGE_SOURCE_DIR "${RECLIP_ANDROID_PACKAGE_SOURCE_DIR}"
        QT_ANDROID_PACKAGE_NAME "${RECLIP_ANDROID_APPLICATION_ID}"
        QT_ANDROID_APP_NAME "Video Downloader"
        QT_ANDROID_MIN_SDK_VERSION 28
        QT_ANDROID_TARGET_SDK_VERSION 35
        QT_ANDROID_VERSION_CODE 1
        QT_ANDROID_VERSION_NAME "${PROJECT_VERSION}"
    )
endif()

target_link_libraries(${RECLIP_APP_TARGET} PRIVATE
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Network
)

if(NOT RECLIP_IOS)
    target_link_libraries(${RECLIP_APP_TARGET} PRIVATE ReClipYtDlp)
    reclip_stage_python_runtime(${RECLIP_APP_TARGET})
endif()

if(RECLIP_HAS_FFMPEG_SDK)
    target_link_libraries(${RECLIP_APP_TARGET} PRIVATE
        ReClipFfmpegSdk
        Qt6::Concurrent
    )
endif()

function(reclip_stage_ffmpeg_runtime target_name)
    if(NOT RECLIP_HAS_FFMPEG_SDK OR NOT WIN32)
        return()
    endif()

    file(GLOB RECLIP_FFMPEG_RUNTIME_DLLS LIST_DIRECTORIES FALSE
        "${RECLIP_FFMPEG_ROOT}/bin/*.dll"
    )
    if(NOT RECLIP_FFMPEG_RUNTIME_DLLS)
        message(FATAL_ERROR
            "FFmpeg SDK is enabled, but no runtime DLLs were found in "
            "${RECLIP_FFMPEG_ROOT}/bin"
        )
    endif()

    foreach(runtime_dll IN LISTS RECLIP_FFMPEG_RUNTIME_DLLS)
        add_custom_command(TARGET ${target_name} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${runtime_dll}"
                "$<TARGET_FILE_DIR:${target_name}>"
            VERBATIM
        )
    endforeach()
endfunction()

if(RECLIP_HAS_FFMPEG_SDK)
    reclip_stage_ffmpeg_runtime(${RECLIP_APP_TARGET})
endif()

if(RECLIP_HAS_KIRIGAMI)
    target_link_libraries(${RECLIP_APP_TARGET} PRIVATE KF6::Kirigami)
    target_compile_definitions(${RECLIP_APP_TARGET} PRIVATE RECLIP_HAS_KIRIGAMI=1)

    if(WIN32)
        file(GLOB RECLIP_KIRIGAMI_RUNTIME_DLLS
            "${RECLIP_KIRIGAMI_PREFIX}/bin/Kirigami*.dll"
        )
        foreach(RECLIP_KIRIGAMI_RUNTIME_DLL IN LISTS RECLIP_KIRIGAMI_RUNTIME_DLLS)
            add_custom_command(TARGET ${RECLIP_APP_TARGET} POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${RECLIP_KIRIGAMI_RUNTIME_DLL}"
                    "$<TARGET_FILE_DIR:${RECLIP_APP_TARGET}>"
            )
            install(FILES "${RECLIP_KIRIGAMI_RUNTIME_DLL}" DESTINATION .)
        endforeach()
    endif()

    if(EXISTS "${RECLIP_KIRIGAMI_QML_DIR}/org")
        add_custom_command(TARGET ${RECLIP_APP_TARGET} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_directory
                "${RECLIP_KIRIGAMI_QML_DIR}/org"
                "$<TARGET_FILE_DIR:${RECLIP_APP_TARGET}>/qml/org"
        )
        install(DIRECTORY "${RECLIP_KIRIGAMI_QML_DIR}/org" DESTINATION qml)
    endif()
endif()

include(GNUInstallDirs)
install(TARGETS ${RECLIP_APP_TARGET}
    RUNTIME DESTINATION .
    LIBRARY DESTINATION .
    ARCHIVE DESTINATION .
    BUNDLE DESTINATION .
)

if(RECLIP_HAS_FFMPEG_SDK)
    install(DIRECTORY "${RECLIP_FFMPEG_ROOT}/bin/"
        DESTINATION .
        FILES_MATCHING
            PATTERN "*.dll"
            PATTERN "*.dylib"
            PATTERN "*.so*"
    )
endif()

include(CTest)

if(BUILD_TESTING)
    qt_add_executable(ReClipSmokeTest
        tests/smoke.cpp
    )

    target_link_libraries(ReClipSmokeTest PRIVATE Qt6::Core)
    add_test(NAME ReClipSmokeTest COMMAND ReClipSmokeTest)

    qt_add_executable(ReClipToolLocatorTest
        tests/tool_locator.cpp
        src/AndroidDownloadEngine.h
        src/AndroidDownloadEngine.cpp
        src/ToolLocator.h
        src/ToolLocator.cpp
        src/PlatformPaths.h
        src/PlatformPaths.cpp
    )

    target_include_directories(ReClipToolLocatorTest PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
    )
    target_link_libraries(ReClipToolLocatorTest PRIVATE Qt6::Core Qt6::Qml)
    if(RECLIP_HAS_FFMPEG_SDK)
        target_link_libraries(ReClipToolLocatorTest PRIVATE ReClipFfmpegSdk)
        reclip_stage_ffmpeg_runtime(ReClipToolLocatorTest)
    endif()
    add_test(NAME ReClipToolLocatorTest COMMAND ReClipToolLocatorTest)

    qt_add_executable(ReClipMediaInspectorTest
        tests/media_inspector.cpp
        src/AndroidDownloadEngine.h
        src/AndroidDownloadEngine.cpp
        src/MediaInspector.h
        src/MediaInspector.cpp
    )

    target_include_directories(ReClipMediaInspectorTest PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
    )
    target_link_libraries(ReClipMediaInspectorTest PRIVATE Qt6::Core Qt6::Qml)
    add_test(NAME ReClipMediaInspectorTest COMMAND ReClipMediaInspectorTest)

    qt_add_executable(ReClipDownloadManagerTest
        tests/download_manager.cpp
        src/AndroidDownloadEngine.h
        src/AndroidDownloadEngine.cpp
        src/DownloadManager.h
        src/DownloadManager.cpp
        src/PlatformPaths.h
        src/PlatformPaths.cpp
        src/PlatformStorage.h
        src/PlatformStorage.cpp
    )

    target_include_directories(ReClipDownloadManagerTest PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
    )
    target_link_libraries(ReClipDownloadManagerTest PRIVATE Qt6::Core Qt6::Gui Qt6::Qml)
    add_test(NAME ReClipDownloadManagerTest COMMAND ReClipDownloadManagerTest)

    set(RECLIP_DOWNLOAD_QUEUE_TEST_SOURCES
        tests/download_queue.cpp
        src/AndroidDownloadEngine.h
        src/AndroidDownloadEngine.cpp
        src/DownloadQueue.h
        src/DownloadQueue.cpp
        src/PlatformPaths.h
        src/PlatformPaths.cpp
        src/PlatformStorage.h
        src/PlatformStorage.cpp
    )
    if(RECLIP_HAS_FFMPEG_SDK AND NOT RECLIP_IOS)
        list(APPEND RECLIP_DOWNLOAD_QUEUE_TEST_SOURCES
            src/DownloadManager.h
            src/DownloadManager.cpp
        )
    endif()
    qt_add_executable(ReClipDownloadQueueTest
        ${RECLIP_DOWNLOAD_QUEUE_TEST_SOURCES}
    )

    target_include_directories(ReClipDownloadQueueTest PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
    )
    target_link_libraries(ReClipDownloadQueueTest PRIVATE Qt6::Core Qt6::Gui Qt6::Qml)
    # When the SDK is enabled, exercise the same embedded backend that the
    # desktop application uses instead of compiling only the legacy path.
    if(RECLIP_HAS_FFMPEG_SDK)
        target_compile_definitions(ReClipDownloadQueueTest PRIVATE RECLIP_HAS_FFMPEG_SDK=1)
        target_link_libraries(ReClipDownloadQueueTest PRIVATE
            ReClipFfmpegSdk
            Qt6::Concurrent
            Qt6::Network
        )
        reclip_stage_ffmpeg_runtime(ReClipDownloadQueueTest)
    endif()
    add_test(NAME ReClipDownloadQueueTest COMMAND ReClipDownloadQueueTest)

    qt_add_executable(ReClipAppSettingsTest
        tests/app_settings.cpp
        src/AppSettings.h
        src/AppSettings.cpp
        src/PlatformPaths.h
        src/PlatformPaths.cpp
    )

    target_include_directories(ReClipAppSettingsTest PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
    )
    target_link_libraries(ReClipAppSettingsTest PRIVATE Qt6::Core Qt6::Qml)
    add_test(NAME ReClipAppSettingsTest COMMAND ReClipAppSettingsTest)

    if(RECLIP_HAS_FFMPEG_SDK)
        qt_add_executable(ReClipFfmpegSdkTest
            tests/ffmpeg_sdk.cpp
        )

        target_include_directories(ReClipFfmpegSdkTest PRIVATE
            ${CMAKE_CURRENT_SOURCE_DIR}/src
        )
        target_link_libraries(ReClipFfmpegSdkTest PRIVATE
            ReClipFfmpegSdk
            Qt6::Core
        )
        add_test(NAME ReClipFfmpegSdkTest COMMAND ReClipFfmpegSdkTest)
        reclip_stage_ffmpeg_runtime(ReClipFfmpegSdkTest)

        qt_add_executable(ReClipFfmpegServiceTest
            tests/ffmpeg_service.cpp
        )

        target_include_directories(ReClipFfmpegServiceTest PRIVATE
            ${CMAKE_CURRENT_SOURCE_DIR}/src
        )
        target_link_libraries(ReClipFfmpegServiceTest PRIVATE
            ReClipFfmpegSdk
            Qt6::Core
        )
        add_test(NAME ReClipFfmpegServiceTest COMMAND ReClipFfmpegServiceTest)
        reclip_stage_ffmpeg_runtime(ReClipFfmpegServiceTest)

        qt_add_executable(ReClipFakeYtDlp
            tests/fake_ytdlp.cpp
        )
        target_link_libraries(ReClipFakeYtDlp PRIVATE Qt6::Core)

        qt_add_executable(ReClipSdkDownloadManagerTest
            tests/download_manager_sdk.cpp
            src/AndroidDownloadEngine.h
            src/AndroidDownloadEngine.cpp
            src/DownloadManager.h
            src/DownloadManager.cpp
            src/PlatformPaths.h
            src/PlatformPaths.cpp
            src/PlatformStorage.h
            src/PlatformStorage.cpp
        )

        target_include_directories(ReClipSdkDownloadManagerTest PRIVATE
            ${CMAKE_CURRENT_SOURCE_DIR}/src
        )
        target_compile_definitions(ReClipSdkDownloadManagerTest PRIVATE
            RECLIP_HAS_FFMPEG_SDK=1
        )
        target_link_libraries(ReClipSdkDownloadManagerTest PRIVATE
            ReClipFfmpegSdk
            Qt6::Concurrent
            Qt6::Core
            Qt6::Gui
            Qt6::Network
            Qt6::Qml
        )
        add_dependencies(ReClipSdkDownloadManagerTest ReClipFakeYtDlp)
        add_custom_command(TARGET ReClipSdkDownloadManagerTest POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${CMAKE_CURRENT_SOURCE_DIR}/tests/fixtures/tiny_video_mp4.b64"
                "$<TARGET_FILE_DIR:ReClipSdkDownloadManagerTest>"
            VERBATIM
        )
        add_test(NAME ReClipSdkDownloadManagerTest COMMAND ReClipSdkDownloadManagerTest)
        reclip_stage_ffmpeg_runtime(ReClipSdkDownloadManagerTest)
    endif()
endif()

if(BUILD_TESTING AND NOT RECLIP_IOS)
    foreach(_ytdlp_consumer ReClipToolLocatorTest ReClipMediaInspectorTest ReClipDownloadManagerTest ReClipDownloadQueueTest ReClipSdkDownloadManagerTest)
        if(TARGET ${_ytdlp_consumer})
            target_link_libraries(${_ytdlp_consumer} PRIVATE ReClipYtDlp)
            reclip_stage_python_runtime(${_ytdlp_consumer})
        endif()
    endforeach()
    if(RECLIP_ENABLE_YTDLP_SDK AND RECLIP_HAS_FFMPEG_SDK)
        qt_add_executable(ReClipEmbeddedYtDlpTest
            tests/ytdlp_embedded.cpp
            src/DownloadQueue.h src/DownloadQueue.cpp
            src/AndroidDownloadEngine.h src/AndroidDownloadEngine.cpp
            src/MediaInspector.h src/MediaInspector.cpp
            src/DownloadManager.h src/DownloadManager.cpp
            src/PlatformPaths.h src/PlatformPaths.cpp
            src/PlatformStorage.h src/PlatformStorage.cpp
        )
        target_link_libraries(ReClipEmbeddedYtDlpTest PRIVATE
            ReClipYtDlp ReClipFfmpegSdk Qt6::Gui Qt6::Qml Qt6::Network Qt6::Concurrent)
        reclip_stage_python_runtime(ReClipEmbeddedYtDlpTest)
        reclip_stage_ffmpeg_runtime(ReClipEmbeddedYtDlpTest)
        add_custom_command(TARGET ReClipEmbeddedYtDlpTest POST_BUILD
            COMMAND "${CMAKE_COMMAND}" -E copy_if_different
                "${CMAKE_CURRENT_SOURCE_DIR}/tests/fixtures/tiny_video_mp4.b64"
                "$<TARGET_FILE_DIR:ReClipEmbeddedYtDlpTest>"
            VERBATIM)
        add_test(NAME ReClipEmbeddedYtDlpTest COMMAND ReClipEmbeddedYtDlpTest)
        set_tests_properties(ReClipEmbeddedYtDlpTest PROPERTIES TIMEOUT 60)
    endif()
endif()
