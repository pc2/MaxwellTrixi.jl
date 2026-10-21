using Documenter, Trixi, MaxwellTrixi

DocMeta.setdocmeta!(MaxwellTrixi, :DocTestSetup,
                    :(using Trixi, MaxwellTrixi); recursive = true)

# Pages reference committed figures. Use matching videos when available;
# Documenter renders Markdown images ending in .mp4 as native video players.
mktempdir() do temporary
    source = joinpath(temporary, "src")
    cp(joinpath(@__DIR__, "src"), source)
    mkpath(joinpath(source, "assets"))
    for kind in ("figures", "videos")
        directory = joinpath(@__DIR__, kind)
        isdir(directory) && cp(directory, joinpath(source, "assets", kind))
    end
    media = r"^!\[([^\]]*)\]\((?:\.\./)*assets/figures/([a-z0-9_]+)\.png\)$"m
    for (directory, _, files) in walkdir(source), file in files
        endswith(file, ".md") || continue
        page = joinpath(directory, file)
        text = replace(read(page, String),
                       media => function (entry)
                           alt, name = match(media, entry).captures
                           video = joinpath(source, "assets", "videos", "$name.mp4")
                           if isfile(video)
                               relative = replace(relpath(video, directory), '\\' => '/')
                               return "![$alt]($relative)"
                           end
                           return entry
                       end)
        write(page, text)
    end

    makedocs(; root = @__DIR__, source, build = joinpath(@__DIR__, "build"),
             sitename = "MaxwellTrixi.jl", modules = [MaxwellTrixi],
             checkdocs = :exports,
             format = Documenter.HTML(; prettyurls = true, edit_link = nothing,
                                      size_threshold = 500_000),
             pages = ["Overview" => "index.md",
                 "Equations and materials" => "equations.md",
                 "DG discretization" => "numerics.md",
                 "Sources and boundaries" => "sources.md",
                 "Meshes and output" => "meshes.md",
                 "Diagnostics and validation" => "diagnostics.md",
                 "Figures and videos" => "visuals.md",
                 "Validation and performance" => "hpc.md",
                 "Building and publishing" => "building.md",
                 "API index" => "reference.md"])
end
