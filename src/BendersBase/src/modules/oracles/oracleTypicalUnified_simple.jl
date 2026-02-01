export UnifiedOracle, model_reformulation!

const UnifiedOracleParam = BasicOracleParam

mutable struct UnifiedOracle <: AbstractTypicalOracle
    
    param::UnifiedOracleParam

    model::Model
    w0::Float64

    function UnifiedOracle(data::AbstractData, master::Master; 
                            customize = customize_sub_model!,
                            scen_idx::Int=0, 
                            param::UnifiedOracleParam = UnifiedOracleParam(), 
                            w0::Float64 = 1.0)
    
            @debug "Building unified oracle"
            model = Model()

            # Copy the master’s coupling variables into the submodel (with identical axes and symbols)
            x_copy = copy_variables!(model, master.x_tuple)

            # Build the submodel using user-defined customization, passing the copied variables
            customize(model, data, scen_idx; x_copy...)

            # Collect all copied master variables and add linking constraint
            x = var_from_tuple(x_copy)

            # Reformulate subproblem
            model_reformulation!(model, w0; x)

            new(param, model, w0)
    end

    UnifiedOracle() = new()
end

function generate_cuts(oracle::UnifiedOracle, x_value::Vector{Float64}, t_value::Vector{Float64}; tol_normalize = 1.0, time_limit = 3600)
    set_time_limit_sec(oracle.model, time_limit)
    
    set_normalized_rhs.(oracle.model[:fix_x_lb], x_value)
    set_normalized_rhs.(oracle.model[:fix_x_ub], -x_value)
    set_normalized_rhs.(oracle.model[:epigraph], -t_value)

    optimize!(oracle.model)
    
    if termination_status(oracle.model) == TIME_LIMIT
        throw(TimeLimitException("Time limit reached during cut generation"))
    elseif termination_status(oracle.model) != OPTIMAL
        throw(UnexpectedModelStatusException("UnifiedOracle: $(termination_status(oracle.model)). This is likely a numerical issue."))
    end

    a_x = dual.(oracle.model[:fix_x_lb]) .- dual.(oracle.model[:fix_x_ub])
    a_t = [-dual(oracle.model[:epigraph])]
    a_0 = objective_value(oracle.model) - a_x'*x_value + dual(oracle.model[:epigraph])*t_value[1]
    
    return isapprox(dual_objective_value(oracle.model), 0, atol=oracle.param.zero_tol) ? (true, [Hyperplane(a_x, a_t, a_0)], [t_value[1]]) : (false, [Hyperplane(a_x, a_t, a_0)], [Inf])
end

function model_reformulation!(model::Model, w0::Float64; x)
    # Weight in dual problem
    @variable(model, z)

    # Add epigraph constraint
    @constraint(model, epigraph, w0 * z .- objective_function(model) .>= 0)

    # Change objective function
    @objective(model, Min, z)

    # Linking constraints
    @constraint(model, fix_x_lb, z .+ x .>= 0)
    @constraint(model, fix_x_ub, z .- x .>= 0)
end




