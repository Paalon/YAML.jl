import Base: getindex, setindex!, haskey

# error for composer

struct ComposerError <: Exception
    context::Union{String, Nothing}
    context_mark::Union{Mark, Nothing}
    problem::Union{String, Nothing}
    problem_mark::Union{Mark, Nothing}
    note::Union{String, Nothing}
end

ComposerError(context::Union{String, Nothing}, context_mark::Union{Mark, Nothing}, problem::Union{String, Nothing}, problem_mark::Union{Mark, Nothing}) = ComposerError(context, context_mark, problem, problem_mark, nothing)

ComposerError(problem::Union{String, Nothing}, problem_mark::Union{Mark, Nothing}) = ComposerError(nothing, nothing, problem, problem_mark)

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

function compose(composer::Composer)
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

function handle_error(composer::Composer, event::Event)
    anchor = event.anchor
    anchor !== nothing && haskey(composer, anchor) && throw(ComposerError(
        "found duplicate anchor '$anchor'; first occurance", firstmark(composer[anchor]),
        "second occurence", firstmark(event),
    ))
    nothing
end

# handle event

function handle_event(composer::Composer, event::AliasEvent)
    anchor = event.anchor
    forward!(composer)
    haskey(composer, anchor) || throw(ComposerError(
        "found undefined alias '$anchor'", firstmark(event),
    ))
    composer[anchor]
end

function handle_event(composer::Composer, event::ScalarEvent)::ScalarNode
    handle_error(composer, event)
    compose_scalar_node(composer, event.anchor)
end

function handle_event(composer::Composer, event::SequenceStartEvent)::SequenceNode
    handle_error(composer, event)
    compose_sequence_node(composer, event.anchor)
end

function handle_event(composer::Composer, event::MappingStartEvent)::MappingNode
    handle_error(composer, event)
    compose_mapping_node(composer, event.anchor)
end

handle_event(composer::Composer, event::Event)::Nothing = nothing

# compose node

function compose_node(composer::Composer)
    event = peek(composer)
    handle_event(composer, event)
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
