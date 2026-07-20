#include <turbojpeg.h>

int main(void)
{
    tjhandle decoder = tj3Init(TJINIT_DECOMPRESS);
    if (decoder == 0)
        return 1;
    tj3Destroy(decoder);
    return 0;
}
