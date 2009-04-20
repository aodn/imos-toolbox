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
import java.util.List;

import org.imos.ddb.schema.DeploymentData;
import org.imos.ddb.schema.Personnel;
import org.imos.ddb.schema.Sensors;
import org.imos.ddb.schema.Sites;

/**
 * Simple test case for DDB access.
 * 
 * @author Paul McCarthy <paul.mccarthy@csiro.au>
 */
public class Test {
  
  static void printObj(Object o) throws Exception {
    
    Field []fields = o.getClass().getDeclaredFields();
    
    for (Field f : fields) {
      
      if (f.isSynthetic()) continue;
      
      System.out.println(f.getName() + ": " + f.get(o));
    }
    System.out.println("------");
  }

  /**
   * @param args
   */
  public static void main(String[] args) {

    long startFreeMem, endFreeMem;
    DDB mdb = null;
    
    try {mdb = DDB.getDDB(args[0]);}
    catch (Exception e) {
      e.printStackTrace();
      System.exit(1);
    }
    
    startFreeMem = Runtime.getRuntime().freeMemory();
    
    try {

      List<DeploymentData> deps = mdb.executeQuery("DeploymentData", null, null);
      for (DeploymentData d : deps) printObj(d);
      
      List<Personnel> people = mdb.executeQuery("Personnel", null, null);
      for (Personnel p : people) printObj(p);
      
      List<Sensors> seabirds = mdb.executeQuery("Sensors", "Make", "SEABIRD");
      for (Sensors s : seabirds) printObj(s);
      
      
      List<Sites> capeSites = mdb.executeQuery("Sites", "ResearchActivity", "NW Cape 2002");
      for (Sites s : capeSites) printObj(s);
    }
    catch (Exception e) {e.printStackTrace();}
    
    endFreeMem = Runtime.getRuntime().freeMemory();
    
    System.out.println("free mem at start: " + startFreeMem);
    System.out.println("free mem at end:   " + endFreeMem);
    System.out.println("lost mem:          " + (startFreeMem - endFreeMem));
  }
}
