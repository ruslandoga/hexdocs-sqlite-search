#include <stddef.h>

#include "../deps/exqlite/c_src/sqlite3ext.h"
SQLITE_EXTENSION_INIT1

/*
** Implementation of hexdocs_rank() function.
*/
static void hexdocsRankFunction(
    const Fts5ExtensionApi *pApi, /* API offered by current FTS version */
    Fts5Context *pFts,            /* First arg to pass to pApi functions */
    sqlite3_context *pCtx,        /* Context for returning result/error */
    int nVal,                     /* Number of values in apVal[] array */
    sqlite3_value **apVal         /* Array of trailing arguments */
) {
  ((void)nVal);  /* Unused parameter */
  ((void)apVal); /* Unused parameter */

  int rc;
  int matches;

  rc = pApi->xInstCount(pFts, &matches);
  if (rc != SQLITE_OK) {
    sqlite3_result_error_code(pCtx, rc);
    return;
  }

  for (int i = 0; i < matches; i++) {
    int phrase, col, off;

    rc = pApi->xInst(pFts, i, &phrase, &col, &off);
    if (rc != SQLITE_OK) {
      sqlite3_result_error_code(pCtx, rc);
      return;
    }

    // title=0
    // doc=1

    if (col == 0) {
      sqlite3_result_double(pCtx, 2.0);
      return;
    }
  }

  sqlite3_result_double(pCtx, 1.0);
}

int sqlite3_hexdocs_init(sqlite3 *db, char **pzErrMsg,
                         const sqlite3_api_routines *pApi) {
  int rc;

  SQLITE_EXTENSION_INIT2(pApi);
  (void)pzErrMsg; /* Unused parameter */

  sqlite3_stmt *stmt = NULL;
  rc = pApi->prepare_v2(db, "SELECT fts5(?1)", -1, &stmt, NULL);
  if (rc != SQLITE_OK) return rc;

  fts5_api *fts5Api;
  rc = pApi->bind_pointer(stmt, 1, &fts5Api, "fts5_api_ptr", NULL);

  if (rc != SQLITE_OK) {
    pApi->finalize(stmt);
    return rc;
  }

  pApi->step(stmt);
  rc = pApi->finalize(stmt);

  if (rc != SQLITE_OK) return rc;
  if (!fts5Api || fts5Api->iVersion != 2) return SQLITE_MISUSE;

  return fts5Api->xCreateFunction(
      fts5Api, "hexdocs_rank", /* Function name (nul-terminated) */
      NULL,                    /* User-data pointer */
      hexdocsRankFunction,     /* Callback function */
      NULL                     /* Destructor function */
  );
}
