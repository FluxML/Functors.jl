using Documenter, Functors

DocMeta.setdocmeta!(Functors, :DocTestSetup, :(using Functors); recursive = true)

makedocs(modules = [Functors],
         sitename = "Functors.jl",
         pages = ["Home" => "index.md",
                  "API" => "api.md"],
         format = Documenter.HTML(
             analytics = "UA-36890222-9",
             assets = ["assets/flux.css"],
             prettyurls = get(ENV, "CI", nothing) == "true"),
         )

deploydocs(repo = "github.com/FluxML/Functors.jl.git",
           target = "build",
           push_preview = true)
