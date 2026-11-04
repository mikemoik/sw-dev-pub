classdef (Abstract) JsonConfig
%JSONCONFIG Base class for typed JSON config objects.
%   Subclasses only declare properties (their "schema"). This constructor
%   copies matching fields from a jsondecode struct; unknown fields are
%   ignored, missing fields keep the subclass defaults. Nested objects
%   convert automatically via the subclass property types.

    methods
        function obj = JsonConfig(s)
            arguments
                s (1,1) struct = struct()
            end
            plist = metaclass(obj).PropertyList;
            for k = 1:numel(plist)
                p = plist(k);
                if ~p.Dependent && isfield(s, p.Name)
                    obj.(p.Name) = s.(p.Name);
                end
            end
        end
    end
end
