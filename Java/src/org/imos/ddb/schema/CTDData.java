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

package org.imos.ddb.schema;

import java.util.Date;

public class CTDData
{

	public String FieldTrip;
	public Double Latitude;
	public Double Longitude;
	public String Site;
	public String Station;
	public String InstrumentID;
	public String FileName;
	public Boolean Niskin;
	public Boolean Chlorophyll;
	public Double DepthNiskin01;
	public String DepthDatumNiskin01;
	public Double DepthNiskin02;
	public String DepthDatumNiskin02;
	public Double DepthNiskin03;
	public String DepthDatumNiskin03;
	public Double DepthNiskin04;
	public String DepthDatumNiskin04;
	public Double DepthNiskin05;
	public String DepthDatumNiskin05;
	public Date DateFirstInPos;
	public Date TimeFirstInPos;
	public Date DateLastInPos;
	public Date TimeLastInPos;
	public String TimeZone;
	public String InstrumentDepth;
	public String InstrumentDepthDatum;
	public String SiteDepth;
	public String SiteDepthDatum;
	public String LinkFile1;
	public String LinkFile2;
	public String Comment;
	public String ResearchActivity;
	public Date DateModified;
	public Date TimeModified;
	public String ModifiedBy;
}
