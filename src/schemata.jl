# TODO: Once the other features are completed,
# export these types so that users can call them directly.
#=
export
    AbstractSchema,
    FailsafeSchema,
    JSONSchema,
    CoreSchema,
    YAML_jl_0_4_10_Schema
=#

"""
    AbstractSchema

An abstract type for YAML schemata.
"""
abstract type AbstractSchema end

"""
    FailsafeSchema <: AbstractSchema

The failsafe schema.
"""
struct FailsafeSchema <: AbstractSchema end

"""
    JSONSchema <: AbstractSchema

The JSON schema.
"""
struct JSONSchema <: AbstractSchema end

"""
    CoreSchema <: AbstractSchema

The type of the Core schema. The Core schema is the officially recommended default schema.
"""
struct CoreSchema <: AbstractSchema end

"""
    YAML_jl_0_4_10_Schema <: AbstractSchema

The schema used in YAML.jl v0.4.10.
"""
struct YAML_jl_0_4_10_Schema <: AbstractSchema end
