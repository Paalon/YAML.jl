using Documenter, YAML

makedocs(
    modules=[YAML],
    sitename="YAML.jl",
    pages=[
        "Home" => "index.md",
    ],
)
deploydocs(
    repo="github.com/JuliaData/YAML.jl.git",
)
