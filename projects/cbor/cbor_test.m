function cbor_test
%CBOR_TEST  Full test suite for CBORENC / CBORDEC.
%   Run from this directory:  cbor_test
%
%   Covers: RFC 8949 Appendix A vectors, float16 edge cases (ties, subnormals,
%   overflow), RFC 8746 typed arrays (exact bytes, both byte orders, all
%   classes, multi-dim tags 40/1040), generic-decoder features (indefinite
%   lengths, chunked strings, >2^53 integers, simple values, unknown tags,
%   non-identifier map keys), malformed-input errors, round trips, and a
%   header+blocks streaming sequence. Prints one line per group and a summary;
%   errors out (exit code style) if anything failed.

    nPass = 0; nFail = 0; failures = {};

    % ---- helpers ----------------------------------------------------------
    function ok(cond, label)
        if cond, nPass = nPass + 1;
        else
            nFail = nFail + 1; failures{end + 1} = label;
            fprintf(2, '  FAIL: %s\n', label);
        end
    end
    function chk(v, hex)                     % encode -> exact bytes
        ok(isequal(cborenc(v), hx(hex)), sprintf('enc %s', hex));
    end
    function dchk(hex, want)                 % decode bytes -> exact value
        ok(isequaln(cbordec(hx(hex)), want), sprintf('dec %s', hex));
    end
    function rt(v, label)                    % round trip, class+value exact
        ok(isequaln(cbordec(cborenc(v)), v), sprintf('roundtrip %s', label));
    end
    function echk(hex, id)                   % decode must error with id
        try
            cbordec(hx(hex));
            ok(false, sprintf('no error for %s', hex));
        catch e
            ok(strcmp(e.identifier, id), sprintf('%s -> %s', hex, id));
        end
    end
    function b = hx(h)
        b = uint8(sscanf(h, '%2x')');
    end

    % ---- 1. RFC 8949 Appendix A: integers --------------------------------
    fprintf('integers ...\n');
    chk(uint8(0), '00');  chk(uint8(1), '01');  chk(uint8(10), '0a');
    chk(uint8(23), '17'); chk(uint8(24), '1818'); chk(uint8(25), '1819');
    chk(uint8(100), '1864'); chk(uint16(1000), '1903e8');
    chk(uint32(1000000), '1a000f4240');
    chk(uint64(1000000000000), '1b000000e8d4a51000');
    chk(uint64(18446744073709551615), '1bffffffffffffffff');
    chk(uint64(9007199254740993), '1b0020000000000001');   % 2^53+1: exact, not rounded
    chk(int8(-1), '20');  chk(int8(-10), '29');  chk(int8(-100), '3863');
    chk(int16(-1000), '3903e7');
    chk(intmin('int64'), '3b7fffffffffffffff');
    dchk('00', 0);  dchk('1903e8', 1000);  dchk('3903e7', -1000);
    dchk('1bffffffffffffffff', uint64(18446744073709551615));
    ok(isequal(cbordec(cborenc(uint64(2)^60)), uint64(2)^60), 'uint64 2^60');
    ok(isequal(cbordec(cborenc(int64(-2)^60)), int64(-2)^60), 'int64 -2^60');

    % ---- 2. floats --------------------------------------------------------
    fprintf('floats ...\n');
    chk(1.1, 'fb3ff199999999999a');
    chk(single(100000), 'fa47c35000');
    chk(single(3.4028234663852886e38), 'fa7f7fffff');
    chk(1.0e300, 'fb7e37e43c8800759c');
    chk(-4.1, 'fbc010666666666666');
    chk(single(Inf), 'fa7f800000');  chk(Inf, 'fb7ff0000000000000');
    dchk('fa7f800000', single(Inf));
    ok(isnan(cbordec(hx('fb7ff8000000000000'))), 'dec NaN');
    % NaN bytes must be canonical on every platform (MATLAB's native NaN
    % carries a set sign bit; the encoder must not leak it)
    chk(single(NaN), 'fa7fc00000');
    chk(NaN, 'fb7ff8000000000000');
    rt(single(9.81), 'single scalar');  rt(pi, 'double scalar');

    % ---- 3. float16 (encode via cbor_f16, decode 0xf9) --------------------
    fprintf('float16 ...\n');
    f16 = @(x) struct('cbor_f16', x);
    chk(f16(0.0), 'f90000');        chk(f16(-0.0), 'f98000');
    chk(f16(1.0), 'f93c00');        chk(f16(1.5), 'f93e00');
    chk(f16(65504), 'f97bff');      chk(f16(65520), 'f97c00');   % ties->even->Inf
    chk(f16(2^-24), 'f90001');      chk(f16(1.5 * 2^-24), 'f90002');
    chk(f16(2^-25), 'f90000');      % tie rounds to even (0)
    chk(f16(2^-14), 'f90400');      % smallest normal
    chk(f16(-4), 'f9c400');
    chk(f16(Inf), 'f97c00');  chk(f16(-Inf), 'f9fc00');  chk(f16(NaN), 'f97e00');
    dchk('f90001', 2^-24);  dchk('f90400', 2^-14);  dchk('f93e00', 1.5);
    dchk('f9c400', -4);  dchk('f97c00', Inf);
    ok(isnan(cbordec(hx('f97e00'))), 'dec f16 NaN');

    % ---- 4. strings -------------------------------------------------------
    fprintf('strings ...\n');
    chk('', '60');  chk('a', '6161');  chk('IETF', '6449455446');
    chk(['"' '\'], '62225c');
    chk(hx('01020304'), '4401020304');            % byte string
    rt('grüße', 'utf8 text');  rt(uint8([1 2 3]), 'byte string');
    dchk('7f657374726561646d696e67ff', 'streaming');   % indefinite text
    dchk('5f42010243030405ff', uint8(1:5));            % indefinite bytes
    ok(isequal(cborenc(uint8(zeros(1, 0))), hx('f6')), 'empty uint8 -> null (documented)');

    % ---- 5. arrays and maps ----------------------------------------------
    fprintf('arrays/maps ...\n');
    chk({}, '80');
    chk({uint8(1), uint8(2), uint8(3)}, '83010203');
    chk({uint8(1), {uint8(2), uint8(3)}, {uint8(4), uint8(5)}}, '8301820203820405');
    chk(num2cell(uint8(1:25)), ...
        '98190102030405060708090a0b0c0d0e0f101112131415161718181819');
    chk(struct('a', uint8(1), 'b', {{uint8(2), uint8(3)}}), 'a26161016162820203');
    dchk('9f0102ff', {1, 2});                          % indefinite array
    m = cbordec(hx('bf61610161629f0203ffff'));         % indefinite map+array
    ok(isequal(m.a, 1) && isequal(m.b, {2, 3}), 'dec indefinite map');
    m = cbordec(hx('a16361206201'));                   % key "a b" -> Map
    ok(isa(m, 'containers.Map') && m('a b') == 1, 'non-identifier key -> Map');
    m = cbordec(hx('a1016178'));                       % numeric key -> Map
    ok(isa(m, 'containers.Map') && strcmp(m(1), 'x'), 'numeric key -> Map');
    rt(struct('v', uint8(1), 'name', 'imu0', 'x', single(1.5)), 'flat struct');
    rt({uint8(1), 'two', single(3), {[]}}, 'mixed cell');
    ok(isequal(cbordec(cborenc([true false])), {true, false}), ...
        'logical vector -> cell (documented)');

    % ---- 6. simple values, null, undefined --------------------------------
    fprintf('simple values ...\n');
    chk(true, 'f5');  chk(false, 'f4');  chk([], 'f6');
    dchk('f5', true);  dchk('f6', []);
    ok(isequal(cbordec(hx('f0')), struct('cbor_simple', 16)), 'simple 16');
    ok(isequal(cbordec(hx('f8ff')), struct('cbor_simple', 255)), 'simple 255');
    if exist('missing', 'builtin') || ~isempty(which('missing'))
        ok(ismissing(cbordec(hx('f7'))), 'undefined -> missing');
    else
        fprintf('  (skipping undefined/missing: not available on this host)\n');
    end

    % ---- 7. tags ----------------------------------------------------------
    fprintf('tags ...\n');
    chk(struct('cbor_tag', 0, 'value', '2013-03-21T20:04:00Z'), ...
        'c074323031332d30332d32315432303a30343a30305a');
    chk(struct('cbor_tag', 1, 'value', uint32(1363896240)), 'c11a514b67b0');
    t = cbordec(hx('c249010000000000000000'));         % tag 2 bignum: unknown
    ok(isequal(t.cbor_tag, 2) && isa(t.value, 'uint8'), 'unknown tag passthrough');
    rt(struct('cbor_tag', 1234, 'value', {{uint8(1), 'x'}}), 'tag struct');
    dchk('d9d9f763616263', 'abc');                     % 55799 unwraps

    % ---- 8. typed arrays (RFC 8746) ---------------------------------------
    fprintf('typed arrays ...\n');
    chk(uint32([1 2]), 'd846480100000002000000');
    chk(single([1.5 2.5]), 'd855480000c03f00002040');
    rt(uint16([0 65535]), 'uint16 vec');   rt(uint32(1:3), 'uint32 vec');
    rt(uint64([0 18446744073709551615]), 'uint64 vec');
    rt(int8([-128 127]), 'int8 vec');      rt(int16([-1 2]), 'int16 vec');
    rt(int32([intmin('int32') 0]), 'int32 vec');
    rt(int64([intmin('int64') intmax('int64')]), 'int64 vec');
    rt(single([9.81 0 -1.5]), 'single vec');  rt((1:5) / 3, 'double vec');
    dchk('d8414400010002', uint16([1 2]));             % uint16 BE
    dchk('d842480000000100000002', uint32([1 2]));     % uint32 BE
    % big-endian float32 (tag 81) and float16 array (tag 84)
    dchk('d851483fc0000040200000', single([1.5 2.5]));
    dchk('d85444003c003e', [1.0 1.5]);
    % multi-dim: 1040 column-major round trip, 40 row-major decode
    rt(reshape(single(1:6), 2, 3), '2x3 single (tag 1040)');
    rt(reshape(uint16(1:24), 2, 3, 4), '2x3x4 uint16 (tag 1040)');
    dchk('d8288282020386010203040506', [1 2 3; 4 5 6]);   % tag 40 row-major
    echk('d855450000000000', 'cbordec:typedarray');    % 5 B under float32 tag

    % ---- 9. malformed input -----------------------------------------------
    fprintf('malformed ...\n');
    echk('19', 'cbordec:eof');          % truncated argument
    echk('ff', 'cbordec:break');        % top-level break
    echk('1c', 'cbordec:reserved');     % reserved additional info
    echk('8201ff', 'cbordec:break');    % break inside definite array
    echk('4403', 'cbordec:eof');        % truncated byte string
    echk('9f01', 'cbordec:eof');        % unterminated indefinite array

    % ---- 10. streaming sequence (the logger layout) -----------------------
    fprintf('stream ...\n');
    hdr = struct('v', uint8(1), 'dev', 'imu0', 't0', uint32(1756944000), ...
                 'dt_ms', uint16(10), 'fields', {{'t', 'ax'}});
    B = 4;
    stream = cborenc(struct('cbor_tag', 55799, 'value', hdr));
    for blk = 1:3
        t  = uint32((blk - 1) * B : blk * B - 1) * 10;
        ax = single(t) * 0.1;
        stream = [stream, cborenc({t, ax})]; %#ok<AGROW>
    end
    ok(isequal(stream(1:3), hx('d9d9f7')), 'stream starts with magic');
    [h2, pos] = cbordec(stream);
    ok(isequaln(h2, hdr), 'stream header round trip');
    nblk = 0;
    while pos <= numel(stream)
        [blkv, pos] = cbordec(stream, pos);
        nblk = nblk + 1;
        ok(isa(blkv{1}, 'uint32') && isa(blkv{2}, 'single') ...
            && numel(blkv{1}) == B, sprintf('block %d types', nblk));
    end
    ok(nblk == 3 && isequal(blkv{1}(end), uint32(110)), 'stream block count/values');

    % ---- summary ----------------------------------------------------------
    fprintf('\n%d passed, %d failed\n', nPass, nFail);
    if nFail > 0
        error('cbor_test:failed', 'failures: %s', strjoin(failures, ' | '));
    end
end
