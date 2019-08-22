module JuliaSkriptumKontrolle

export @Aufgabe

const exercise_data_dir = joinpath(@__DIR__,"..","exercise_data")

check_functions = Dict{String,Function}()
check_function_passed = Dict{String,Bool}()
setup_functions = Dict{String,Function}()

function setup(identifier::AbstractString;force::Bool=false)
    # Copy data dir if exists
    data_dir = joinpath(exercise_data_dir,identifier)
    isdir(data_dir) && cp(data_dir,joinpath(pwd(),identifier),force=force)
    # Call setup function
    identifier in keys(setup_functions) && setup_functions[identifier]()
end

macro Aufgabe(identifier::AbstractString, expr)
    @assert identifier in keys(check_functions) "Aufgabe $identifier nicht gefunden!"
    check_function = check_functions[identifier]
    result = eval_sandboxed(expr)
    quote
        JuliaSkriptumKontrolle.reset_passed($identifier)
        JuliaSkriptumKontrolle.setup($identifier,force=true)
        $check_function($result)
        JuliaSkriptumKontrolle.passed($identifier)
    end
end

macro Aufgabe(expr::Expr)
    error("Aufgabennummer nicht angegeben. Das Format ist @Aufgabe \"x.y.z\" ...")
end

function reset_passed(identifier::AbstractString)
    check_function_passed[identifier] = false
end

function passed(identifier::AbstractString)
    @assert identifier in keys(check_functions) "Aufgabe $identifier nicht gefunden!"
    check_function_passed[identifier] = true
    nothing
end

function sandbox()
    sandbox_name = "SB_$(splitext(basename(tempname())) |> first)"
    Core.eval(Main, Meta.parse("module $(sandbox_name)\nend"))
end

eval_sandboxed(expr::Expr) = Core.eval(sandbox(),expr)

function run_redirected(f::Function;input::Vector{<:AbstractString}=String[],output::Vector{<:AbstractString}=String[])
    _stdin = stdin
    _stdout = stdout
    try
        (in_rd,in_wr) = redirect_stdin()
        (out_rd,out_wr) = redirect_stdout()
        # Write input into stdin buffer
        println.(Ref(in_wr),input)
        res = f()
        redirect_stdin(_stdin)
        redirect_stdout(_stdout)
        close(out_wr)
        # Push to output
        push!.(Ref(output),readlines(out_rd))
        close(out_rd)
        close(in_rd)
        close(in_wr)
        return res
    catch e
        redirect_stdin(_stdin)
        redirect_stdout(_stdout)
        close(out_wr)
        close(out_rd)
        close(in_rd)
        close(in_wr)
        rethrow(e)
    end
end

end # module
