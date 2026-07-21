#include <MyGUI.h>

#include <sstream>
#include <string>
#include <type_traits>

#ifndef MYGUI_STATIC
#error "MyGUI consumers must use the static ABI"
#endif
#ifndef MYGUI_USE_FREETYPE
#error "MyGUI consumers must use the FreeType-enabled ABI"
#endif
#ifndef MYGUI_DONT_USE_OBSOLETE
#error "MyGUI consumers must use the non-obsolete API surface"
#endif

static_assert(MYGUI_VERSION_MAJOR == 3);
static_assert(MYGUI_VERSION_MINOR == 4);
static_assert(MYGUI_VERSION_PATCH == 3);
static_assert(std::is_same_v<MyGUI::UString::unicode_char, char32_t>);
static_assert(std::is_same_v<MyGUI::UString::code_point, char16_t>);

extern "C" int openmwIosMyGuiProbe()
{
    const std::string utf8 = "OpenMW iOS \xE2\x9C\x93 \xF0\x9F\x8E\xAE";
    const MyGUI::UString text(utf8);
    if (text.asUTF8() != utf8 || text.size() != 15
        || text.length_Characters() != 14)
        return 1;

    const MyGUI::Version version = MyGUI::Version::parse("3.4.3");
    if (version.getMajor() != 3 || version.getMinor() != 4
        || version.getPatch() != 3 || version.print() != "3.4.3")
    {
        return 2;
    }

    MyGUI::xml::Document document;
    if (document.createDeclaration() == nullptr)
        return 3;
    MyGUI::xml::ElementPtr root = document.createRoot("OpenMW");
    if (root == nullptr)
        return 4;
    root->addAttribute("profile", "ui-foundation");
    MyGUI::xml::ElementPtr widget = root->createChild("Widget", "ready");
    if (widget == nullptr)
        return 5;
    widget->addAttribute("engine", version.print());

    std::ostringstream encoded;
    if (!document.save(encoded))
        return 6;

    MyGUI::xml::Document decoded;
    std::istringstream input(encoded.str());
    if (!decoded.open(input) || decoded.getRoot() == nullptr)
        return 7;

    MyGUI::xml::ElementPtr decodedRoot = decoded.getRoot();
    if (decodedRoot->getName() != "OpenMW"
        || decodedRoot->findAttribute("profile") != "ui-foundation")
    {
        return 8;
    }

    MyGUI::xml::ElementEnumerator children
        = decodedRoot->getElementEnumerator();
    if (!children.next("Widget") || children.current() == nullptr)
        return 9;
    if (children->getContent() != "ready"
        || children->findAttribute("engine") != "3.4.3")
    {
        return 10;
    }
    if (children.next())
        return 11;

    return 0;
}

#ifndef OPENMW_IOS_PROBE_NO_MAIN
int main()
{
    return openmwIosMyGuiProbe();
}
#endif
