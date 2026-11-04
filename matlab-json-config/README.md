# matlab-json-config

Pattern for **typed JSON configuration in MATLAB**: declare the schema as class properties with size/class validation, and let an abstract base class copy the fields of a `jsondecode` struct into them. Nested JSON objects become nested typed objects via the property types; unknown fields are ignored, missing fields keep their defaults, wrong types raise MATLAB's validation errors.

**Owner:** swdevos · **Status:** example/pattern, **untested** — MATLAB only; not run by the maintainer (no MATLAB on the maintainer's host, and GNU Octave lacks `metaclass().PropertyList` and property validation, so it does not run there) · **License:** MIT (repo root)

## Files

| File | What |
|---|---|
| `JsonConfig.m` | Abstract base: constructor `JsonConfig(s)` copies matching, non-dependent properties from struct `s`. |
| `Config.m` | Example schema: `timestamp (1,1) double`, `name (1,1) NameConfig`. |
| `NameConfig.m` | Example nested schema: `name`, `surname` strings + dependent `fullName`. |
| `clone.m` | Demo: read a JSON file, validate it into `Config`, add 20 to `timestamp`. |

## Use (MATLAB R2019b+ for `arguments` blocks)

```matlab
% config.json: {"timestamp": 100, "name": {"name": "Ada", "surname": "Lovelace"}}
cfg = clone("config.json");
cfg.timestamp        % 120
cfg.name.fullName    % "Ada Lovelace"
```

For your own config: subclass `JsonConfig`, declare properties with validation, construct with `MyConfig(jsondecode(fileread(f)))`.

## Test

No automated tests yet. Contributions with a `matlab.unittest` suite welcome.
