classdef Config < JsonConfig
%CONFIG Typed view of the JSON config — this is the "schema" MATLAB sees.

    properties
        timestamp (1,1) double
        name      (1,1) NameConfig
    end
end
