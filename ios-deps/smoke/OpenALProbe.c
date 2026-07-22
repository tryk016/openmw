#include <AL/al.h>
#include <AL/alc.h>
#include <AL/alext.h>

#ifndef AL_VERSION_1_1
#error "The OpenAL 1.1 API is required"
#endif

int openmwIosOpenALProbe(void)
{
    if (alcIsExtensionPresent(NULL, "ALC_SOFT_loopback") != ALC_TRUE)
        return 1;

    LPALCLOOPBACKOPENDEVICESOFT loopbackOpenDevice
        = (LPALCLOOPBACKOPENDEVICESOFT)alcGetProcAddress(NULL, "alcLoopbackOpenDeviceSOFT");
    if (loopbackOpenDevice == NULL)
        return 2;

    ALCdevice* loopbackDevice = loopbackOpenDevice(NULL);
    if (loopbackDevice == NULL)
        return 3;
    if (alcGetError(loopbackDevice) != ALC_NO_ERROR)
    {
        if (alcCloseDevice(loopbackDevice) != ALC_TRUE)
            return 5;
        return 4;
    }
    if (alcCloseDevice(loopbackDevice) != ALC_TRUE)
        return 5;

    ALCdevice* physicalDevice = alcOpenDevice(NULL);
    if (physicalDevice != NULL && alcCloseDevice(physicalDevice) != ALC_TRUE)
        return 6;

    return 0;
}

#ifndef OPENMW_IOS_PROBE_NO_MAIN
int main(void)
{
    return openmwIosOpenALProbe();
}
#endif
