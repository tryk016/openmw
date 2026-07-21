#include <array>
#include <cstdint>
#include <sstream>
#include <string>
#include <string_view>

#include <SDL.h>

#include <GL/gl.h>

extern "C"
{
#include <gl4es/gl4esinit.h>
}

#include <osg/Geode>
#include <osg/Geometry>
#include <osg/Group>
#include <osg/Vec3>
#include <osg/Version>
#include <osgDB/Options>
#include <osgDB/ReaderWriter>
#include <osgDB/Registry>

// iOS ships no dynamic OSG plugins. These proxies are the production plugin
// registration set and deliberately include both generations of native OSG
// serialization, while omitting DAE and every unused format.
USE_OSGPLUGIN(bmp)
USE_OSGPLUGIN(dds)
USE_OSGPLUGIN(freetype)
USE_OSGPLUGIN(jpeg)
USE_OSGPLUGIN(osg)
USE_OSGPLUGIN(png)
USE_OSGPLUGIN(tga)
USE_DOTOSGWRAPPER_LIBRARY(osg)
USE_SERIALIZER_WRAPPER_LIBRARY(osg)

namespace
{
    SDL_Window* gProbeWindow = nullptr;

    void getDrawableSize(int* width, int* height)
    {
        SDL_GL_GetDrawableSize(gProbeWindow, width, height);
    }

    bool hasReaderWriter(std::string_view extension)
    {
        return osgDB::Registry::instance()->getReaderWriterForExtension(
                   std::string(extension))
            != nullptr;
    }

    int probeOsg()
    {
        if (std::string_view(osgGetVersion()) != "3.6.5")
            return 20;

        for (const std::string_view extension : {
                 "bmp", "dds", "ttf", "jpg", "osg", "osgt", "png", "tga" })
        {
            if (!hasReaderWriter(extension))
                return 21;
        }

        osg::ref_ptr<osg::Vec3Array> vertices = new osg::Vec3Array;
        vertices->push_back(osg::Vec3(-0.75F, -0.75F, 0.0F));
        vertices->push_back(osg::Vec3(0.75F, -0.75F, 0.0F));
        vertices->push_back(osg::Vec3(0.0F, 0.75F, 0.0F));

        osg::ref_ptr<osg::Geometry> geometry = new osg::Geometry;
        geometry->setName("openmw-ios-render-triangle");
        geometry->setVertexArray(vertices);
        geometry->addPrimitiveSet(
            new osg::DrawArrays(GL_TRIANGLES, 0,
                static_cast<GLsizei>(vertices->size())));

        osg::ref_ptr<osg::Geode> geode = new osg::Geode;
        geode->addDrawable(geometry);
        osg::ref_ptr<osg::Group> root = new osg::Group;
        root->setName("openmw-ios-render-foundation");
        root->addChild(geode);

        osgDB::ReaderWriter* modern
            = osgDB::Registry::instance()->getReaderWriterForExtension("osgt");
        osg::ref_ptr<osgDB::Options> asciiOptions
            = new osgDB::Options("Ascii");
        std::ostringstream encoded;
        if (modern == nullptr
            || !modern->writeNode(*root, encoded, asciiOptions.get()).success()
            || encoded.str().find("openmw-ios-render-foundation")
                == std::string::npos)
        {
            return 22;
        }
        std::istringstream input(encoded.str());
        const osgDB::ReaderWriter::ReadResult decoded
            = modern->readNode(input, asciiOptions.get());
        if (!decoded.validNode()
            || decoded.getNode()->getName() != "openmw-ios-render-foundation")
        {
            return 23;
        }

        osgDB::ReaderWriter* legacy
            = osgDB::Registry::instance()->getReaderWriterForExtension("osg");
        std::ostringstream legacyEncoded;
        if (legacy == nullptr
            || !legacy->writeNode(*root, legacyEncoded, nullptr).success()
            || legacyEncoded.str().empty())
        {
            return 24;
        }
        return 0;
    }

    int probeGl4es()
    {
        if (SDL_InitSubSystem(SDL_INIT_VIDEO) != 0)
            return 30;

        SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_ES);
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2);
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);

        gProbeWindow = SDL_CreateWindow("OpenMW iOS render probe",
            SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 64, 64,
            SDL_WINDOW_OPENGL | SDL_WINDOW_SHOWN);
        if (gProbeWindow == nullptr)
        {
            SDL_QuitSubSystem(SDL_INIT_VIDEO);
            return 31;
        }

        SDL_GLContext context = SDL_GL_CreateContext(gProbeWindow);
        if (context == nullptr || SDL_GL_MakeCurrent(gProbeWindow, context) != 0)
        {
            if (context != nullptr)
                SDL_GL_DeleteContext(context);
            SDL_DestroyWindow(gProbeWindow);
            gProbeWindow = nullptr;
            SDL_QuitSubSystem(SDL_INIT_VIDEO);
            return 32;
        }

        set_getprocaddress(SDL_GL_GetProcAddress);
        set_getmainfbsize(getDrawableSize);
        initialize_gl4es();
        for (int pendingError = 0;
             pendingError < 16 && glGetError() != GL_NO_ERROR;
             ++pendingError)
        {
        }

        int width = 0;
        int height = 0;
        SDL_GL_GetDrawableSize(gProbeWindow, &width, &height);
        int result = 0;
        if (width <= 0 || height <= 0 || glGetString(GL_VERSION) == nullptr)
        {
            result = 33;
        }
        else
        {
            glViewport(0, 0, width, height);
            glClearColor(0.0F, 0.0F, 0.0F, 1.0F);
            glClear(GL_COLOR_BUFFER_BIT);
            glMatrixMode(GL_PROJECTION);
            glLoadIdentity();
            glMatrixMode(GL_MODELVIEW);
            glLoadIdentity();
            glBegin(GL_TRIANGLES);
            glColor3f(0.0F, 1.0F, 0.0F);
            glVertex2f(-1.0F, -1.0F);
            glVertex2f(1.0F, -1.0F);
            glVertex2f(0.0F, 1.0F);
            glEnd();
            glFinish();

            std::array<std::uint8_t, 4> centerPixel = {};
            glReadPixels(width / 2, height / 2, 1, 1, GL_RGBA,
                GL_UNSIGNED_BYTE, centerPixel.data());
            const GLenum error = glGetError();
            const bool pixelPassed = centerPixel[1] > 128
                && centerPixel[0] < 64 && centerPixel[2] < 64;
            if (error != GL_NO_ERROR || !pixelPassed)
                result = 34;
        }

        SDL_GL_DeleteContext(context);
        SDL_DestroyWindow(gProbeWindow);
        gProbeWindow = nullptr;
        SDL_QuitSubSystem(SDL_INIT_VIDEO);
        return result;
    }
}

extern "C" int openmwIosRenderProbe()
{
    const int osgResult = probeOsg();
    return osgResult == 0 ? probeGl4es() : osgResult;
}

#ifndef OPENMW_IOS_PROBE_NO_MAIN
int main()
{
    SDL_SetMainReady();
    return openmwIosRenderProbe();
}
#endif
