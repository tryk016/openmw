_find_package(${ARGS})

# FFmpeg 7.1.1's Darwin configuration attaches these three frameworks to
# libavutil through its Apple framework checks. OpenMW's FindFFmpeg module
# resolves archive paths but drops pkg-config's private link requirements, so
# restore both a static-safe archive order and the exact framework closure.
if(FFmpeg_FOUND AND APPLE)
    find_library(OPENMW_FFMPEG_COREFOUNDATION_FRAMEWORK CoreFoundation REQUIRED)
    find_library(OPENMW_FFMPEG_COREMEDIA_FRAMEWORK CoreMedia REQUIRED)
    find_library(OPENMW_FFMPEG_COREVIDEO_FRAMEWORK CoreVideo REQUIRED)

    set(FFmpeg_LIBRARIES
        ${FFmpeg_AVFORMAT_LIBRARIES}
        ${FFmpeg_AVCODEC_LIBRARIES}
        ${FFmpeg_SWRESAMPLE_LIBRARIES}
        ${FFmpeg_SWSCALE_LIBRARIES}
        ${FFmpeg_AVUTIL_LIBRARIES}
        ${OPENMW_FFMPEG_COREFOUNDATION_FRAMEWORK}
        ${OPENMW_FFMPEG_COREMEDIA_FRAMEWORK}
        ${OPENMW_FFMPEG_COREVIDEO_FRAMEWORK}
    )
endif()
