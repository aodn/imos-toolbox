function sam = finaliseData(sam, rawFiles, flagVal, toolboxVersion)
%FINALISEDATA Adds all required/relevant information from the given field
%trip and deployment structs to the given sample data following the IMOS NetCDF standard.
%
%
% Inputs:
%   sam             - a struct containing sample data.
%   rawFiles        - 
%   flagVal         -
%   toolboxVersion  - current version of the toolbox
%
% Outputs:
%   sample_data - same as input, with fields added/modified
%
% Author: Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
  error(nargchk(4, 4, nargin));

  if ~isstruct(sam), error('sam must be a struct'); end
  
  % add toolbox version info
  sam.toolbox_version = toolboxVersion;
  
  % add IMOS file version info
  if ~isfield(sam.meta, 'level') 
      sam.meta.level = 0; 
      sam.file_version                 = imosFileVersion(sam.meta.level, 'name');
      sam.file_version_quality_control = imosFileVersion(sam.meta.level, 'desc');
  end

  % get the toolbox execution mode. Values can be 'timeSeries' and 'profile'.
  % If no value is set then default mode is 'timeSeries'
  mode = lower(readProperty('toolbox.mode'));
  
  % turn raw data files a into semicolon separated string
  rawFiles = cellfun(@(x)([x ';']), rawFiles, 'UniformOutput', false);
  
  sam.meta.log           = {};
  sam.meta.QCres         = {};
  sam.meta.raw_data_file = [rawFiles{:}];
  
  if isfield(sam.meta, 'site')
      if ~isempty(fieldnames(sam.meta.site)), sam.meta.site_name = sam.meta.site.SiteName; end
  end
  
  if isfield(sam.meta, 'deployment')
      sam.meta.site_id       = sam.meta.deployment.Site;
      sam.meta.timezone      = sam.meta.deployment.TimeZone;
  elseif isfield(sam.meta, 'profile')
      sam.meta.survey        = sam.meta.profile.FieldTrip;
      sam.meta.site_id       = sam.meta.profile.Site;
      sam.meta.station       = sam.meta.profile.Station;
      sam.meta.depth         = sam.meta.profile.InstrumentDepth;
      sam.meta.timezone      = sam.meta.profile.TimeZone;
  else
      
      if ~isfield(sam.meta, 'site_name'); sam.meta.site_name  = 'UNKNOWN';  end
      if ~isfield(sam.meta, 'site_id');   sam.meta.site_id    = 'UNKNOWN';  end
      if ~isfield(sam.meta, 'timezone');  sam.meta.timezone   = 'UTC';      end
      
      switch mode
          case 'profile'
              if ~isfield(sam.meta, 'survey');    sam.meta.survey     = 'UNKNOWN';  end
              if ~isfield(sam.meta, 'station');   sam.meta.station    = NaN;        end
              if ~isfield(sam.meta, 'depth');     sam.meta.depth      = NaN;        end
              
      end
  end
  
  % add empty QC flags for all variables
  for k = 1:length(sam.variables)
    
    if isfield(sam.variables{k}, 'flags'), continue; end
    
    sam.variables{k}.flags(1:numel(sam.variables{k}.data)) = flagVal;
    sam.variables{k}.flags = reshape(...
    sam.variables{k}.flags, size(sam.variables{k}.data));
  end
  
  % and for all dimensions
  for k = 1:length(sam.dimensions)
    
    if isfield(sam.dimensions{k}, 'flags'), continue; end
    if any(strcmpi(sam.dimensions{k}.name, {'INSTANCE', 'MAXZ'})), continue; end
    
    sam.dimensions{k}.flags(1:numel(sam.dimensions{k}.data)) = flagVal;
    sam.dimensions{k}.flags = reshape(...
    sam.dimensions{k}.flags, size(sam.dimensions{k}.data));
  end
  
  % add IMOS parameters
  sam = makeNetCDFCompliant(sam);
  if isfield(sam, 'instrument_nominal_depth')
      if ~isempty(sam.instrument_nominal_depth)
          sam.meta.depth = sam.instrument_nominal_depth;
      end
  end
  
  % populate NetCDF metadata from existing metadata/data if empty
  sam = populateMetadata(sam);
  
  % set the time deployment period from the metadata
  if isfield(sam.meta, 'deployment')
      if ~isempty(sam.meta.deployment.TimeFirstGoodData)
          sam.time_deployment_start         = sam.meta.deployment.TimeFirstGoodData;
          sam.time_deployment_start_origin  = 'TimeFirstGoodData';
      elseif ~isempty(sam.meta.deployment.TimeFirstInPos)
          sam.time_deployment_start         = sam.meta.deployment.TimeFirstInPos;
          sam.time_deployment_start_origin  = 'TimeFirstInPos';
      elseif ~isempty(sam.meta.deployment.TimeFirstWet)
          sam.time_deployment_start         = sam.meta.deployment.TimeFirstWet;
          sam.time_deployment_start_origin  = 'TimeFirstWet';
      elseif ~isempty(sam.meta.deployment.TimeSwitchOn)
          sam.time_deployment_start         = sam.meta.deployment.TimeSwitchOn;
          sam.time_deployment_start_origin  = 'TimeSwitchOn';
      end
      
      if ~isempty(sam.meta.deployment.TimeLastGoodData)
          sam.time_deployment_end           = sam.meta.deployment.TimeLastGoodData;
          sam.time_deployment_end_origin    = 'TimeLastGoodData';
      elseif ~isempty(sam.meta.deployment.TimeLastInPos)
          sam.time_deployment_end           = sam.meta.deployment.TimeLastInPos;
          sam.time_deployment_end_origin    = 'TimeLastInPos';
      elseif ~isempty(sam.meta.deployment.TimeOnDeck)
          sam.time_deployment_end           = sam.meta.deployment.TimeOnDeck;
          sam.time_deployment_end_origin    = 'TimeOnDeck';
      elseif ~isempty(sam.meta.deployment.TimeSwitchOff)
          sam.time_deployment_end           = sam.meta.deployment.TimeSwitchOff;
          sam.time_deployment_end_origin    = 'TimeSwitchOff';
      end
  elseif isfield(sam.meta, 'profile')
      if ~isempty(sam.meta.profile.DateFirstInPos) && ~isempty(sam.meta.profile.TimeFirstInPos)
          sam.time_deployment_start = datenum([datestr(sam.meta.profile.DateFirstInPos, 'dd-mm-yyyy') ' ' ...
              datestr(sam.meta.profile.TimeFirstInPos, 'HH:MM:SS')], 'dd-mm-yyyy HH:MM:SS');
      end
      
      if ~isempty(sam.meta.profile.DateLastInPos) && ~isempty(sam.meta.profile.TimeLastInPos)
          sam.time_deployment_end = datenum([datestr(sam.meta.profile.DateLastInPos, 'dd-mm-yyyy') ' ' ...
              datestr(sam.meta.profile.TimeLastInPos, 'HH:MM:SS')], 'dd-mm-yyyy HH:MM:SS');
      end
  end
  
  if isempty(sam.time_deployment_start)
      sam.time_deployment_start         = [];
      sam.time_deployment_start_origin  = [];
  end
  if isempty(sam.time_deployment_end)
      sam.time_deployment_end           = [];
      sam.time_deployment_end_origin    = [];
  end
  
  % set the time coverage period from the data
  switch mode
      case 'profile'
          time = getVar(sam.variables, 'TIME');
          if time ~= 0
              if isempty(sam.time_coverage_start),
                  sam.time_coverage_start = sam.variables{time}.data(1);
              end
              if isempty(sam.time_coverage_end),
                  sam.time_coverage_end   = sam.variables{time}.data(end);
              end
          else
              if isempty(sam.time_coverage_start), sam.time_coverage_start = []; end
              if isempty(sam.time_coverage_end),   sam.time_coverage_end   = []; end
          end
          
      otherwise
          time = getVar(sam.dimensions, 'TIME');
          if time ~= 0
              if isempty(sam.time_coverage_start),
                  sam.time_coverage_start = sam.dimensions{time}.data(1);
              end
              if isempty(sam.time_coverage_end),
                  sam.time_coverage_end   = sam.dimensions{time}.data(end);
              end
          else
              if isempty(sam.time_coverage_start), sam.time_coverage_start = []; end
              if isempty(sam.time_coverage_end),   sam.time_coverage_end   = []; end
          end
  
  end
  
end