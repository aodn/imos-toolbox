/*
 * Copyright (c) 2016, Australian Ocean Data Network (AODN) and Integrated 
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
 *     * Neither the name of the AODN/IMOS nor the names of its contributors 
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

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.DatabaseMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;

/**
 * In memory representation of the IMOS deployment database using JDBC. 
 * This class uses a generic JDBC driver and connection string so is
 * database agnostic, allowing the deployment database to be hosted on any
 * JDBC supported database platform.
 * 
 * This class should never be instantiated directly; use the static method
 * org.imos.ddb.DDB.getDDB.
 * 
 * @author Gordon Keith <gordon.keith@csiro.au>
 * @author Peter Jansen <peter.jansen@csiro.au> - generic database schema changes
 * 
 * @see http://java.sun.com/javase/6/docs/technotes/guides/jdbc/bridge.html
 */
public class JDBCDDB extends DDB {

	String identQuote = "'";
	
	/**The JDBC database driver*/
	private String driver;
	private String connection;
	private String user;
	private String password;

	/**
	 * Create a JDBC DDB object using the specified JDBC driver and database connection. 
	 * 
	 * @param driver Class name of JDBC database driver
	 * @param connection Database connection string, must include user and password if required by the database.
	 * @throws ClassNotFoundException If the specified Database driver can't be found
	 * @throws SQLException If an attempt to open a connection to the database fails
	 */
	protected JDBCDDB(String driver, String connection, String user, String password) throws ClassNotFoundException, SQLException {
		this.driver = driver;
		this.connection = connection;
		this.user = user;
		this.password = password;

		// Test connection - throws exception at creation if can't connect
		Class.forName(driver);

		Connection conn = DriverManager.getConnection(connection, user, password);
		
		// get the database's IdentifierQuote
		DatabaseMetaData dbmd = conn.getMetaData();
		identQuote = dbmd.getIdentifierQuoteString();
		
		conn.close();
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
	public ArrayList<Object> executeQuery(
			String tableName,  
			String fieldName, 
			Object fieldValue)
					throws Exception {

		Connection conn = null;
		ArrayList<Object> results = null;

		try {

			//create ODBC database connection
			Class.forName(driver);

			conn = DriverManager.getConnection(connection, user, password);

			results = new ArrayList<Object>();

			//build the query
			String query = "SELECT * FROM " + identQuote + tableName + identQuote;
			if (fieldName != null) {

				if (fieldValue == null)
					throw new Exception("a fieldValue must be provided");

				//wrap strings in quotes
				if (fieldValue instanceof String) 
					query += " WHERE " + identQuote + fieldName + identQuote + " = '" + fieldValue + "'";
				else
					query += " WHERE " + identQuote + fieldName + identQuote + " = " + fieldValue;
			}

			//execute the query
			Statement stmt = null;
			ResultSet rs = null;
			try {
				stmt = conn.createStatement();
				rs = stmt.executeQuery(query);
			}
			catch (Exception e) {

				System.out.println("JDBCDDB::Exception Caught " + e);

				//Hack to accommodate DeploymentId and FieldTripID
				//types of number or text. Don't tell anyone
				if (fieldName != null && fieldValue instanceof String) {

					query = "SELECT * FROM " + identQuote + tableName + identQuote + 
							" WHERE " + identQuote + fieldName + identQuote + " = " + fieldValue;

					System.out.println("JDBCDDB::Query : " + query);

					stmt = conn.createStatement();
					rs = stmt.executeQuery(query);
				}
				else throw e;
			}

			ResultSetMetaData rsmd = rs.getMetaData();
			int columnsNumber = rsmd.getColumnCount();
			//create an object for each row
			while (rs.next()) {

				ArrayList<Object> instance = new ArrayList<Object>();
				results.add(instance);

				for (int i = 1; i <= columnsNumber; i++) {

					DBObject db = new DBObject();

					db.name = rsmd.getColumnName(i);
					db.o = rs.getObject(i);

					//all numeric values must be doubles
					if (db.o instanceof Integer) {
						db.o = (double)((Integer)db.o).intValue();
					}

					instance.add(db);
				}
			}
		}

		//always close db connection
		finally {try {conn.close();} catch (Exception e) {}}

		return results;
	}
}
