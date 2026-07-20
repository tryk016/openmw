#include <stddef.h>
#include <stdio.h>

#include <jpeglib.h>

int main(void)
{
    struct jpeg_decompress_struct decoder = { 0 };
    struct jpeg_error_mgr error = { 0 };
    decoder.err = jpeg_std_error(&error);
    jpeg_create_decompress(&decoder);
    jpeg_destroy_decompress(&decoder);
    return 0;
}
