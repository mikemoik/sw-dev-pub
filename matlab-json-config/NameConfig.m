classdef NameConfig < JsonConfig
%NAMECONFIG Typed view of the nested "name" object in the JSON config.

    properties
        name    (1,1) string = ""
        surname (1,1) string = ""
    end

    properties (Dependent)
        fullName (1,1) string
    end

    methods
        function v = get.fullName(obj)
            v = strtrim(obj.name + " " + obj.surname);
        end
    end
end
