#if __has_include(<sqlite3.h>)
#include <sqlite3.h>
#else
/* Minimal declarations for the system SQLite ABI, for Linux core tests. */
typedef struct sqlite3 sqlite3;
typedef struct sqlite3_stmt sqlite3_stmt;
typedef void (*sqlite3_destructor_type)(void *);
int sqlite3_open(const char *, sqlite3 **);
int sqlite3_close(sqlite3 *);
const char *sqlite3_errmsg(sqlite3 *);
int sqlite3_exec(sqlite3 *,const char *,int(*)(void *,int,char **,char **),void *,char **);
void sqlite3_free(void *);
int sqlite3_prepare_v2(sqlite3 *,const char *,int,sqlite3_stmt **,const char **);
int sqlite3_finalize(sqlite3_stmt *);
int sqlite3_step(sqlite3_stmt *);
int sqlite3_bind_text(sqlite3_stmt *,int,const char *,int,sqlite3_destructor_type);
const unsigned char *sqlite3_column_text(sqlite3_stmt *,int);
#define SQLITE_OK 0
#define SQLITE_ROW 100
#define SQLITE_DONE 101
#endif
