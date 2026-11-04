function b = cborenc(v)
%CBORENC  Encode a MATLAB value as one CBOR data item (RFC 8949).
%   B = CBORENC(V) returns a uint8 row vector holding V in CBOR.
%
%   Type mapping is deliberately literal -- the MATLAB class decides the CBOR
%   major type, so what you cast is what you get. No integer/float guessing.
%
%     []                      -> null (0xf6)
%     logical scalar          -> true / false
%     int8..int64/uint8..64   -> major 0/1 integer  (scalar)
%     single scalar           -> float32 (0xfa)
%     double scalar           -> float64 (0xfb)      cast to single for 4 bytes
%     char row / string scalar-> text string (major 3, UTF-8)
%     uint8 row vector        -> byte string (major 2)
%     other numeric vector    -> RFC 8746 typed array: little-endian tag
%                                (69/70/71 uintN, 77/78/79 intN, 85 single,
%                                86 double) wrapping one packed byte string
%     numeric matrix / ND     -> tag 1040 (multi-dim, column-major -- the
%                                MATLAB layout) wrapping dims + typed array
%     logical vector          -> array of true/false items
%     cell array              -> array of items, per-element types
%     scalar struct           -> map, keys are field names in definition order
%     containers.Map / dictionary -> map
%     struct('cbor_tag',n,'value',x) -> tagged item (major 6)
%     struct('cbor_f16',x)    -> float16 (0xf9), round-to-nearest-even
%
%   Typed arrays are emitted with the little-endian tags, so on LE hosts
%   (x86/ARM) the payload is a straight TYPECAST of MATLAB memory. To force
%   an array-of-items encoding instead, pass num2cell(v).
%
%   Deterministic encoding (RFC 8949 s4.2) additionally requires map keys in
%   sorted bytewise order; this encoder preserves insertion order instead.
%   Sort the fields yourself (ORDERFIELDS) if you need to hash or sign output.
%
%   Indefinite-length containers are not produced here -- emit the head byte
%   0x9f (array) or 0xbf (map) and the break byte 0xff yourself around
%   repeated CBORENC calls when streaming.
%
%   See also FWRITE, TYPECAST.

    if isstruct(v) && isscalar(v) && isfield(v, 'cbor_tag') && isfield(v, 'value')
        b = [head(6, v.cbor_tag), cborenc(v.value)];
        return
    end
    if isstruct(v) && isscalar(v) && isfield(v, 'cbor_f16')
        b = [uint8(249), f16be(single(v.cbor_f16))];
        return
    end

    if isempty(v) && ~ischar(v) && ~iscell(v) && ~isstring(v)
        b = uint8(246);                                   % null
    elseif islogical(v) && isscalar(v)
        b = uint8(244 + double(v));                       % false / true
    elseif ischar(v) || (isstring(v) && isscalar(v))
        raw = uint8(unicode2native(char(v), 'UTF-8'));
        b = [head(3, numel(raw)), raw(:)'];
    elseif isa(v, 'uint8') && isvector(v)
        b = [head(2, numel(v)), v(:)'];
        if isscalar(v)                                    % scalar uint8 is an int
            b = encInt(double(v));
        end
    elseif isnumeric(v) && isscalar(v)
        b = encScalar(v);
    elseif isnumeric(v)
        b = typedArray(v);
    elseif islogical(v)
        if ~isvector(v)
            error('cborenc:shape', 'logical arrays must be vectors');
        end
        b = head(4, numel(v));
        for k = 1:numel(v)
            b = [b, cborenc(v(k))]; %#ok<AGROW>
        end
    elseif iscell(v)
        b = head(4, numel(v));
        for k = 1:numel(v)
            b = [b, cborenc(v{k})]; %#ok<AGROW>
        end
    elseif isstruct(v) && isscalar(v)
        f = fieldnames(v);
        b = head(5, numel(f));
        for k = 1:numel(f)
            b = [b, cborenc(f{k}), cborenc(v.(f{k}))]; %#ok<AGROW>
        end
    elseif isa(v, 'containers.Map') || isa(v, 'dictionary')
        ky = keys(v);
        if isa(v, 'dictionary'), ky = num2cell(ky); end
        b = head(5, numel(ky));
        for k = 1:numel(ky)
            b = [b, cborenc(ky{k}), cborenc(v(ky{k}))]; %#ok<AGROW>
        end
    else
        error('cborenc:unsupported', 'cannot encode class %s', class(v));
    end
end

% ---------------------------------------------------------------------------

function b = encScalar(v)
    if isinteger(v)
        b = encInt(v);                        % native width: no double round trip
    elseif isnan(v)
        % canonical quiet NaN: MATLAB's native NaN has the SIGN BIT SET
        % (num2hex(NaN) = fff8...), Octave's does not -- pin the bytes so
        % output is platform-independent
        if isa(v, 'single')
            b = uint8([250 127 192 0 0]);         % fa 7fc00000
        else
            b = uint8([251 127 248 0 0 0 0 0 0]); % fb 7ff8000000000000
        end
    elseif isa(v, 'single')
        b = [uint8(250), be(v)];                          % 0xfa float32
    else
        b = [uint8(251), be(double(v))];                  % 0xfb float64
    end
end

function b = encInt(n)
%ENCINT  Integer-valued scalar (native integer class or double) -> major 0/1.
%   Kept exact for the full int64/uint64 range: values are widened to
%   uint64/int64, never through double (which rounds above 2^53).
    if n >= 0
        b = head(0, uint64(n));
    elseif isa(n, 'double')
        b = head(1, uint64(-1 - n));
    else
        b = head(1, uint64(-(int64(n) + 1)));  % exact down to intmin('int64')
    end
end

function b = head(major, n)
%HEAD  Major type byte plus the argument, per RFC 8949 s3.
    m = uint8(bitshift(uint8(major), 5));
    n = uint64(n);
    if n < 24
        b = bitor(m, uint8(n));
    elseif n < 256
        b = [bitor(m, uint8(24)), uint8(n)];
    elseif n < 65536
        b = [bitor(m, uint8(25)), be(uint16(n))];
    elseif n < 4294967296
        b = [bitor(m, uint8(26)), be(uint32(n))];
    else
        b = [bitor(m, uint8(27)), be(n)];
    end
end

function b = be(x)
%BE  Raw bytes of scalar X in big-endian (network) order, host-independent.
    b = typecast(x, 'uint8');
    [~, ~, endian] = computer;
    if endian == 'L'
        b = fliplr(b);
    end
end

function b = typedArray(v)
%TYPEDARRAY  Numeric vector -> RFC 8746 typed array (little-endian tags);
%   matrix/ND -> tag 1040 (column-major multi-dim) wrapping the typed array.
    tags = struct('uint8', 64, 'uint16', 69, 'uint32', 70, 'uint64', 71, ...
                  'int8', 72, 'int16', 77, 'int32', 78, 'int64', 79, ...
                  'single', 85, 'double', 86);
    cls = class(v);
    if ~isfield(tags, cls)
        error('cborenc:typedarray', 'no typed-array tag for class %s', cls);
    end
    raw = typecast(reshape(v, 1, []), 'uint8');
    [~, ~, endian] = computer;
    if endian == 'B'                          % wire format is little-endian
        w = numel(raw) / numel(v);
        raw = reshape(flipud(reshape(raw, w, [])), 1, []);
    end
    b = [head(6, tags.(cls)), head(2, numel(raw)), raw];
    if ~isvector(v)
        dims = size(v);                       % RFC 8746 s3.1.2: [[dims], data]
        db = head(4, numel(dims));
        for k = 1:numel(dims)
            db = [db, head(0, dims(k))]; %#ok<AGROW>
        end
        b = [head(6, 1040), head(4, 2), db, b];
    end
end

function b = f16be(x)
%F16BE  Scalar single -> IEEE 754 binary16, round-to-nearest-even, big-endian.
    if isnan(x)
        b = uint8([126 0]);                       % canonical f9 7e00; MATLAB's
        return                                    % NaN sign bit must not leak
    end
    u    = typecast(single(x), 'uint32');
    sgn  = uint16(bitshift(bitand(u, uint32(2147483648)), -16));  % bit 15
    expo = double(bitshift(bitand(u, uint32(2139095040)), -23)) - 127;
    mant = double(bitand(u, uint32(8388607)));                    % 23 bits
    if expo == 128                                % Inf / NaN
        h = 31744;                                % 0x7c00
        if mant > 0, h = 32256; end               % 0x7e00 canonical NaN
    elseif expo > 15                              % overflow -> Inf
        h = 31744;
    elseif expo >= -14                            % normal binary16
        h = bitshift(expo + 15, 10) + rne(mant / 8192);   % drop 13 bits
        % a mantissa carry from rounding overflows cleanly into the exponent
    elseif expo >= -24                            % subnormal binary16
        h = rne((mant + 8388608) / 2^(13 - 14 - expo));
    else                                          % underflow -> signed zero
        h = 0;
    end
    h = uint16(h) + sgn;
    b = [uint8(bitshift(h, -8)), uint8(bitand(h, uint16(255)))];
end

function r = rne(x)
%RNE  Round to nearest, ties to even (MATLAB's ROUND ties away from zero).
    r = floor(x);
    f = x - r;
    if f > 0.5 || (f == 0.5 && mod(r, 2) == 1)
        r = r + 1;
    end
end
