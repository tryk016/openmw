#include <sqlite3.h>
#include <string.h>

#if SQLITE_VERSION_NUMBER != 3051002
#    error "The SQLite probe must compile against SQLite 3.51.2"
#endif

#ifndef SQLITE_OMIT_LOAD_EXTENSION
#    error "Runtime extension loading must be omitted"
#endif

#ifdef SQLITE_OMIT_JSON
#    error "SQLite JSON support must remain enabled"
#endif

_Static_assert(sizeof(sqlite3_int64) == 8, "SQLite needs a 64-bit integer ABI");

static int closeWithResult(sqlite3* database, int result)
{
    return sqlite3_close(database) == SQLITE_OK ? result : 1;
}

int openmwIosSQLiteProbe(void)
{
    if (strcmp(sqlite3_libversion(), SQLITE_VERSION) != 0
        || sqlite3_libversion_number() != SQLITE_VERSION_NUMBER
        || strcmp(sqlite3_sourceid(), SQLITE_SOURCE_ID) != 0
        || sqlite3_threadsafe() != 1
        || sqlite3_compileoption_used("THREADSAFE=1") == 0
        || sqlite3_compileoption_used("OMIT_LOAD_EXTENSION") == 0)
    {
        return 1;
    }

    sqlite3* database = 0;
    if (sqlite3_open_v2(
            ":memory:",
            &database,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX,
            0)
        != SQLITE_OK)
    {
        if (database != 0)
            sqlite3_close(database);
        return 1;
    }

    if (sqlite3_exec(
            database,
            "CREATE TABLE sample(value TEXT);"
            "INSERT INTO sample VALUES('{\"value\":42}');",
            0,
            0,
            0)
        != SQLITE_OK)
    {
        return closeWithResult(database, 1);
    }

    sqlite3_stmt* statement = 0;
    if (sqlite3_prepare_v2(
            database,
            "SELECT json_extract(value, '$.value') FROM sample;",
            -1,
            &statement,
            0)
        != SQLITE_OK)
    {
        return closeWithResult(database, 1);
    }

    const int valid = sqlite3_step(statement) == SQLITE_ROW
        && sqlite3_column_int(statement, 0) == 42
        && sqlite3_step(statement) == SQLITE_DONE;
    const int finalizeResult = sqlite3_finalize(statement);
    return closeWithResult(
        database,
        valid && finalizeResult == SQLITE_OK ? 0 : 1);
}

#ifndef OPENMW_IOS_PROBE_NO_MAIN
int main(void)
{
    return openmwIosSQLiteProbe();
}
#endif
