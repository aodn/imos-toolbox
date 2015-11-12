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

import java.lang.reflect.Field;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;

/**
 * In memory representation of the IMOS deployment database using JDBC. This
 * class uses a generic JDBC driver and connection string so is database
 * agnostic, allowing the deployment database to be hosted on any JDBC supported
 * database platform.
 * 
 * This class should never be instantiated directly; use the static method
 * org.imos.ddb.DDB.getDDB.
 * 
 * @author Gordon Keith <gordon.keith@csiro.au>
 * 
 * @see http://java.sun.com/javase/6/docs/technotes/guides/jdbc/bridge.html
 */
public class JDBCDDB1 extends DDB
{
	/** The JDBC database driver */
	private String driver;
	private String connection;
	private String user;
	private String password;

	/**
	 * Create a JDBC DDB object using the specified JDBC driver and database
	 * connection.
	 * 
	 * @param driver
	 *            Class name of JDBC database driver
	 * @param connection
	 *            Database connection string, must include user and password if
	 *            required by the database.
	 * @throws ClassNotFoundException
	 *             If the specified Database driver can't be found
	 * @throws SQLException
	 *             If an attempt to open a connection to the database fails
	 */
	protected JDBCDDB1(String driver, String connection, String user, String password) throws ClassNotFoundException, SQLException
	{
		this.driver = driver;
		this.connection = connection;
		this.user = user;
		this.password = password;

		// Test connection - throws exception at creation if can't connect
		Class.forName(driver);

		Connection conn = DriverManager.getConnection(connection, user, password);
		conn.close();
	}

	/**
	 * Executes the given query, in the form:
	 * 
	 * select * from [tableName] where [fieldName] = '[fieldValue]'
	 * 
	 * The rows are converted into object equivalents of the table, and returned
	 * in a List. If fieldName is null, the where clause is omitted, thus the
	 * entire table is returned.
	 * 
	 * @param tableName
	 *            The table to read.
	 * 
	 * @param fieldName
	 *            the name of the query field.
	 * 
	 * @param fieldValue
	 *            the query field value.
	 * 
	 * @throws Exception
	 *             on any error.
	 */
	public List<Object> executeQuery(String tableName, String fieldName, Object fieldValue) throws Exception
	{

		Connection conn = null;
		List<Object> results = null;

		// type of object to return
		Class clazz = Class.forName("org.imos.ddb.schema." + tableName);

		try
		{

			// create ODBC database connection
			Class.forName(driver);

			conn = DriverManager.getConnection(connection, user, password);

			results = new ArrayList<Object>();

			// build the query
			String query = "SELECT * FROM " + tableName;
			if (fieldName != null)
			{

				if (fieldValue == null)
					throw new Exception("a fieldValue must be provided");

				// wrap strings in quotes
				if (fieldValue instanceof String)
					query += " WHERE \"" + fieldName + "\" = '" + fieldValue + "'";
				else
					query += " WHERE \"" + fieldName + "\" = " + fieldValue;
			}

			// execute the query
			Statement stmt = null;
			ResultSet rs = null;
			try
			{
				System.out.println("JDBCDDB1::Query : " + query);

				stmt = conn.createStatement();
				rs = stmt.executeQuery(query);
			}
			catch (Exception e)
			{

				// Hack to accommodate DeploymentId and FieldTripID
				// types of number or text. Don't tell anyone
				if (fieldName != null && fieldValue instanceof String)
				{

					query = "SELECT * FROM " + tableName + " WHERE \"" + fieldName + "\" = " + fieldValue;

					System.out.println("JDBCDDB1::Query (2) : " + query);

					stmt = conn.createStatement();
					rs = stmt.executeQuery(query);
				}
				else
					throw e;
			}

			// create an object for each row
			while (rs.next())
			{

				Object instance = clazz.newInstance();
				results.add(instance);

				Field[] fields = clazz.getDeclaredFields();

				// set the fields of the object from the row data
				for (Field f : fields)
				{

					if (f.isSynthetic())
						continue;

					Object o = rs.getObject(f.getName());

					// all numeric values must be doubles
					if (o instanceof Integer)
					{
						o = (double) ((Integer) o).intValue();

						// Hack to accommodate DeploymentId and FieldTripID
						// types of number or text. Don't tell anyone
						if (f.getType() == String.class)
							o = o.toString();
					}

					f.set(instance, o);
				}
			}
		}

		// always close db connection
		finally
		{
			try
			{
				conn.close();
			}
			catch (Exception e)
			{
			}
		}

		return results;
	}
}
