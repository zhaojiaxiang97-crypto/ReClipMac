option(RECLIP_ENABLE_YTDLP_SDK "Embed CPython and yt-dlp (Windows resolver/native single-format downloader)" OFF)
set(RECLIP_PYTHON_ROOT "" CACHE PATH "Pinned CPython development/runtime root (tools directory)")

add_library(ReClipYtDlp STATIC
    src/ytdlp/YtDlpTypes.h
    src/ytdlp/YtDlpService.h
    src/ytdlp/YtDlpService.cpp
)
target_include_directories(ReClipYtDlp PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/src")
target_link_libraries(ReClipYtDlp PUBLIC Qt6::Core)

if(RECLIP_ENABLE_YTDLP_SDK)
    if(NOT WIN32 OR ANDROID OR RECLIP_IOS)
        message(FATAL_ERROR "Desktop yt-dlp embedding currently supports Windows x64 only; Android retains Chaquopy")
    endif()
    file(READ "${CMAKE_CURRENT_SOURCE_DIR}/runtime/python/dependencies.json" _reclip_python_manifest)
    string(JSON _reclip_python_version GET "${_reclip_python_manifest}" python version)
    if(NOT RECLIP_PYTHON_ROOT)
        set(RECLIP_PYTHON_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/.third_party/python/windows-x64/${_reclip_python_version}/tools"
            CACHE PATH "Pinned CPython development/runtime root (tools directory)" FORCE)
    endif()
    if(NOT EXISTS "${RECLIP_PYTHON_ROOT}/include/Python.h" OR
       NOT EXISTS "${RECLIP_PYTHON_ROOT}/Lib/site-packages/yt_dlp/__init__.py")
        message(FATAL_ERROR "Missing pinned Python/yt-dlp. Run scripts/Fetch-PythonRuntime.ps1 or set RECLIP_PYTHON_ROOT")
    endif()
    set(Python3_ROOT_DIR "${RECLIP_PYTHON_ROOT}")
    set(Python3_FIND_REGISTRY NEVER)
    find_package(Python3 ${_reclip_python_version} EXACT REQUIRED COMPONENTS Development.Embed)
    file(REAL_PATH "${RECLIP_PYTHON_ROOT}" _reclip_python_real_root)
    foreach(_reclip_python_include IN LISTS Python3_INCLUDE_DIRS)
        file(REAL_PATH "${_reclip_python_include}" _reclip_python_real_include)
        cmake_path(IS_PREFIX _reclip_python_real_root "${_reclip_python_real_include}" NORMALIZE _reclip_python_in_root)
        if(NOT _reclip_python_in_root)
            message(FATAL_ERROR "Python headers were found outside RECLIP_PYTHON_ROOT")
        endif()
    endforeach()
    target_sources(ReClipYtDlp PRIVATE src/ytdlp/PythonRuntime.h src/ytdlp/PythonRuntime.cpp)
    target_compile_definitions(ReClipYtDlp PUBLIC RECLIP_HAS_YTDLP_SDK=1)
    target_link_libraries(ReClipYtDlp PRIVATE Python3::Python)
    set_source_files_properties(runtime/python/reclip_ytdlp/__init__.py PROPERTIES QT_RESOURCE_ALIAS adapter.py)
    qt_add_resources(ReClipYtDlp reclip_python
        PREFIX "/reclip/python"
        FILES runtime/python/reclip_ytdlp/__init__.py
    )
    message(STATUS "In-process yt-dlp enabled: CPython ${Python3_VERSION} (${RECLIP_PYTHON_ROOT})")
endif()

function(reclip_stage_python_runtime target_name)
    if(NOT RECLIP_ENABLE_YTDLP_SDK)
        return()
    endif()
    add_custom_command(TARGET ${target_name} POST_BUILD
        COMMAND "${CMAKE_COMMAND}" "-DRECLIP_PYTHON_ROOT=${RECLIP_PYTHON_ROOT}"
            "-DRECLIP_PYTHON_DESTINATION=$<TARGET_FILE_DIR:${target_name}>"
            "-DRECLIP_PYTHON_MANIFEST=${CMAKE_CURRENT_SOURCE_DIR}/runtime/python/dependencies.json"
            -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/StagePython.cmake"
        VERBATIM
    )
endfunction()
