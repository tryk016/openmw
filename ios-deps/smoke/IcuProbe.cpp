#include <string>

#include <unicode/fmtable.h>
#include <unicode/msgfmt.h>
#include <unicode/numberformatter.h>
#include <unicode/plurrule.h>
#include <unicode/putil.h>
#include <unicode/uclean.h>
#include <unicode/unistr.h>
#include <unicode/uversion.h>

#if U_ICU_VERSION_MAJOR_NUM != 70 || U_ICU_VERSION_MINOR_NUM != 1
#error "The iOS language foundation requires ICU 70.1"
#endif

namespace
{
    bool selectedPlural(const char* localeName, double value,
        const char* expected)
    {
        UErrorCode status = U_ZERO_ERROR;
        icu::PluralRules* rules = icu::PluralRules::forLocale(
            icu::Locale(localeName), status);
        if (U_FAILURE(status) || rules == nullptr)
        {
            delete rules;
            return false;
        }
        const icu::UnicodeString selected = rules->select(value);
        delete rules;
        std::string utf8;
        selected.toUTF8String(utf8);
        return utf8 == expected;
    }

    int runIcuChecks()
    {
        const std::string source = "Zażółć gęślą — OpenMW";
        const icu::UnicodeString unicode
            = icu::UnicodeString::fromUTF8(source);
        std::string roundTrip;
        unicode.toUTF8String(roundTrip);
        if (roundTrip != source)
            return 2;

        UErrorCode status = U_ZERO_ERROR;
        icu::MessageFormat message(
            icu::UnicodeString::fromUTF8("Hello, {0}!"),
            icu::Locale::getEnglish(), status);
        icu::Formattable argument(
            icu::UnicodeString::fromUTF8("OpenMW"));
        icu::UnicodeString formattedMessage;
        icu::FieldPosition fieldPosition(0);
        message.format(&argument, 1, formattedMessage, fieldPosition, status);
        std::string messageUtf8;
        formattedMessage.toUTF8String(messageUtf8);
        if (U_FAILURE(status) || messageUtf8 != "Hello, OpenMW!")
            return 3;

        if (!selectedPlural("en", 1, "one"))
            return 4;
        if (!selectedPlural("pl", 2, "few"))
            return 5;
        if (!selectedPlural("ru", 5, "many"))
            return 6;

        status = U_ZERO_ERROR;
        const icu::number::UnlocalizedNumberFormatter numberTemplate
            = icu::number::NumberFormatter::forSkeleton(
                icu::UnicodeString::fromUTF8(".00 group-off"), status);
        if (U_FAILURE(status))
            return 7;
        const icu::UnicodeString formattedNumber = numberTemplate
            .locale(icu::Locale::getEnglish())
            .formatDouble(1234.5, status)
            .toString(status);
        if (U_FAILURE(status))
            return 8;
        std::string numberUtf8;
        formattedNumber.toUTF8String(numberUtf8);
        if (numberUtf8 != "1234.50")
            return 9;

        return 0;
    }
}

extern "C" int openmwIosIcuProbe()
{
    UErrorCode status = U_ZERO_ERROR;
    u_init(&status);
    if (U_FAILURE(status))
        return 1;

    const int result = runIcuChecks();
    u_cleanup();
    return result;
}

#ifndef OPENMW_IOS_PROBE_NO_MAIN
int main()
{
    return openmwIosIcuProbe();
}
#endif
