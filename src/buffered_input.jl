

# Simple buffered input that allows peeking an arbitrary number of characters
# ahead by maintaining a typically quite small buffer of a few characters.


mutable struct BufferedInput
    input::IO
    buffer::Vector{Char}
    offset::UInt64
    avail::UInt64

    function BufferedInput(input::IO)
        return new(input, Char[], 0, 0)
    end
end


# Read and buffer n more characters
function __fill(bi::BufferedInput, bi_input::IO, n::Integer)
    for _ in 1:n
        c = eof(bi_input) ? '\0' : read(bi_input, Char)
        i = bi.offset + bi.avail + 1
        if i ≤ length(bi.buffer)
            bi.buffer[i] = c
        else
            push!(bi.buffer, c)
        end
        bi.avail += 1
    end
end

_fill(bi::BufferedInput, n::Integer) = __fill(bi, bi.input, n)

# Peek the character in the i-th position relative to the current position.
# (0-based)
function peek(bi::BufferedInput, i::Integer=0)
    i1 = i + 1
    if bi.avail < i1
        _fill(bi, i1 - bi.avail)
    end
    bi.buffer[bi.offset + i1]
end


# Return the string formed from the first n characters from the current position
# of the stream.
function prefix(bi::BufferedInput, n::Integer=1)
    n1 = n + 1
    if bi.avail < n1
        _fill(bi, n1 - bi.avail)
    end
    String(bi.buffer[bi.offset .+ (1:n)])
end


# NOPE: This is wrong. What if n > bi.avail

# Advance the stream by n characters.
function forward!(bi::BufferedInput, n::Integer=1)
    if n < bi.avail
        bi.offset += n
        bi.avail -= n
    else
        n -= bi.avail
        bi.offset = 0
        bi.avail = 0
        while n > 0
            read(bi.input, Char)
            n -= 1
        end
    end
end

# Ugly hack to allow peeking of `StringDecoder`s
function peek(io::StringDecoder, ::Type{UInt8})
    c = read(io, UInt8)
    io.skip -= 1
    c
end

# The same but for Julia 1.3
peek(io::StringDecoder) = peek(io, UInt8)
