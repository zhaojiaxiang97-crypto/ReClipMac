cmake_minimum_required(VERSION 3.21)

project(ReClipQt VERSION 0.1.0 LANGUAGES CXX)

if(APPLE)
    set(RECLIP_MACOS_DEPLOYMENT_TARGET "14.0" CACHE STRING
        "Minimum macOS version supported by ReClip")
    set(CMAKE_OSX_DEPLOYMENT_TARGET "${RECLIP_MACOS_DEPLOYMENT_TARGET}"
        CACHE STRING "Minimum macOS version supported by ReClip" FORCE)
    configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/packaging/macos/Info.plist.in"
        "${CMAKE_CURRENT_BINARY_DIR}/ReClipInfo.plist"
        @ONLY
    )
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

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
if(RECLIP_ENABLE_KIRIGAMI)
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
else()
    message(STATUS "Kirigami disabled by RECLIP_ENABLE_KIRIGAMI=OFF")
endif()

find_package(Qt6 6.8 REQUIRED COMPONENTS Quick QuickControls2)
if(RECLIP_HAS_KIRIGAMI)
    find_package(Qt6 6.8 REQUIRED COMPONENTS Svg Concurrent ShaderTools)
    set(QML_IMPORT_PATH "${RECLIP_KIRIGAMI_QML_DIR}")
endif()

qt_standard_project_setup(REQUIRES 6.8)

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

if(APPLE)
    set_source_files_properties(
        "${CMAKE_CURRENT_SOURCE_DIR}/packaging/macos/ReClip.icns"
        PROPERTIES MACOSX_PACKAGE_LOCATION "Resources"
    )
    target_sources(${RECLIP_APP_TARGET} PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}/packaging/macos/ReClip.icns"
    )
endif()

target_include_directories(${RECLIP_APP_TARGET} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)

set(RECLIP_QML_FILES
    qml/Main.qml
    qml/Theme.qml
    qml/components/ActivityPanel.qml
    qml/components/AppButton.qml
    qml/components/DesktopSidebar.qml
    qml/components/DownloadRow.qml
    qml/components/DownloadStatusPanel.qml
    qml/components/InlineNotice.qml
    qml/components/LinkCapture.qml
    qml/components/MediaPreview.qml
    qml/components/MobileBottomBar.qml
    qml/components/NavigationItem.qml
    qml/components/SignalTrace.qml
    qml/components/StatusPill.qml
    qml/components/ToolStatusCard.qml
    qml/components/ToolStatusRow.qml
    qml/pages/NewDownloadPage.qml
    qml/pages/QueuePage.qml
    qml/pages/SettingsPage.qml
)

if(RECLIP_HAS_KIRIGAMI)
    list(APPEND RECLIP_QML_FILES qml/MainKirigami.qml)
endif()

qt_add_qml_module(${RECLIP_APP_TARGET}
    URI ReClip
    VERSION 1.0
    QML_FILES ${RECLIP_QML_FILES}
    SOURCES
        src/AppController.h
        src/AppController.cpp
        src/ToolLocator.h
        src/ToolLocator.cpp
        src/MediaInspector.h
        src/MediaInspector.cpp
        src/DownloadManager.h
        src/DownloadManager.cpp
        src/DownloadQueue.h
        src/DownloadQueue.cpp
        src/AppSettings.h
        src/AppSettings.cpp
)

set_target_properties(${RECLIP_APP_TARGET} PROPERTIES
    OUTPUT_NAME ReClip
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_BUNDLE_NAME "ReClip"
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.reclip.app"
    MACOSX_BUNDLE_ICON_FILE "ReClip.icns"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
    MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
    WIN32_EXECUTABLE TRUE
)

if(APPLE)
    set_target_properties(${RECLIP_APP_TARGET} PROPERTIES
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_BINARY_DIR}/ReClipInfo.plist"
    )
endif()

target_link_libraries(${RECLIP_APP_TARGET} PRIVATE
    Qt6::Quick
    Qt6::QuickControls2
)

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
    BUNDLE DESTINATION .
)

include(CTest)

if(BUILD_TESTING)
    qt_add_executable(ReClipSmokeTest
        tests/smoke.cpp
    )

    target_link_libraries(ReClipSmokeTest PRIVATE Qt6::Core)
    add_test(NAME ReClipSmokeTest COMMAND ReClipSmokeTest)

    qt_add_executable(ReClipToolLocatorTest
        tests/tool_locator.cpp
        src/ToolLocator.h
        src/ToolLocator.cpp
    )

    target_include_directories(ReClipToolLocatorTest PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
    )
    target_link_libraries(ReClipToolLocatorTest PRIVATE Qt6::Core Qt6::Qml)
    add_test(NAME ReClipToolLocatorTest COMMAND ReClipToolLocatorTest)

    qt_add_executable(ReClipMediaInspectorTest
        tests/media_inspector.cpp
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
        src/DownloadManager.h
        src/DownloadManager.cpp
    )

    target_include_directories(ReClipDownloadManagerTest PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
    )
    target_link_libraries(ReClipDownloadManagerTest PRIVATE Qt6::Core Qt6::Gui Qt6::Qml)
    add_test(NAME ReClipDownloadManagerTest COMMAND ReClipDownloadManagerTest)

    qt_add_executable(ReClipDownloadQueueTest
        tests/download_queue.cpp
        src/DownloadQueue.h
        src/DownloadQueue.cpp
    )

    target_include_directories(ReClipDownloadQueueTest PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
    )
    target_link_libraries(ReClipDownloadQueueTest PRIVATE Qt6::Core Qt6::Gui Qt6::Qml)
    add_test(NAME ReClipDownloadQueueTest COMMAND ReClipDownloadQueueTest)

    qt_add_executable(ReClipAppSettingsTest
        tests/app_settings.cpp
        src/AppSettings.h
        src/AppSettings.cpp
    )

    target_include_directories(ReClipAppSettingsTest PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
    )
    target_link_libraries(ReClipAppSettingsTest PRIVATE Qt6::Core Qt6::Qml)
    add_test(NAME ReClipAppSettingsTest COMMAND ReClipAppSettingsTest)
endif()
