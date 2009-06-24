/**
 * Copyright (c) 2009, eMarine Information Infrastructure (eMII) and Integrated 
 * Marine Observing System (IMOS).
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without 
 * modification, are permitted provided that the following conditions are met:
 * 
 *     * Redistributions of source code must retain the above copyright notice, 
 *       this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright 
 *       notice, this list of conditions and the following disclaimer in the 
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the eMII/IMOS nor the names of its contributors 
 *       may be used to endorse or promote products derived from this software 
 *       without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
 * POSSIBILITY OF SUCH DAMAGE.
 *
 *
 *
 * This driver provides basic read only access to Microsoft Access (JET3/JET4) 
 * databases. Built on top of mdbtools. Requires mdbtools version 0.6pre1.
 * 
 * Typical usage is as follows (you should check return values of course :/ ):
 * 
 *   mdbsql_open("./myaccessdb.mdb");
 *   
 *   mdbsql_query("select * from table1");
 *   
 *   while (mdbsql_fetch()) {
 *    
 *     printf("col1 value: %s\n", mdbsql_value("col1"));
 *     printf("col2 value: %s\n", mdbsql_value("col2"));
 *     printf("col3 value: %s\n", mdbsql_value("col3"));
 *   }
 *   
 *   mdbsql_close();
 * 
 * \author Paul McCarthy <paul.mccarthy@csiro.au>.
 */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include <glib.h>
#include <mdbsql.h>

/*****************************
 * private function prototypes
 ****************************/

static int    mdbsql_open( char *filename);
static int    mdbsql_query(char *query);
static int    mdbsql_fetch();
static char * mdbsql_value(char *column);
static int    mdbsql_close();

/*provided by mdbsql*/
extern int yyparse(void);

/***********************
 * JNI wrapper functions
 **********************/

#include <jni.h>
#include "mdbsql_wrapper.h"

JNIEXPORT jint JNICALL 
Java_org_imos_ddb_MDBSQLDDB_mdbsql_1open(
  JNIEnv *env, 
  jobject obj, 
  jstring jfile
)
{
  char *file;
  int result;
  
  file = (char *)(*env)->GetStringUTFChars(env, jfile, NULL);
  
  result = mdbsql_open(file);
  
  (*env)->ReleaseStringUTFChars(env, jfile, file);
  return result;
}

JNIEXPORT jint JNICALL 
Java_org_imos_ddb_MDBSQLDDB_mdbsql_1query(
  JNIEnv *env, 
  jobject obj, 
  jstring jquery
)
{
  char *query;
  int result;
  
  query = (char *)(*env)->GetStringUTFChars(env, jquery, NULL);
  
  result = mdbsql_query(query);

  (*env)->ReleaseStringUTFChars(env, jquery, query);
  
  return result;
}


JNIEXPORT jint JNICALL 
Java_org_imos_ddb_MDBSQLDDB_mdbsql_1fetch(
  JNIEnv *env, 
  jobject obj
)
{
  return mdbsql_fetch();
}

JNIEXPORT jstring JNICALL 
Java_org_imos_ddb_MDBSQLDDB_mdbsql_1value(
  JNIEnv *env, 
  jobject obj, 
  jstring jcolumn
)
{
  char *column;
  char *value;
  
  column = (char *)(*env)->GetStringUTFChars(env, jcolumn, NULL);
  
  value = mdbsql_value(column);
  
  (*env)->ReleaseStringUTFChars(env, jcolumn, column);
  
  return (*env)->NewStringUTF(env, value);
}

JNIEXPORT jint JNICALL 
Java_org_imos_ddb_MDBSQLDDB_mdbsql_1close(
  JNIEnv *env, 
  jobject obj
)
{
  return mdbsql_close();
}


/***********************
 * actual implementation
 **********************/

/**MdbSQL handle.*/
static MdbSQL *sql;

/**
 * Opens the given access database.
 * 
 * \return zero on success, non-zero on failure.
 */
static int 
mdbsql_open(
  char *filename /**< filename of ms access database */
)
{
  /*busy*/
  if (sql != NULL) return 1;
  
  /*open the mdb file*/
  sql = mdb_sql_init();
  
  if (mdb_sql_open(sql, (char *)filename) == NULL) {
    
    mdbsql_close();
    return 1;
  }
  
  return 0;
}

/**
 * Executes the given SQL query on a previously opened access database.
 * 
 * \return zero on success, non-zero on failure..
 */
static int 
mdbsql_query(
  char *query /**< the query to execute */
)
{ 
  /*no database open*/
  if (sql == NULL) return 1;
  
  /*execute query*/
  g_input_ptr = query;
  _mdb_sql(sql);
  if (yyparse()) {
    
    mdb_sql_reset(sql);
    return 1;
  }
  
  if (sql->cur_table == NULL) return 1;
  
  mdb_sql_bind_all(sql);
  
  return 0;
}

/**
 * Moves to the next row of a previously executed query.
 * 
 * \return non-zero if there is another row to read, zero if there are no 
 * more rows.
 */
static int 
mdbsql_fetch()
{
  int result;
  
  if (sql == NULL) return 1;
  
  result = mdb_fetch_row(sql->cur_table);
  
  if (result == 0) mdb_sql_reset(sql);
  
  return result;
}

/**
 * Returns the value of the given field from the current row of a previously
 * executed query.
 * 
 * \return pointer to a char * containing the value, NULL on failure.
 */
static char *
mdbsql_value(
  char *column /**< name of column */
)
{
  MdbSQLColumn *sqlcol;
  char *val = NULL;
  int i;
  
  if (sql == NULL)    return NULL;
  if (column == NULL) return NULL;
  
  for (i = 0; i < sql->num_columns; i++) {
    
    sqlcol = g_ptr_array_index(sql->columns, i);
    
    if (!strcmp(sqlcol->name, column)) {
    
      val = sql->bound_values[i];
      break;
    }
  }
  
  return val;
}


/**
 * Closes a previously opened database. Fails silently if no database was open. 
 * 
 * \return 0.
 */
static int 
mdbsql_close() 
{
  /*fail silently if not currently open*/
  if (sql != NULL) {

    mdb_sql_exit(sql);
    sql = NULL;
  }
  return 0;
}

