function [sample_data, varChecked, paramsLog] = imosSurfaceDetectionByDepthSetQC(sample_data, ~)
%function [sample_data, varChecked, paramsLog] = imosSurfaceDetectionByDepthSetQC(sample_data, ~)
%
% A Surface detection test for ADCPs using Depth information.
%
% The detection is done by inspecting the ADCP bins and the
% observable water column height. Any bin beyond this height
% is marked as bad.
%
% This test only works for datasets with available TIME dimension, 
% HEIGHT_ABOVE_SENSOR or DIST_ALONG_BEAMS dimensions, DEPTH variable,
% and adcp_site_nominal_depth or site_depth_at_deployment metadata.
%
% author: hugo.oliveira@utas.edu.au [refactored from older versions of imosSurfaceDetectSetQC].
%
narginchk(1, 2);
varChecked = {};
paramsLog = [];
currentQCtest = mfilename;

if ~isstruct(sample_data), error('sample_data must be a struct'); end

[valid,reason] = IMOS.validate_dataset(sample_data,currentQCtest);
if ~valid
    %TODO: we may need to include a global verbose flag to avoid pollution here.
    unwrapped_msg = ['Skipping %s. Reasons: ' cell2str(reason,'')];
    dispmsg(unwrapped_msg,sample_data.toolbox_input_file)
    return
end

idepth = IMOS.get_data(sample_data.variables,'DEPTH');
bathy = IMOS.meta.site_bathymetry(sample_data);
beam_face_config = IMOS.meta.beam_face_config(sample_data);

avail_dimensions = IMOS.get(sample_data.dimensions, 'name');
along_height = inCell(avail_dimensions, 'HEIGHT_ABOVE_SENSOR');
along_beams = inCell(avail_dimensions, 'DIST_ALONG_BEAMS');
if along_height
    bin_dist = IMOS.get_data(sample_data.dimensions,'HEIGHT_ABOVE_SENSOR');
elseif along_beams
    bin_dist = IMOS.get_data(sample_data.dimensions,'DIST_ALONG_BEAMS');
end

[wbins, last_water_bin] = IMOS.adcp.bin_in_water(idepth,bin_dist,beam_face_config,bathy);


qcSet = str2double(readProperty('toolbox.qc_set'));
badFlag = imosQCFlag('bad', qcSet, 'flag');
goodFlag = imosQCFlag('good', qcSet, 'flag');

flags = ones(size(wbins), 'int8') * badFlag;
flags(wbins) = goodFlag;

if along_beams
    dims_tz = {'TIME','DIST_ALONG_BEAMS'};
    dispmsg('No bin-mapping performed. Surface Detections will be contaminated by missing tilt corrections.')
else
    dims_tz = {'TIME','HEIGHT_ABOVE_SENSOR'};
end

vars_tz = IMOS.variables_with_dimensions(sample_data.dimensions,sample_data.variables,dims_tz);
vars_tz_inds = IMOS.find(sample_data.variables,vars_tz);

for k=1:numel(vars_tz_inds)
    sample_data.variables{k}.flags = flags;
end
varChecked = vars_tz;
paramsLog = ['min_surface_bin=' min(last_water_bin), 'max_surface_bin=' max(last_water_bin)];

end
