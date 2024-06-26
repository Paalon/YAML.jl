
# Position within the document being parsed
struct Mark
    index::UInt64
    line::UInt64
    column::UInt64
end


function show(io::IO, mark::Mark)
    @printf(io, "line %d, column %d", mark.line, mark.column)
end


# Where in the stream a particular token lies.
struct Span
    start_mark::Mark
    end_mark::Mark
end


# YAML Tokens.
# Each token must include at minimum member "span::Span".
abstract type Token end


# The '%YAML' directive.
struct DirectiveToken <: Token
    span::Span
    name::String
    value::Union{Tuple, Nothing}
end

# '---'
struct DocumentStartToken <: Token
    span::Span
end

# '...'
struct DocumentEndToken <: Token
    span::Span
end

# '\uFEFF'
struct ByteOrderMarkToken <: Token
    span::Span
end

# The stream start
struct StreamStartToken <: Token
    span::Span
    encoding::String
end

# The stream end
struct StreamEndToken <: Token
    span::Span
end

#
struct BlockSequenceStartToken <: Token
    span::Span
end

#
struct BlockMappingStartToken <: Token
    span::Span
end

#
struct BlockEndToken <: Token
    span::Span
end

# '['
struct FlowSequenceStartToken <: Token
    span::Span
end

# '{'
struct FlowMappingStartToken <: Token
    span::Span
end

# ']'
struct FlowSequenceEndToken <: Token
    span::Span
end

# '}'
struct FlowMappingEndToken <: Token
    span::Span
end

# '?' or nothing (simple keys).
struct KeyToken <: Token
    span::Span
end

# ':'
struct ValueToken <: Token
    span::Span
end

# '-'
struct BlockEntryToken <: Token
    span::Span
end

# ','
struct FlowEntryToken <: Token
    span::Span
end

# '*anchor'
struct AliasToken <: Token
    span::Span
    value::String
end

# '&anchor'
struct AnchorToken <: Token
    span::Span
    value::String
end

# '!handle!suffix'
struct TagToken <: Token
    span::Span
    value
end

# A scalar.
struct ScalarToken <: Token
    span::Span
    value::String
    plain::Bool
    style::Union{Char, Nothing}
end
