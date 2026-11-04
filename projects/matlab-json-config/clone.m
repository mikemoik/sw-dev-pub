function cfg = clone(jsonFile)
%CLONE Read a JSON config file and return a Config with 'timestamp' + 20.
%   cfg = CLONE("config.json") decodes the file, validates it against the
%   Config class, and adds 20 to cfg.timestamp.

    raw = jsondecode(fileread(jsonFile));

    if ~isfield(raw, 'timestamp')
        error('clone:missingField', ...
            'File "%s" has no top-level field ''timestamp''.', jsonFile);
    end

    cfg = Config(raw);
    cfg.timestamp = cfg.timestamp + 20;
end
