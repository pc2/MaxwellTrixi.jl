# Markdown table of the metrics.txt files below a results directory.
#
#   julia ci/metrics_table.jl results

const LINE = r"^maxwelltrixi_(\w+)\{(.*)\} (\S+)$"
const LABEL = r"(\w+)=\"([^\"]*)\""
const CHECK = r"_(relative_error|absolute_error|fraction|plus_reflectance)$"
const SHOWN = ("pid_seconds", "time_per_dof_per_rhs_seconds", "steps")

function read_metrics(path)
    labels = Dict{String, String}()
    values = Pair{String, String}[]
    for line in eachline(path)
        found = match(LINE, line)
        found === nothing && continue
        name, label_text, value = found.captures
        labels = Dict(label.captures[1] => label.captures[2]
                      for label in eachmatch(LABEL, label_text))
        push!(values, name => value)
    end
    return labels, values
end

function number(text)
    value = parse(Float64, text)
    return isinteger(value) ? string(Int(value)) : string(round(value; sigdigits = 3))
end

label(name) = replace(name, r"_(relative|absolute)_error$" => "", "_" => " ")

function main(root)
    files = isdir(root) ?
            sort([joinpath(directory, file)
                  for (directory, _, files) in walkdir(root)
                  for file in files if file == "metrics.txt"]) : String[]
    if isempty(files)
        println("no metrics found")
        return
    end
    println("| Case | Variant | Threads | Checks | PID [s] | time/DOF/RHS [s] | Steps |")
    println("|---|---|---|---|---|---|---|")
    for path in files
        labels, values = read_metrics(path)
        checks = join(("$(label(name)) $(number(value))"
                       for (name, value) in values if occursin(CHECK, name)), ", ")
        cells = [get(labels, "case", basename(dirname(dirname(path)))),
            get(labels, "variant", basename(dirname(path))),
            get(labels, "threads", ""), checks]
        for name in SHOWN
            index = findfirst(pair -> first(pair) == name, values)
            push!(cells, index === nothing ? "" : number(last(values[index])))
        end
        println("| ", join(cells, " | "), " |")
    end
end

main(isempty(ARGS) ? "results" : ARGS[1])
