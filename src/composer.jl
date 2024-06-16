import Base: getindex, setindex!, haskey

# error for composer

struct ComposerError <: Exception
    context::Union{String, Nothing}
    context_mark::Union{Mark, Nothing}
    problem::Union{String, Nothing}
    problem_mark::Union{Mark, Nothing}
    note::Union{String, Nothing}

    function ComposerError(context=nothing, context_mark=nothing,
                           problem=nothing, problem_mark=nothing,
                           note=nothing)
        new(context, context_mark, problem, problem_mark, note)
    end
end

function show(io::IO, error::ComposerError)
    if error.context !== nothing
        print(io, error.context, " at ", error.context_mark, ": ")
    end
    print(io, error.problem, " at ", error.problem_mark)
end

# composer

mutable struct Composer
    input::EventStream
    anchors::Dict{String, Node}
    resolver::Resolver
end

peek(composer::Composer) = peek(composer.input)

forward!(composer::Composer) = forward!(composer.input)

getindex(composer::Composer, anchor::String) = composer.anchors[anchor]

setindex!(composer::Composer, node::Node, anchor::String) = composer.anchors[anchor] = node

haskey(composer::Composer, anchor::Union{String, Nothing}) = haskey(composer.anchors, anchor)

# compose

function compose(events::EventStream)
    composer = Composer(events, Dict{String, Node}(), Resolver())
    @assert forward!(composer) isa StreamStartEvent
    node = compose_document(composer)
    if peek(composer) isa StreamEndEvent
        forward!(composer)
    else
        @assert peek(composer) isa DocumentStartEvent
    end
    node
end

# compose document

function compose_document(composer::Composer)
    @assert forward!(composer) isa DocumentStartEvent
    node = compose_node(composer)
    @assert forward!(composer) isa DocumentEndEvent
    empty!(composer.anchors)
    node
end

# handle error

handle_error(event::Event, composer::Composer, anchor::Union{String, Nothing}) =
    anchor !== nothing && haskey(composer, anchor) && throw(ComposerError(
        "found duplicate anchor '$anchor'; first occurance", firstmark(composer[anchor]),
        "second occurence", firstmark(event),
    ))

# handle event

function handle_event(event::AliasEvent, composer::Composer)
    anchor = event.anchor
    forward!(composer)
    haskey(composer, anchor) || throw(ComposerError(
        nothing, nothing,
        "found undefined alias '$anchor'", firstmark(event),
    ))
    composer[anchor]
end

function handle_event(event::ScalarEvent, composer::Composer)
    anchor = event.anchor
    handle_error(event, composer, anchor)
    compose_scalar_node(composer, anchor)
end

function handle_event(event::SequenceStartEvent, composer::Composer)
    anchor = event.anchor
    handle_error(event, composer, anchor)
    compose_sequence_node(composer, anchor)
end

function handle_event(event::MappingStartEvent, composer::Composer)
    anchor = event.anchor
    handle_error(event, composer, anchor)
    compose_mapping_node(composer, anchor)
end

handle_event(event::Event, composer::Composer) = nothing

# compose node

function compose_node(composer::Composer)
    event = peek(composer)
    handle_event(event, composer)
end

# compose scalar node

function _compose_scalar_node(event::ScalarEvent, composer::Composer, anchor::Union{String, Nothing})
    tag = event.tag
    if tag === nothing || tag == "!"
        tag = resolve(composer.resolver, ScalarNode, event.value, event.implicit)
    end

    node = ScalarNode(tag, event.value, firstmark(event), lastmark(event), event.style)
    if anchor !== nothing
        composer[anchor] = node
    end

    node
end

compose_scalar_node(composer::Composer, anchor::Union{String, Nothing}) =
    _compose_scalar_node(forward!(composer), composer, anchor)

# compose sequence node

__compose_sequence_node(event::SequenceEndEvent, composer::Composer, node::Node) = false

function __compose_sequence_node(event::Event, composer, node)
    push!(node.value, compose_node(composer))
    true
end

function _compose_sequence_node(start_event::SequenceStartEvent, composer::Composer, anchor::Union{String, Nothing})
    tag = start_event.tag
    if tag === nothing || tag == "!"
        tag = resolve(composer.resolver, SequenceNode, nothing, start_event.implicit)
    end

    node = SequenceNode(tag, Any[], firstmark(start_event), nothing, start_event.flow_style)
    if anchor !== nothing
        composer[anchor] = node
    end

    while true
        event = peek(composer)
        event === nothing && break
        __compose_sequence_node(event, composer, node) || break
    end

    end_event = forward!(composer)
    node.end_mark = lastmark(end_event)

    node
end

compose_sequence_node(composer::Composer, anchor::Union{String, Nothing}) =
    _compose_sequence_node(forward!(composer), composer, anchor)

# compose mapping node

__compose_mapping_node(event::MappingEndEvent, composer::Composer, node::Node) = false

function __compose_mapping_node(event::Event, composer::Composer, node::Node)
    item_key = compose_node(composer)
    item_value = compose_node(composer)
    push!(node.value, (item_key, item_value))
    true
end

function _compose_mapping_node(start_event::MappingStartEvent, composer::Composer, anchor::Union{String, Nothing})
    tag = start_event.tag
    if tag === nothing || tag == "!"
        tag = resolve(composer.resolver, MappingNode, nothing, start_event.implicit)
    end

    node = MappingNode(tag, Any[], firstmark(start_event), nothing, start_event.flow_style)
    if anchor !== nothing
        composer[anchor] = node
    end

    while true
        event = peek(composer)
        __compose_mapping_node(event, composer, node) || break
    end

    end_event = forward!(composer)
    node.end_mark = lastmark(end_event)

    node
end

compose_mapping_node(composer::Composer, anchor::Union{String, Nothing}) =
    _compose_mapping_node(forward!(composer), composer, anchor)
