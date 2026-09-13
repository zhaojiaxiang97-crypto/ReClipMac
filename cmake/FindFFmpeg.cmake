include(FindPackageHandleStandardArgs)

set(_FFMPEG_ROOT_HINTS)
if(RECLIP_FFMPEG_ROOT)
    list(APPEND _FFMPEG_ROOT_HINTS "${RECLIP_FFMPEG_ROOT}")
endif()
if(FFmpeg_ROOT)
    list(APPEND _FFMPEG_ROOT_HINTS "${FFmpeg_ROOT}")
endif()

set(_FFMPEG_RUNTIME_ROOT "${RECLIP_FFMPEG_ROOT}")
if(NOT _FFMPEG_RUNTIME_ROOT AND FFmpeg_ROOT)
    set(_FFMPEG_RUNTIME_ROOT "${FFmpeg_ROOT}")
endif()

find_path(FFmpeg_INCLUDE_DIR
    NAMES libavformat/avformat.h
    HINTS ${_FFMPEG_ROOT_HINTS}
    PATH_SUFFIXES include
)

set(_FFMPEG_COMPONENTS
    avutil
    swresample
    swscale
    avcodec
    avformat
)

foreach(_component IN LISTS _FFMPEG_COMPONENTS)
    find_library(FFmpeg_${_component}_LIBRARY
        NAMES ${_component} lib${_component}
        HINTS ${_FFMPEG_ROOT_HINTS}
        PATH_SUFFIXES lib
    )

    if(WIN32 AND FFmpeg_${_component}_LIBRARY)
        file(GLOB _runtime_candidates LIST_DIRECTORIES FALSE
            "${_FFMPEG_RUNTIME_ROOT}/bin/${_component}.dll"
            "${_FFMPEG_RUNTIME_ROOT}/bin/${_component}-*.dll"
            "${_FFMPEG_RUNTIME_ROOT}/bin/lib${_component}.dll"
            "${_FFMPEG_RUNTIME_ROOT}/bin/lib${_component}-*.dll"
        )
        list(SORT _runtime_candidates)
        if(_runtime_candidates)
            list(GET _runtime_candidates 0 FFmpeg_${_component}_RUNTIME)
        endif()
    endif()
endforeach()

find_package_handle_standard_args(FFmpeg
    REQUIRED_VARS
        FFmpeg_INCLUDE_DIR
        FFmpeg_avutil_LIBRARY
        FFmpeg_swresample_LIBRARY
        FFmpeg_swscale_LIBRARY
        FFmpeg_avcodec_LIBRARY
        FFmpeg_avformat_LIBRARY
)

if(FFmpeg_FOUND)
    foreach(_component IN LISTS _FFMPEG_COMPONENTS)
        if(NOT TARGET FFmpeg::${_component})
            if(WIN32 AND FFmpeg_${_component}_RUNTIME)
                add_library(FFmpeg::${_component} SHARED IMPORTED)
            else()
                add_library(FFmpeg::${_component} UNKNOWN IMPORTED)
            endif()
            set_target_properties(FFmpeg::${_component} PROPERTIES
                INTERFACE_INCLUDE_DIRECTORIES "${FFmpeg_INCLUDE_DIR}"
            )

            if(WIN32 AND FFmpeg_${_component}_RUNTIME)
                set_target_properties(FFmpeg::${_component} PROPERTIES
                    IMPORTED_IMPLIB "${FFmpeg_${_component}_LIBRARY}"
                    IMPORTED_LOCATION "${FFmpeg_${_component}_RUNTIME}"
                )
            else()
                set_target_properties(FFmpeg::${_component} PROPERTIES
                    IMPORTED_LOCATION "${FFmpeg_${_component}_LIBRARY}"
                )
            endif()
        endif()
    endforeach()

    if(NOT TARGET FFmpeg::FFmpeg)
        add_library(FFmpeg::FFmpeg INTERFACE IMPORTED)
        set_target_properties(FFmpeg::FFmpeg PROPERTIES
            INTERFACE_LINK_LIBRARIES
                "FFmpeg::avformat;FFmpeg::avcodec;FFmpeg::swresample;FFmpeg::swscale;FFmpeg::avutil"
        )
    endif()
endif()

mark_as_advanced(
    FFmpeg_INCLUDE_DIR
    FFmpeg_avutil_LIBRARY
    FFmpeg_swresample_LIBRARY
    FFmpeg_swscale_LIBRARY
    FFmpeg_avcodec_LIBRARY
    FFmpeg_avformat_LIBRARY
)
