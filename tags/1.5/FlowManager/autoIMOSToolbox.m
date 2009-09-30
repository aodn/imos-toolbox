function autoIMOSToolbox(fieldTrip, dataDir, qcChain, exportDir)
%AUTOIMOSTOOLBOX Executes the toolbox automatically.
%
% All inputs are optional.
%
% Inputs:
%   fieldTrip - Numeric ID of field trip. 
%   dataDir   - Directory containing raw data files.
%   qcChain   - Cell array of strings, the names of QC filters to run.
%   exportDir - Directory to store output NetCDF files.
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
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
  error(nargchk(0, 4, nargin));

  % validate and save field trip
  if nargin > 0
    if ~isnumeric(fieldTrip), error('field trip must be numeric'); end
    writeToolboxProperty('startDialog.fieldTrip', num2str(fieldTrip));
  end

  % validate and save data dir
  if nargin > 1
    if ~ischar(dataDir),       error('dataDir must be a string');    end
    if ~exist(dataDir, 'dir'), error('dataDir must be a directory'); end

    writeToolboxProperty('startDialog.dataDir', dataDir);
  end

  % validate and save qc chain
  if nargin > 2
    if ~iscellstr(qcChain)
      error('qcChain must be a cell array of strings'); 
    end

    if ~isempty(qcChain)
      qcChainStr = cellfun(@(x)([x ' ']), qcChain, 'UniformOutput', false);
      qcChainStr = deblank([qcChainStr{:}]);
    else
      qcChainStr = '';
    end
    writeToolboxProperty('autoQCManager.autoQCChain', qcChainStr);
  end

  % validate and save export dir
  if nargin > 3
    if ~ischar(exportDir),       error('exportDir must be a string');    end
    if ~exist(exportDir, 'dir'), error('exportDir must be a directory'); end
    
    writeToolboxProperty('exportDialog.defaultDir', exportDir);
  end
  

  % import, QC, export
  sample_data = importManager(true);
  qc_data     = autoQCManager(sample_data, true);
  exportManager({sample_data qc_data}, {'raw', 'QC'}, 'netcdf', true);

end
