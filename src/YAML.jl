"""
    YAML

A package to read and write YAML.
https://github.com/JuliaData/YAML.jl

Reading:

* `YAML.load` parses the first YAML document of a YAML file as a Julia object.
* `YAML.load_all` parses all YAML documents of a YAML file.
* `YAML.load_file` is the same as `YAML.load` except it reads from a file.
* `YAML.load_all_file` is the same as `YAML.load_all` except it reads from a file.

Writing:

* `YAML.write` prints a Julia object as a YAML file.
* `YAML.write_file` is the same as `YAML.write` except it writes to a file.
* `YAML.yaml` converts a given Julia object to a YAML-formatted string.
"""
module YAML

import Base: isempty, length, show, peek
import Base: iterate

using Base64: base64decode
using Dates
using Printf
using StringEncodings

include("queue.jl")
include("buffered_input.jl")
include("mark.jl")
include("span.jl")
include("tokens.jl")
include("scanner.jl")
include("events.jl")
include("parser.jl")
include("nodes.jl")
include("resolver.jl")
include("composer.jl")
include("constructor.jl")
include("writer.jl")

const _constructor = Union{Dict, Nothing}
const _dicttype = Union{Type, Function}

# add a dicttype-aware version of construct_mapping to the constructors
function _patch_constructors(more_constructors::_constructor, dicttype::_dicttype)
    if more_constructors === nothing
        more_constructors = Dict{String,Function}()
    else
        more_constructors = copy(more_constructors) # do not change the outside world
    end
    if !haskey(more_constructors, "tag:yaml.org,2002:map")
        more_constructors["tag:yaml.org,2002:map"] = custom_mapping(dicttype) # map to the custom type
    elseif dicttype != Dict{Any,Any} # only warn if another type has explicitly been set
        @warn "dicttype=$dicttype has no effect because more_constructors has the key \"tag:yaml.org,2002:map\""
    end
    return more_constructors
end

"""
    parsefirst(x::Union{AbstractString, IO})

Parse the string or stream `x` as a YAML file, and return the first YAML document as a
Julia object.
"""
function parsefirst(tokenstream::TokenStream, constructor::Constructor)
    eventstream = EventStream(tokenstream)
    resolver = Resolver()
    node = compose(eventstream, resolver)
    document = construct_document(constructor, node)
    document
end

function parsefirst(io::IO, constructor::Constructor)
    tokenstream = TokenStream(io)
    parsefirst(tokenstream, constructor)
end

parsefirst(
    tokenstream::TokenStream, more_constructors::_constructor=nothing, multi_constructors::Dict=Dict();
    dicttype::_dicttype=Dict{Any, Any}, constructorType::Function=SafeConstructor,
) = parsefirst(
    tokenstream,
    constructorType(_patch_constructors(more_constructors, dicttype), multi_constructors),
)

function parsefirst(
    io::IO,
    more_constructors::_constructor=nothing,
    multi_constructors::Dict=Dict();
    kwargs...,
)
    tokenstream = TokenStream(io)
    parsefirst(tokenstream, more_constructors, multi_constructors; kwargs...)
end

"""
    YAMLDocIterator

An iterator type to represent multiple YAML documents. You can retrieve each YAML document
as a Julia object by iterating.
"""
mutable struct YAMLDocIterator
    input::IO
    ts::TokenStream
    constructor::Constructor
    next_doc

    function YAMLDocIterator(input::IO, constructor::Constructor)
        it = new(input, TokenStream(input), constructor, nothing)
        it.next_doc = eof(it.input) ? nothing : parsefirst(it.ts, it.constructor)
        it
    end
end

YAMLDocIterator(input::IO, more_constructors::_constructor=nothing, multi_constructors::Dict = Dict(); dicttype::_dicttype=Dict{Any, Any}, constructorType::Function = SafeConstructor) = YAMLDocIterator(input, constructorType(_patch_constructors(more_constructors, dicttype), multi_constructors))

# Old iteration protocol:
start(it::YAMLDocIterator) = nothing

function next(it::YAMLDocIterator, state)
    doc = it.next_doc
    if eof(it.input)
        it.next_doc = nothing
    else
        reset!(it.ts)
        it.next_doc = parsefirst(it.ts, it.constructor)
    end
    doc, nothing
end

done(it::YAMLDocIterator, state) = it.next_doc === nothing

# 0.7 iteration protocol:
iterate(it::YAMLDocIterator) = next(it, start(it))
iterate(it::YAMLDocIterator, s) = done(it, s) ? nothing : next(it, s)

"""
    parse(x::Union{AbstractString, IO}) -> YAMLDocIterator

Parse the string or stream `x` as a YAML file, and return corresponding YAML documents.
"""
parse(io::IO, args...; kwargs...) = YAMLDocIterator(io, args...; kwargs...)

function parsefirst(str::AbstractString, args...; kwargs...)
    io = IOBuffer(str)
    parsefirst(io, args...; kwargs...)
end

function parse(str::AbstractString, args...; kwargs...)
    io = IOBuffer(str)
    parse(io, args...; kwargs...)
end

"""
    parsefirstfile(filename::AbstractString)

Parse the YAML file `filename`, and return the first YAML document as a Julia object.
"""
function parsefirstfile(filename::AbstractString, args...; kwargs...)
    open(filename, "r") do io
        parsefirst(io, args...; kwargs...)
    end
end

"""
    parsefile(filename::AbstractString) -> YAMLDocIterator

Parse the YAML file `filename`, and return corresponding YAML documents.
"""
function parsefile(filename::AbstractString, args...; kwargs...)
    open(filename, "r") do io
        parse(io, args...; kwargs...)
    end
end

@deprecate load parsefirst
@deprecate load_all parse
@deprecate load_file parsefirstfile
@deprecate load_all_file parsefile

end  # module
