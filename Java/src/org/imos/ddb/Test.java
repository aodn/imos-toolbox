/*
 * Copyright (C) 2017, Australian Ocean Data Network (AODN) and Integrated 
 * Marine Observing System (IMOS).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation version 3 of the License.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program.
 * If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
 */

package org.imos.ddb;

import java.util.ArrayList;

/**
 * Simple test case for DDB access.
 * 
 * @author Paul McCarthy <paul.mccarthy@csiro.au>
 */
public class Test {

	static void printObj(Object o) throws Exception {

		ArrayList<DBObject> l = (ArrayList<DBObject>) o;

		for (DBObject i : l) {

			if (i.o == null)
				System.out.println(i.name + " = null");
			else
				System.out.println(i.name + " class " + i.o.getClass().getName() + " = " + i.o);
		}
		System.out.println("------");
	}

	/**
	 * @param args
	 */
	public static void main(String[] args) {

		long startFreeMem, connectFreeMem, endFreeMem;
		DDB mdb = null;

//		String odbcArgs = "imos-ddb_bmorris";
//		String odbcArgs = "/home/ggalibert/Documents/IMOS_toolbox/data_files_examples/NSW/OceanDB2015.mdb";
		String odbcArgs = "/home/ggalibert/Documents/IMOS_toolbox/data_files_examples/AIMS/Paul_Rigby/OceanDB.mdb";
//		String odbcArgs = "/home/ggalibert/Documents/IMOS_toolbox/data_files_examples/AIMS/new_ddb/OceanDB_Unreplicated.mdb";

//		String driver = "net.ucanaccess.jdbc.UcanaccessDriver";
		String driver = "org.postgresql.Driver";
		String mdbFile = "/home/ggalibert/Documents/IMOS_toolbox/data_files_examples/NSW/OceanDB2015.mdb";
//		String mdbFile = "/home/ggalibert/Documents/IMOS_toolbox/data_files_examples/AIMS/Paul_Rigby/OceanDB.mdb";
//		String connection = "jdbc:ucanaccess://" + mdbFile + ";jackcessOpener=org.imos.ddb.CryptCodecOpener;SingleConnection=true";
//		String connection = "jdbc:ucanaccess://" + mdbFile + ";jackcessOpener=org.imos.ddb.CryptCodecOpener";
		String connection = "jdbc:postgresql://localhost/Darren_2016-03-24";
		String user = "myUser";
		String password = "myPassword";
		String[] jdbcArgs = new String[4];
		jdbcArgs[0] = driver;
		jdbcArgs[1] = connection;
		jdbcArgs[2] = user;
		jdbcArgs[3] = password;

		long startTime = System.currentTimeMillis();
//		startFreeMem = Runtime.getRuntime().totalMemory();
//		System.out.println("free mem: " + startFreeMem/1000000 + "Mb");
		long usedMem = Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory();
		System.out.println("used mem: " + usedMem/1000000 + "Mb");

		try {
//			mdb = DDB.getDDB(odbcArgs);}
			mdb = DDB.getDDB(jdbcArgs[0], jdbcArgs[1], jdbcArgs[2], jdbcArgs[3]);}
		catch (Exception e) {
			e.printStackTrace();
			System.exit(1);
		}

		long connectTime = System.currentTimeMillis();
		System.out.println("Connection created in " + (connectTime - startTime)/1000 + " seconds.");

//		connectFreeMem = Runtime.getRuntime().totalMemory();
//		System.out.println("free mem: " + connectFreeMem/1000000 + "Mb");
//		System.out.println("lost mem: " + (startFreeMem - connectFreeMem)/1000000 + "Mb");
		usedMem = Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory();
		System.out.println("used mem: " + usedMem/1000000 + "Mb");

		try {

			ArrayList<Object> trips = mdb.executeQuery("FieldTrip", "FieldTripID", "NRSMAI-2015-06-26");
			for (Object o : trips) printObj(o);

//			ArrayList<Object> deps = mdb.executeQuery("DeploymentData", null, null);
//			for (Object o : deps) printObj(o);
//
//			ArrayList<Object> capeSites = mdb.executeQuery("Sites", null, null);
//			for (Object o : capeSites) printObj(o);
//
//			ArrayList<Object> casts = mdb.executeQuery("CTDData", null, null);
//			for (Object o : casts) printObj(o);
//
//			ArrayList<Object> inst = mdb.executeQuery("Instruments", null, null);
//			for (Object o : inst) printObj(o);
//
//			ArrayList<Object> sens = mdb.executeQuery("Sensors", null, null);
//			for (Object o : sens) printObj(o);
//
//			ArrayList<Object> instSens = mdb.executeQuery("InstrumentSensorConfig", null, null);
//			for (Object o : instSens) printObj(o);
		}
		catch (Exception e) {e.printStackTrace();}

		long stopTime = System.currentTimeMillis();
		System.out.println("Query performed in " + (stopTime - connectTime)/1000 + " seconds.");

//		endFreeMem = Runtime.getRuntime().totalMemory();
//		System.out.println("free mem: " + endFreeMem/1000000 + "Mb");
//		System.out.println("lost mem: " + (connectFreeMem - endFreeMem)/1000000 + "Mb");
		usedMem = Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory();
		System.out.println("used mem: " + usedMem/1000000 + "Mb");
	}
}
