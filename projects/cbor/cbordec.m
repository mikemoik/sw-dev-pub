function [v, pos] = cbordec(b, pos)
%CBORDEC  Decode one CBOR data item (RFC 8949) from a uint8 buffer.
%   [V, POS] = CBORDEC(B) decodes the first item in uint8 vector B and
%   returns the next unread position, so a CBOR sequence (header + records,
%   RFC 8742) is read with a plain loop:
%
%       b = fread(fid, Inf, '*uint8')';
%       [header, pos] = cbordec(b);
%       while pos <= numel(b)
%           [rec, pos] = cbordec(b, pos);
%       end
%
%   [V, POS] = CBORDEC(B, POS) starts at position POS (1-based).
%
%   Type mapping back into MATLAB:
%     integers      -> double if |n| < 2^53, else uint64/int64
%     byte string   -> uint8 row vector
%     text string   -> char row vector (UTF-8 decoded)
%     array         -> cell row vector (faithful to per-element types)
%     map           -> struct when every key is text and a valid identifier,
%                      otherwise containers.Map (all-char or all-numeric keys)
%     float16/64    -> double;  float32 -> single (round-trips with CBORENC)
%     false/true    -> logical
%     null          -> []
%     undefined     -> missing
%     tag 55799     -> unwrapped silently (the self-describe magic)
%     tags 64..87   -> RFC 8746 typed array -> typed row vector (both byte
%                      orders; float16 widens to double; float128 falls
%                      through to the generic tag struct)
%     tag 40 / 1040 -> RFC 8746 multi-dim array -> MATLAB array (1040 is
%                      column-major, i.e. MATLAB-native; 40 is row-major)
%     other tag n   -> struct('cbor_tag', n, 'value', {content})
%
%   Indefinite-length strings, arrays, and maps are supported; chunked
%   strings are concatenated. Malformed input errors with 'cbordec:*'.
%
%   See also CBORENC, FREAD.

    if nargin < 2, pos = 1; end
    b = uint8(b(:)');
    [v, pos] = item(b, pos);
    if isequal(v, BreakMarker)
        error('cbordec:break', 'unexpected break (0xff) at top level');
    end
end

% ---------------------------------------------------------------------------

function m = BreakMarker()
    m = struct('cbor_break', true);   % internal sentinel, never returned
end

function [v, pos] = item(b, pos)
    if pos > numel(b)
        error('cbordec:eof', 'truncated: item head expected at %d', pos);
    end
    ib = double(b(pos));
    pos = pos + 1;
    major = floor(ib / 32);
    info  = mod(ib, 32);

    if ib == 255                              % break
        v = BreakMarker;
        return
    end
    if info >= 28 && info <= 30
        error('cbordec:reserved', 'reserved additional info %d at %d', info, pos - 1);
    end

    indef = (info == 31);
    n = uint64(0);                            % unused when indefinite
    if ~indef && major ~= 7
        [n, pos] = arg(b, pos, info);
    end

    switch major
        case 0                                % unsigned int
            v = toInt(n, false);
        case 1                                % negative int, -1 - n
            v = toInt(n, true);
        case 2                                % byte string
            [v, pos] = strBody(b, pos, indef, n, 2);
        case 3                                % text string
            [raw, pos] = strBody(b, pos, indef, n, 3);
            v = native2unicode(raw, 'UTF-8');
            if isempty(v), v = ''; end
        case 4                                % array -> cell
            if indef
                v = {};
                while true
                    [e, pos] = item(b, pos);
                    if isequal(e, BreakMarker), break, end
                    v{end + 1} = e; %#ok<AGROW>
                end
            else
                v = cell(1, n);
                for k = 1:n
                    [v{k}, pos] = itemStrict(b, pos);
                end
            end
        case 5                                % map
            ky = {}; vl = {};
            if indef
                while true
                    [k, pos] = item(b, pos);
                    if isequal(k, BreakMarker), break, end
                    [w, pos] = itemStrict(b, pos);
                    ky{end + 1} = k; vl{end + 1} = w; %#ok<AGROW>
                end
            else
                ky = cell(1, n); vl = cell(1, n);
                for k = 1:n
                    [ky{k}, pos] = itemStrict(b, pos);
                    [vl{k}, pos] = itemStrict(b, pos);
                end
            end
            v = buildMap(ky, vl);
        case 6                                % tag
            [content, pos] = itemStrict(b, pos);
            if n == 55799                     % self-describe magic: unwrap
                v = content;
            elseif n >= 64 && n <= 87 && isa(content, 'uint8')
                [v, ok] = typedVal(double(n), content);   % RFC 8746 typed array
                if ~ok
                    v = struct('cbor_tag', n, 'value', {content});
                end
            elseif (n == 40 || n == 1040) && iscell(content) && numel(content) == 2
                v = multiDim(double(n), content);         % RFC 8746 multi-dim
            else
                v = struct('cbor_tag', n, 'value', {content});
            end
        case 7                                % simple / float
            [v, pos] = simple(b, pos, info);
    end
end

function [v, pos] = itemStrict(b, pos)
%ITEMSTRICT  Decode one item; a break byte here is malformed.
    [v, pos] = item(b, pos);
    if isequal(v, BreakMarker)
        error('cbordec:break', 'break (0xff) inside definite-length item');
    end
end

function [n, pos] = arg(b, pos, info)
%ARG  The head's argument: info itself, or 1/2/4/8 following big-endian bytes.
    if info < 24
        n = uint64(info);
        return
    end
    nb = 2 ^ (info - 24);                     % 24..27 -> 1,2,4,8 bytes
    if pos + nb - 1 > numel(b)
        error('cbordec:eof', 'truncated: %d-byte argument at %d', nb, pos);
    end
    n = uint64(0);
    for k = 0:nb - 1
        n = n * 256 + uint64(b(pos + k));
    end
    pos = pos + nb;
end

function v = toInt(n, neg)
    if n < uint64(9007199254740992)           % 2^53: exact in double
        v = double(n);
        if neg, v = -1 - v; end
    elseif ~neg
        v = n;                                % uint64
    elseif n < uint64(9223372036854775808)    % fits int64
        v = int64(-1) - int64(n);
    else
        error('cbordec:range', 'negative integer below intmin(''int64'')');
    end
end

function [raw, pos] = strBody(b, pos, indef, n, major)
    if ~indef
        n = double(n);
        if pos + n - 1 > numel(b)
            error('cbordec:eof', 'truncated: %d-byte string at %d', n, pos);
        end
        raw = b(pos:pos + n - 1);
        pos = pos + n;
        return
    end
    raw = uint8([]);                          % indefinite: definite chunks + break
    while true
        if pos > numel(b)
            error('cbordec:eof', 'truncated inside indefinite string');
        end
        if b(pos) == 255
            pos = pos + 1;
            return
        end
        cm = floor(double(b(pos)) / 32);
        ci = mod(double(b(pos)), 32);
        if cm ~= major || ci == 31
            error('cbordec:chunk', 'indefinite string chunk must be a definite %d-string', major);
        end
        [cn, cpos] = arg(b, pos + 1, ci);
        [chunk, pos] = strBody(b, cpos, false, cn, major);
        raw = [raw, chunk]; %#ok<AGROW>
    end
end

function v = buildMap(ky, vl)
    istext = cellfun(@ischar, ky);
    if all(istext) && all(cellfun(@isvarname, ky)) && numel(unique(ky)) == numel(ky)
        v = struct();
        for k = 1:numel(ky)
            v.(ky{k}) = vl{k};
        end
    elseif all(istext)
        v = containers.Map(ky, vl, 'UniformValues', false);
    elseif all(cellfun(@isnumeric, ky))
        v = containers.Map(cell2mat(ky), vl, 'UniformValues', false);
    else
        error('cbordec:mapkeys', 'mixed or non-char/non-numeric map keys not representable');
    end
end

function [v, pos] = simple(b, pos, info)
    switch info
        case 20, v = false;
        case 21, v = true;
        case 22, v = [];                      % null
        case 23, v = missing;                 % undefined
        case 24                               % simple value in next byte
            if pos > numel(b), error('cbordec:eof', 'truncated simple value'); end
            v = struct('cbor_simple', double(b(pos)));
            pos = pos + 1;
        case 25                               % float16
            [n, pos] = arg(b, pos, 25);
            v = f16val(double(n));
        case 26                               % float32
            [n, pos] = arg(b, pos, 26);
            v = typecast(swapIfLE(uint32(n)), 'single');
        case 27                               % float64
            [n, pos] = arg(b, pos, 27);
            v = typecast(swapIfLE(uint64(n)), 'double');
        otherwise                             % simple values 0..19
            v = struct('cbor_simple', info);
    end
end

function x = swapIfLE(u)
%SWAPIFLE  ARG returned the value numerically; typecast needs host order.
%   U already holds the big-endian bytes as a number, which IS the value --
%   so on any host, plain typecast of the native representation is correct.
    x = u;                                    % no-op; kept for the explanation
end

function [v, ok] = typedVal(n, raw)
%TYPEDVAL  RFC 8746 typed-array tag N + byte string -> MATLAB row vector.
%   OK is false for the tags this host cannot represent (float128, 83/87)
%   and reserved 76; the caller then falls back to the generic tag struct.
    %     tag  class     width  big-endian
    T = { 64, 'uint8',   1, false;  65, 'uint16', 2, true
          66, 'uint32',  4, true;   67, 'uint64', 8, true
          68, 'uint8',   1, false;  69, 'uint16', 2, false   % 68 = clamped
          70, 'uint32',  4, false;  71, 'uint64', 8, false
          72, 'int8',    1, false;  73, 'int16',  2, true
          74, 'int32',   4, true;   75, 'int64',  8, true
          77, 'int16',   2, false;  78, 'int32',  4, false
          79, 'int64',   8, false
          80, 'half',    2, true;   81, 'single', 4, true
          82, 'double',  8, true;   84, 'half',   2, false
          85, 'single',  4, false;  86, 'double', 8, false };
    row = find([T{:, 1}] == n, 1);
    ok = ~isempty(row);
    if ~ok, v = []; return, end
    [cls, w, big] = deal(T{row, 2}, T{row, 3}, T{row, 4});
    if mod(numel(raw), w) ~= 0
        error('cbordec:typedarray', ...
            'tag %d: %d bytes is not a multiple of element size %d', n, numel(raw), w);
    end
    [~, ~, endian] = computer;
    if big ~= (endian == 'B')                 % normalize to host byte order
        raw = reshape(flipud(reshape(raw, w, [])), 1, []);
    end
    if strcmp(cls, 'half')                    % no native half: widen to double
        v = arrayfun(@f16val, double(typecast(raw, 'uint16')));
    else
        v = typecast(raw, cls);
    end
end

function v = multiDim(tag, content)
%MULTIDIM  RFC 8746 s3.1 multi-dimensional array: [[dim1, dim2, ...], data].
%   Tag 1040 is column-major (MATLAB-native); tag 40 is row-major.
    dims = content{1};
    if iscell(dims), dims = cell2mat(dims); end
    data = content{2};
    if iscell(data), data = cell2mat(data); end   % plain-array data variant
    if ~isnumeric(data) || numel(data) ~= prod(dims)
        error('cbordec:multidim', 'multi-dim data does not match dims [%s]', ...
            num2str(dims));
    end
    if numel(dims) < 2
        v = data;
    elseif tag == 1040
        v = reshape(data, dims);
    else                                          % row-major -> permute back
        v = permute(reshape(data, fliplr(dims)), numel(dims):-1:1);
    end
end

function x = f16val(h)
%F16VAL  IEEE 754 binary16 (as a 0..65535 number) -> double.
    s = 1 - 2 * (h >= 32768);
    h = mod(h, 32768);
    e = floor(h / 1024);
    m = mod(h, 1024);
    if e == 0
        x = s * m * 2^-24;                    % subnormal (or signed zero)
    elseif e == 31
        if m == 0, x = s * Inf; else, x = NaN; end
    else
        x = s * (1024 + m) * 2^(e - 25);      % normal
    end
end
