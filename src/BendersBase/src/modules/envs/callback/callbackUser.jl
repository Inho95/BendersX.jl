export UserCallbackParam, UserCallback

"""
    UserCallbackParam <: AbstractUserCallbackParam

Parameters for user callbacks in the branch-and-bound process.

# Fields
- `frequency::Int = 50`: How often to process nodes (every N fractional nodes)
- `node_count::Int = -1`: Only process nodes after this node count (-1 means process all)
- `depth::Int = -1`: Only process nodes with depth >= this value (-1 means process all depths)
"""
Base.@kwdef struct UserCallbackParam <: AbstractUserCallbackParam
    frequency::Int = 50
    node_count::Int = -1
    depth::Int = -1
end


"""
    UserCallback <: AbstractUserCallback

Configuration for user cut callbacks in the branch-and-bound process.
Used to dynamically add Benders cuts at fractional nodes.

# Fields
- `params::UserCallbackParam`: Parameters controlling when cuts are generated
- `oracle::AbstractOracle`: Oracle used to generate Benders cuts
"""
struct UserCallback <: AbstractUserCallback
    params::UserCallbackParam
    oracle::AbstractOracle
    
    function UserCallback(oracle::AbstractOracle; params=UserCallbackParam())
        new(params, oracle)
    end
end

"""
    user_callback(cb_data, master::Master, log::BendersBnBLog, callback::UserCallback)

Callback function for adding user cuts in the branch-and-bound process.
Generates and adds Benders cuts at fractional nodes based on the specified frequency and criteria.

# Arguments
- `cb_data`: Callback data from the solver
- `master::Master`: The master module
- `log::BendersBnBLog`: Log object to record statistics
- `param::BendersBnBParam`: Parameters for the branch-and-bound process
- `callback::UserCallback`: Configuration for the user callback with parameters controlling when cuts are generated
"""
function user_callback(cb_data, master::Master, log::BendersBnBLog, param::BendersBnBParam, callback::UserCallback)
    status = JuMP.callback_node_status(cb_data, master.model)
    
    if status == MOI.CALLBACK_NODE_STATUS_FRACTIONAL
        log.num_of_fraction_node += 1
        
        # Check if we should process this node based on frequency
        if log.num_of_fraction_node >= callback.params.frequency
            log.num_of_fraction_node = 0
            
            # Get node information if using CPLEX
            process_node = true
            if solver_name(master.model) == "CPLEX" && (callback.params.node_count != -1 || callback.params.depth != -1)
                n_count = Ref{CPXINT}()
                node_depth = Ref{CPXINT}()
                CPXcallbackgetinfoint(cb_data, CPXCALLBACKINFO_NODECOUNT, n_count)
                CPXcallbackgetinfoint(cb_data, CPXCALLBACKINFO_NODEDEPTH, node_depth)
                
                # Check if node meets criteria
                if (callback.params.node_count != -1 && n_count[] > callback.params.node_count) || 
                   (callback.params.depth != -1 && node_depth[] > callback.params.depth)
                    process_node = false
                end
            elseif (callback.params.node_count != -1 || callback.params.depth != -1) && solver_name(master.model) != "CPLEX"
                @warn "node_count and depth parameters are not supported for $(solver_name(master.model)) solver"
            end
            
            if process_node
                node_depth = Ref{CPXINT}()
                CPXcallbackgetinfoint(cb_data, CPXCALLBACKINFO_NODEDEPTH, node_depth)
                @info "node depth", node_depth[]

                # Create state and get current variable values
                state = BendersBnBState()
                state.values[:x] = JuMP.callback_value.(cb_data, master.x)
                state.values[:t] = JuMP.callback_value.(cb_data, master.t)
                
                @assert CPXcallbackgetlocallb(cb_data, callback.oracle.lb, 0, length(state.values[:x]) - 1) == 0
                @assert CPXcallbackgetlocalub(cb_data, callback.oracle.ub, 0, length(state.values[:x]) - 1) == 0

                # Generate cuts
                pattern_add = false
                state.oracle_time = @elapsed begin
                    state.is_in_L, hyperplanes, state.f_x = generate_cuts(callback.oracle, state.values[:x], state.values[:t]; time_limit = get_sec_remaining(log, param))
                    if isempty(hyperplanes) && isempty(state.f_x)
                        nogood = no_good(master.model, callback.oracle.zero_indices, callback.oracle.one_indices, master.x)
                        cuts = [nogood]
                        push!(param.forbidden_pattern, (copy(callback.oracle.zero_indices), copy(callback.oracle.one_indices)))
                        println("no-good")
                        pattern_add = true
                    else
                        cuts = !state.is_in_L ? hyperplanes_to_expression(master.model, hyperplanes, master.x, master.t) : []
                        state.num_cuts += length(hyperplanes)
                        println("disjunctive")
                    end
                end

                # Check forbidden pattern
                if !isempty(param.forbidden_pattern) && !pattern_add
                    for (zero_indices, one_indices) in param.forbidden_pattern
                        tol = 1e-6
                        matches = all(abs.(state.values[:x][zero_indices]) .<= tol) && all(abs.(state.values[:x][one_indices] .- 1) .<= tol)
                        if matches
                            println("forbidden pattern found in user")
                        end
                    end
                end

                # Add cuts
                for cut in cuts
                    cut_constraint = @build_constraint(0 >= cut)
                    MOI.submit(master.model, MOI.UserCut(cb_data), cut_constraint)
                end
                
                # Record node information
                record_node!(log, state, false)
            end
        end
    end
end