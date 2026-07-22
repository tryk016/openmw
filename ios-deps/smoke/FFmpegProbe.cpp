#include <array>
#include <cstring>

extern "C"
{
#include <libavcodec/avcodec.h>
#include <libavcodec/bsf.h>
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
#include <libswresample/swresample.h>
#include <libswscale/swscale.h>
}

#if LIBAVCODEC_VERSION_MAJOR != 61
#error "The multimedia foundation requires libavcodec 61 from FFmpeg 7.1.1"
#endif
#if LIBAVFORMAT_VERSION_MAJOR != 61
#error "The multimedia foundation requires libavformat 61 from FFmpeg 7.1.1"
#endif
#if LIBAVUTIL_VERSION_MAJOR != 59
#error "The multimedia foundation requires libavutil 59 from FFmpeg 7.1.1"
#endif
#if LIBSWRESAMPLE_VERSION_MAJOR != 5
#error "The multimedia foundation requires libswresample 5 from FFmpeg 7.1.1"
#endif
#if LIBSWSCALE_VERSION_MAJOR != 8
#error "The multimedia foundation requires libswscale 8 from FFmpeg 7.1.1"
#endif

namespace
{
bool hasRequiredDecoders()
{
    constexpr std::array required = {
        AV_CODEC_ID_BINKVIDEO,
        AV_CODEC_ID_BINKAUDIO_DCT,
        AV_CODEC_ID_BINKAUDIO_RDFT,
        AV_CODEC_ID_MP3,
        AV_CODEC_ID_PCM_S16LE,
        AV_CODEC_ID_PCM_U8,
        AV_CODEC_ID_VORBIS,
        AV_CODEC_ID_OPUS,
        AV_CODEC_ID_VP8,
        AV_CODEC_ID_VP9,
    };
    for (const AVCodecID id : required)
    {
        if (avcodec_find_decoder(id) == nullptr)
            return false;
    }
    return true;
}

bool hasRequiredDemuxers()
{
    constexpr std::array required = { "bink", "matroska", "mp3", "ogg", "wav" };
    for (const char* name : required)
    {
        if (av_find_input_format(name) == nullptr)
            return false;
    }
    return true;
}
}

extern "C" int openmwIosFFmpegProbe()
{
    if (std::strncmp(av_version_info(), "7.1.1", 5) != 0)
        return 1;
    if (AV_VERSION_MAJOR(avcodec_version()) != LIBAVCODEC_VERSION_MAJOR
        || AV_VERSION_MAJOR(avformat_version()) != LIBAVFORMAT_VERSION_MAJOR
        || AV_VERSION_MAJOR(avutil_version()) != LIBAVUTIL_VERSION_MAJOR
        || AV_VERSION_MAJOR(swresample_version()) != LIBSWRESAMPLE_VERSION_MAJOR
        || AV_VERSION_MAJOR(swscale_version()) != LIBSWSCALE_VERSION_MAJOR)
        return 2;
    if (!hasRequiredDecoders())
        return 3;
    if (!hasRequiredDemuxers())
        return 4;

    AVCodecParserContext* mp3Parser = av_parser_init(AV_CODEC_ID_MP3);
    AVCodecParserContext* vp9Parser = av_parser_init(AV_CODEC_ID_VP9);
    const bool parsersPassed = mp3Parser != nullptr && vp9Parser != nullptr;
    if (mp3Parser != nullptr)
        av_parser_close(mp3Parser);
    if (vp9Parser != nullptr)
        av_parser_close(vp9Parser);
    if (!parsersPassed)
        return 5;
    if (av_bsf_get_by_name("vp9_superframe_split") == nullptr)
        return 6;

    /* Representative forbidden codecs/formats prove the allowlist stayed narrow. */
    if (avcodec_find_decoder(AV_CODEC_ID_H264) != nullptr
        || avcodec_find_decoder(AV_CODEC_ID_AAC) != nullptr
        || avcodec_find_encoder(AV_CODEC_ID_VP9) != nullptr
        || av_find_input_format("mov") != nullptr
        || av_find_input_format("mpegts") != nullptr)
        return 7;

    void* inputProtocols = nullptr;
    void* outputProtocols = nullptr;
    if (avio_enum_protocols(&inputProtocols, 0) != nullptr
        || avio_enum_protocols(&outputProtocols, 1) != nullptr)
        return 8;
    return 0;
}

#ifndef OPENMW_IOS_PROBE_NO_MAIN
int main()
{
    return openmwIosFFmpegProbe();
}
#endif
