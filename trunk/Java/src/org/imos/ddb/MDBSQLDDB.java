/*
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
 */

package org.imos.ddb;

import java.io.File;
import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.List;

/**
 * In memory representation of the IMOS deployment database using libmdbsql. 
 * This class is a Java interface to the mdbsql_wrapper.c driver, which itself
 * is a simplified inteface to libmdbsql. It provides the ability to query the
 * deployment database (MS Access) on a Unix/Linux platform.
 * 
 * Error handling leaves a bit to be desired, as libmdbsql tends to print 
 * error messages, rather than return error codes. Thus, consider this 
 * an experimental way to use the deployment database.
 * 
 * This class should never be instantiated directly; use the static method
 * org.imos.ddb.DDB.getDDB.
 *   
 * @author Paul McCarthy <paul.mccarthy@csiro.au>
 * 
 * @see http://mdbtools.sourceforge.net/install/book1.htm
 */
public class MDBSQLDDB extends DDB {
  
  /*load the .so file */
  static {
    System.loadLibrary("mdbsql_wrapper");
  }
  
  /**File name of the access DB - set in the constructor.*/
  private String dbFile;
  
  /**
   * Open the given .mdb database. libmdbsql requires that the file has a 
   * suffix of '.mdb'.
   * 
   * @param filename the name of the mdb file to open.
   * 
   * @return 0 on success, non-0 on failure.
   */
  private native int mdbsql_open(String filename);
  
  /**
   * Executes the given SQL query against the database.
   * 
   * @param query the SQL query to execute.
   * 
   * @return 0 on success, non-0 on failure.
   */
  private native int mdbsql_query(String query);
  
  /**
   * Move to the next row of the results of a previously executed SQL query.
   * 
   * @return non-0 if there are more rows, 0 if there are no more rows. 
   */
  private native int mdbsql_fetch();
  
  /**
   * Retrieve the value of the given column from the current row of a 
   * previously executed SQL query.
   *  
   * @param column the name of the column.
   * 
   * @return the value of the given column.
   */
  private native String mdbsql_value(String column);
  
  /**
   * Close the connection to the database.
   * 
   * @return 0 always.
   */
  private native int mdbsql_close();
  
  /**
   * Saves the given file name - ensures that the file exists, is a file, and 
   * has the suffix '.mdb'.
   * 
   * @param dbFile name of the database file.
   * 
   * @throws Exception if the given string is not a file, does not exist, or
   * does not end with '.mdb'.
   */
  protected MDBSQLDDB(String dbFile) throws Exception {
    
    // will throw NullPointer if dbFile == null
    File f = new File(dbFile);
    
    if (!f.exists()) throw new Exception("dbFile does not exist");
    if (!f.isFile()) throw new Exception("dbFile is not a file");
    
    if (!dbFile.endsWith(".mdb")) 
      throw new Exception("dbFile is not an access database file");
    
    this.dbFile = dbFile;
  }
  
  /**
   * Executes the given query, in the form:
   * 
   *   select * from [tableName] where [fieldName] = '[fieldValue]'
   * 
   * The rows are converted into object equivalents of the table, and returned 
   * in a List. If fieldName is null, the where clause is omitted, thus the 
   * entire table is returned.
   * 
   * @param tableName The table to read.
   * 
   * @param fieldName the name of the query field.
   * 
   * @param fieldValue the query field value.
   * 
   * @throws Exception on any error.
   */
  public List executeQuery(
    String tableName, 
    String fieldName, 
    Object fieldValue) 
    throws Exception {
    
    List results = null;

    if (tableName == null) 
      throw new Exception("a tableName must be provided");
    
    Class clazz = Class.forName("org.imos.ddb.schema." + tableName);
   
    
    //build query
    String query = "select * from " + tableName;
    if (fieldName != null) {

      if (fieldValue == null) 
        throw new Exception("a fieldValue must be provided");

      //wrap strings in single quotes
      if (fieldValue instanceof String) fieldValue = "'" + fieldValue + "'";

      query += " where " + fieldName + " = " + fieldValue;
    }

    try {

      //open mdb file
      if (mdbsql_open(dbFile)!= 0) {
        throw new Exception("error opening ddb file: " + dbFile);
      }

      //execute query
      if (mdbsql_query(query) != 0)
        throw new Exception("error executing query: " + query);
      
      results = new ArrayList();
      
      //fetch the results one by one
      while (mdbsql_fetch() != 0) {
        
        //create an instance representing this row
        Object instance = clazz.newInstance();
        results.add(instance);
        
        Field [] fields = clazz.getDeclaredFields();
        
        //set the fields of the instance from the row data
        for (Field f : fields) {
          
          if (f.isSynthetic()) continue;
          
          String s = mdbsql_value(f.getName());
          f.set(instance, createFieldValue(f, s));
        }
      }
    }

    //always attempt to close file, even on error
    finally {mdbsql_close();}
    
    return results;
  }
  
  /**
   * Convert the given String representation of the given field into an 
   * instance of the given field's type.
   * 
   * For example, given the String "123", and a field with a type of Integer,
   * returns an Integer containing the value 123.
   * 
   * @param f the Field which is represented in the String rep.
   * 
   * @param rep the String representation of the field.
   * 
   * @return an instance of the type of the given field.
   * 
   * @throws Exception on any error.
   */
  private Object createFieldValue(Field f, String rep) throws Exception {
    
    Object value = null;
    
    if (rep == null)    return null;
    
    rep = rep.trim();
    if (rep.equals("")) return null;
    
    /*
     * Most object types provide a constructor which converts a String into 
     * an object e.g.
     * 
     *   new Integer("1234");
     *   new Double ("1234.567");
     *   new String ("abcde");
     *   new Date   ("2007-01-01 12:00:00");
     * 
     * This pattern means that we could use reflection to get this constructor
     * and instantiate the object regardless of its type. The only problem with
     * this is the Boolean type which, while it does provide a constructor
     * to convert from a String to a Boolean, only accepts Strings of the form
     * "true" or "false" (case insensitive). 
     * 
     * This is no good to us because libmdbsql stores booleans as "1" and "0". 
     * Thus because of this incompatibility, i'm handling Boolean datatypes 
     * separately. 
     */
    
    //ugly hack for boolean
    if (f.getType().equals(Boolean.class)) {
      
      if (rep.equals("1") || rep.equalsIgnoreCase("true")) value = true;
      else                                                 value = false;
    }
    
    //reflection for everything else
    else {
      
      Constructor ctr = f.getType().getConstructor(String.class);
      value = ctr.newInstance(rep);
    }
    
    return value;
  }
}
