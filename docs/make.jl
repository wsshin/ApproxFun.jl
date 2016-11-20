using Documenter, ApproxFun

makedocs(modules=[ApproxFun],
			doctest = false,
			clean = true,
			format = :html,
			sitename = "ApproxFun.jl",
			authors = "Sheehan Olver",
			pages = Any[
					"Home" => "index.md"
					]
			)

deploydocs(
    repo   = "github.com/ApproxFun/ApproxFun.jl.git",
    latest = "development",
    julia  = "0.5",
    osname = "linux",
    deps = nothing,
    make = nothing)
