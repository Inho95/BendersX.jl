export customize_master_model!, customize_sub_model!, customize_mip_model!, customize_sub_model_gbc!

# function customize_mip_model!(model::Model, data::MCNDPData)
#     optimizer = optimizer_with_attributes(
#         CPLEX.Optimizer, "CPXPARAM_Benders_Strategy" => 0, "CPX_PARAM_PREIND" => 0, "CPXPARAM_Benders_WorkerAlgorithm" => 0)

#     set_optimizer(model, optimizer)
    
#     N, E, K = data.num_nodes, data.num_arcs, data.num_commodities

#     @variable(model, x[1:E], Bin)
#     @variable(model, y[1:E, 1:K] >= 0)
    
#     @objective(model, Min, data.fixed_costs'* x + sum(data.variable_costs[e]*y[e,k] for e in 1:E, k in 1:K))

#     # Add constraints
#     for k in 1:K
#         origin, destination, q = data.demands[k]
#         for node in 1:N
#             infl_idx, outfl_idx = findall(t -> t[2] == node, data.arcs), findall(t -> t[1] == node, data.arcs)
#             if node == origin
#                 @constraint(model, sum(y[e,k] for e in outfl_idx) - sum(y[e,k] for e in infl_idx) == q)
#             elseif node == destination
#                 @constraint(model, sum(y[e,k] for e in outfl_idx) - sum(y[e,k] for e in infl_idx) == -q)
#             else
#                 @constraint(model, sum(y[e,k] for e in outfl_idx) - sum(y[e,k] for e in infl_idx) == 0)
#             end
#         end
#     end
#     @constraint(model, capacity[e in 1:E], sum(y[e,k] for k in 1:K) <= data.capacities[e] * x[e])
# end

# fractional mip
function customize_mip_model!(model::Model, data::MCNDPData)
    # optimizer = optimizer_with_attributes(
    #     CPLEX.Optimizer, "CPXPARAM_Threads" => 7, "CPX_PARAM_EPINT" => 1e-9, "CPX_PARAM_EPRHS" => 1e-9, "CPX_PARAM_EPGAP" => 1e-6, MOI.Silent() => true)

    set_optimizer_attribute(model, "CPXPARAM_Benders_Strategy", 3)
    set_optimizer_attribute(model, "CPXPARAM_Benders_WorkerAlgorithm", 0)
    set_optimizer_attribute(model, "CPXPARAM_Threads", 7)
    
    N, E, K = data.num_nodes, data.num_arcs, data.num_commodities

    @variable(model, x[1:E], Bin)
    @variable(model, y[1:E, 1:K] >= 0)
    
    @objective(model, Min, data.fixed_costs'* x + sum(data.variable_costs[e]*data.demands[k][3]*y[e,k] for e in 1:E, k in 1:K))

    # Add constraints
    for k in 1:K
        origin, destination, q = data.demands[k]
        for node in 1:N
            infl_idx, outfl_idx = findall(t -> t[2] == node, data.arcs), findall(t -> t[1] == node, data.arcs)
            if node == origin
                @constraint(model, sum(y[e,k] for e in outfl_idx) - sum(y[e,k] for e in infl_idx) == 1)
            elseif node == destination
                @constraint(model, sum(y[e,k] for e in outfl_idx) - sum(y[e,k] for e in infl_idx) == -1)
            else
                @constraint(model, sum(y[e,k] for e in outfl_idx) - sum(y[e,k] for e in infl_idx) == 0)
            end
        end
    end
    @constraint(model, capacity[e in 1:E], sum(data.demands[k][3] * y[e,k] for k in 1:K) <= data.capacities[e] * x[e])
    @constraint(model, gbc[e in 1:E, k in 1:K], y[e,k] <= x[e])
end

function customize_master_model!(model::Model, data::MCNDPData)
    optimizer = optimizer_with_attributes(
        CPLEX.Optimizer, "CPXPARAM_Threads" => 7, "CPX_PARAM_EPINT" => 1e-9, "CPX_PARAM_EPRHS" => 1e-9, "CPX_PARAM_EPGAP" => 1e-6, MOI.Silent() => true)

    set_optimizer(model, optimizer)
    
    @variable(model, x[1:data.num_arcs], Bin)
    @variable(model, t >= -1e6)

    @objective(model, Min, data.fixed_costs'* x + t)

    return (x = x, ), t
end

function customize_sub_model!(model::Model, data::MCNDPData, scen_idx::Int; x)
    # optimizer = optimizer_with_attributes(
    #         CPLEX.Optimizer, "CPXPARAM_Threads" => 7, "CPX_PARAM_EPRHS" => 1e-9, "CPX_PARAM_EPOPT" => 1e-9, "CPX_PARAM_NUMERICALEMPHASIS" => 1, MOI.Silent() => true)

    # gurobi GPU
    optimizer = optimizer_with_attributes(
            Gurobi.Optimizer, "Threads" => 7, "Method" => 6, "PDHGGPU" => 1, "Crossover" => 1, "OutputFlag" => 1)

    # CuPDLPx
    # optimizer = optimizer_with_attributes(
    #     CuPDLPx.Optimizer, "verbose" => true, "has_pock_chambolle_alpha" => false, "bound_objective_rescaling" => false, "l_inf_ruiz_iterations" => 10, "iteration_limit" => 999999999)

    set_optimizer(model, optimizer)

    N, E, K = data.num_nodes, data.num_arcs, data.num_commodities

    @variable(model, y[1:E, 1:K] >= 0)
    
    @objective(model, Min, sum(data.variable_costs[e]*y[e,k] for e in 1:E, k in 1:K))

    # Add constraints
    for k in 1:K
        origin, destination, q = data.demands[k]
        for node in 1:N
            infl_idx, outfl_idx = findall(t -> t[2] == node, data.arcs), findall(t -> t[1] == node, data.arcs)
            if node == origin
                @constraint(model, sum(y[e,k] for e in outfl_idx) - sum(y[e,k] for e in infl_idx) == q)
            elseif node == destination
                @constraint(model, sum(y[e,k] for e in outfl_idx) - sum(y[e,k] for e in infl_idx) == -q)
            else
                @constraint(model, sum(y[e,k] for e in outfl_idx) - sum(y[e,k] for e in infl_idx) == 0)
            end
        end
    end
    @constraint(model, capacity[e in 1:E], sum(y[e,k] for k in 1:K) <= data.capacities[e] * x[e])

    return nothing
end

# fractional
# function customize_sub_model!(model::Model, data::MCNDPData, scen_idx::Int; x)
#     optimizer = optimizer_with_attributes(
#         CPLEX.Optimizer, "CPXPARAM_Threads" => 7, "CPX_PARAM_EPRHS" => 1e-9, "CPX_PARAM_EPOPT" => 1e-9, "CPX_PARAM_NUMERICALEMPHASIS" => 1, MOI.Silent() => true)

#     set_optimizer(model, optimizer)

#     N, E, K = data.num_nodes, data.num_arcs, data.num_commodities

#     @variable(model, y[1:E, 1:K] >= 0)
    
#     @objective(model, Min, sum(data.variable_costs[e]*data.demands[k][3]*y[e,k] for e in 1:E, k in 1:K))

#     # Add constraints
#     for k in 1:K
#         origin, destination, q = data.demands[k]
#         for node in 1:N
#             infl_idx, outfl_idx = findall(t -> t[2] == node, data.arcs), findall(t -> t[1] == node, data.arcs)
#             if node == origin
#                 @constraint(model, sum(y[e,k] for e in outfl_idx) - sum(y[e,k] for e in infl_idx) == 1)
#             elseif node == destination
#                 @constraint(model, sum(y[e,k] for e in outfl_idx) - sum(y[e,k] for e in infl_idx) == -1)
#             else
#                 @constraint(model, sum(y[e,k] for e in outfl_idx) - sum(y[e,k] for e in infl_idx) == 0)
#             end
#         end
#     end
#     @constraint(model, capacity[e in 1:E], sum(data.demands[k][3] * y[e,k] for k in 1:K) <= data.capacities[e] * x[e])
#     @constraint(model, gbc[e in 1:E, k in 1:K], y[e,k] <= x[e])

#     return nothing
# end