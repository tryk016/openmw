#include <AL/al.h>
#include <AL/alc.h>

#ifndef AL_VERSION_1_1
#error "The OpenAL 1.1 API is required"
#endif

int openmwIosOpenALProbe(void)
{
    /*
     * Querying the null-device extension surface exercises OpenAL Soft
     * without requiring an audio endpoint to exist in the simulator. The
     * first real device/context open remains a physical-device gate.
     */
    (void)alcIsExtensionPresent(NULL, "ALC_ENUMERATION_EXT");
    (void)alcGetString(NULL, ALC_DEFAULT_DEVICE_SPECIFIER);
    (void)alcGetError(NULL);
    ALCdevice* device = alcOpenDevice(NULL);
    if (device != NULL)
        (void)alcCloseDevice(device);
    return 0;
}

#ifndef OPENMW_IOS_PROBE_NO_MAIN
int main(void)
{
    return openmwIosOpenALProbe();
}
#endif
