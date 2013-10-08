function sample_data = salinityPP( sample_data, auto )
%SALINITYPP Adds a salinity variable to the given data sets, if they
% contain conductivity, temperature and pressure variables. 
%
% This function uses the Gibbs-SeaWater toolbox (TEOS-10) to derive salinity
% data from conductivity, temperature and pressure. It adds the salinity 
% data as a new variable in the data sets. Data sets which do not contain 
% conductivity, temperature and pressure variable are left unmodified.
%
% Inputs:
%   sample_data - cell array of data sets, ideally with conductivity, 
%                 temperature and pressure variables.
%   auto - logical, run pre-processing in batch mode
%
% Outputs:
%   sample_data - the same data sets, with salinity variables added.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
%

%
% Copyright (c) 2009, eMarine Information Infrastructure (eMII) and Integrated 
% Marine Observing System (IMOS).
% All rights reserved.
% 
% Redistribution and use in source and binary forms, with or without 
% modification, are permitted provided that the following conditions are met:
% 
%     * Redistributions of source code must retain the above copyright notice, 
%       this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright 
%       notice, this list of conditions and the following disclaimer in the 
%       documentation and/or other materials provided with the distribution.
%     * Neither the name of the eMII/IMOS nor the names of its contributors 
%       may be used to endorse or promote products derived from this software 
%       without specific prior written permission.
% 
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
% POSSIBILITY OF SUCH DAMAGE.
%
error(nargchk(1, 2, nargin));

if ~iscell(sample_data), error('sample_data must be a cell array'); end
if isempty(sample_data), return;                                    end

% auto logical in input to enable running under batch processing
if nargin<2, auto=false; end

for k = 1:length(sample_data)
  
  sam = sample_data{k};
  
  cndcIdx = getVar(sam.variables, 'CNDC');
  tempIdx = getVar(sam.variables, 'TEMP');
  presIdx = getVar(sam.variables, 'PRES');
  presRelIdx = getVar(sam.variables, 'PRES_REL');
  
  % cndc, temp, or pres/pres_rel not present in data set
  if ~(cndcIdx && tempIdx && (presIdx || presRelIdx)), continue; end
  
  % data set already contains salinity
  if getVar(sam.variables, 'PSAL'), continue; end
  
  cndc = sam.variables{cndcIdx}.data;
  temp = sam.variables{tempIdx}.data;
  if presRelIdx > 0
      presRel = sam.variables{presRelIdx}.data;
      presName = 'PRES_REL';
  else
      % update from a relative pressure like SeaBird computes
      % it in its processed files, substracting a constant value
      % 10.1325 dbar for nominal atmospheric pressure
      presRel = sam.variables{presIdx}.data - gsw_P0/10^4;
      presName = 'PRES substracting a constant value 10.1325 dbar for nominal atmospheric pressure';
  end
  
  % calculate C(S,T,P)/C(35,15,0) ratio
  % conductivity is in S/m and gsw_C3515 in mS/cm
  R = 10*cndc ./ gsw_C3515;
  
  % calculate salinity
  psal = gsw_SP_from_R(R, temp, presRel);
  
  % add salinity data as new variable in data set
  salinityComment = ['salinityPP.m: derived from CNDC, TEMP and ' presName ' using the Gibbs-SeaWater toolbox (TEOS-10) v3.02'];
  sample_data{k} = addVar(...
    sam, ...
    'PSAL', ...
    psal, ...
    getVar(sam.dimensions, 'TIME'), ...
    salinityComment);

    history = sample_data{k}.history;
    if isempty(history)
        sample_data{k}.history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), salinityComment);
    else
        sample_data{k}.history = sprintf('%s\n%s - %s', history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), salinityComment);
    end
end
