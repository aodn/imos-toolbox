function AIMSmetadata = setAIMSmetadata(site,metadataField)

%This function allows a generic config file to be used with the
%IMOS toolbox for processing AIMS data.
%The function call [mat setAIMSmetadata('[ddb Site]','naming_authority')]
%in global_attributes.txt calls this function with the site and the
%datafield as arguements. This function then passes back an appropriate
%string for that site and field.

%If the site is not reconised, default "IMOS" strings are returned.

switch metadataField
    case 'principal_investigator'
        if identifySite(site,{'GBR','NRSYON'})
            AIMSmetadata = 'Q-IMOS';
        elseif identifySite(site,{'ITF','PIL', 'KIM', 'NIN'})
            AIMSmetadata = 'WAIMOS';
        elseif identifySite(site,{'NRSDAR'})
            AIMSmetadata = 'IMOS';
        else
            AIMSmetadata = 'IMOS';
        end
        return
        
    case 'principal_investigator_email'
        if identifySite(site,{'GBR','NRSYON'})
            AIMSmetadata = 'c.steinberg@aims.gov.au';
        elseif identifySite(site,{'ITF','PIL', 'KIM', 'NIN'})
            AIMSmetadata = 'c.steinberg@aims.gov.au';
        elseif identifySite(site,{'NRSDAR'})
            AIMSmetadata = 'c.steinberg@aims.gov.au';
        else
            AIMSmetadata = 'IMOS';
        end
        return
        
    case 'project_acknowledgement'
        if identifySite(site,{'GBR','NRSYON'})
            AIMSmetadata = ['The collection of this data was funded by IMOS ',...
                'and delivered through the Queensland and Northern Australia ',...
                'Mooring sub-facility of the Australian National Mooring Network ',...
                'operated by the Australian Institute of Marine Science. ',...
                'IMOS is supported by the Australian Government through the ',...
                'National Collaborative Research Infrastructure Strategy, ',...
                'the Super Science Initiative and the Department of Employment, ',...
                'Economic Development and Innovation of the Queensland State ',...
                'Government. The support of the Tropical Marine Network ',...
                '(University of Sydney, Australian Museum, University of ',...
                'Queensland and James Cook University) on the GBR is also ',...
                'acknowledged.'];
        elseif identifySite(site,{'ITF','PIL', 'KIM', 'NIN'})
            AIMSmetadata = ['The collection of this data was funded by IMOS ',...
                'and delivered through the Queensland and Northern Australia ',...
                'Mooring sub-facility of the Australian National Mooring Network ',...
                'operated by the Australian Institute of Marine Science. ',...
                'IMOS is supported by the Australian Government through the ',...
                'National Collaborative Research Infrastructure Strategy, ',...
                'the Super Science Initiative and the Western Australian State Government. '];
        elseif identifySite(site,{'NRSDAR'})
            AIMSmetadata = ['The collection of this data was funded by IMOS',...
                'and delivered through the Queensland and Northern Australia',...
                'Mooring sub-facility of the Australian National Mooring Network',...
                'operated by the Australian Institute of Marine Science.',...
                'IMOS is supported by the Australian Government through the',...
                'National Collaborative Research Infrastructure Strategy,',...
                'and the Super Science Initiative. The support of the Darwin ',...
                'Port Corporation is also acknowledged'];
        else
            AIMSmetadata = ['The collection of this data was funded by IMOS ',...
                'and delivered through the Queensland and Northern Australia ',...
                'Mooring sub-facility of the Australian National Mooring Network ',...
                'operated by the Australian Institute of Marine Science. ',...
                'IMOS is supported by the Australian Government through the ',...
                'National Collaborative Research Infrastructure Strategy, ',...
                'and the Super Science Initiative.'];
        end
        return
        
    case 'local_time_zone'
        if identifySite(site,{'GBR','NRSYON'})
            AIMSmetadata = '+10';
        elseif identifySite(site,{'ITF','NRSDAR'})
            AIMSmetadata = '+9.5';
        elseif identifySite(site,{'PIL', 'KIM', 'NIN'})
            AIMSmetadata = '+8';
        else
            AIMSmetadata = '+10';
        end
        return
        
    case 'institution'
        if identifySite(site,{'NRS'})
            AIMSmetadata = 'ANMN-NRS';
        else
            AIMSmetadata = 'ANMN-QLD';
        end
end

function result = identifySite(site,token)
f = regexp(site,token);
g = cell2mat(f);
result = ~isempty(g);





