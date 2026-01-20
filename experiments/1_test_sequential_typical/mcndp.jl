using BendersX
using Test
using JuMP
using CPLEX

@testset verbose = true "MCNDP Sequential Benders Tests" begin
    instances = 1:6

    for i in instances
        @testset "Instance: r01.$i" begin
            # Load problem data
            data = read_mcndp_instance("r01.$i.dow")
            
            # Loop parameters
            benders_param = BendersSeqParam(;
                            time_limit = 200.0,
                            gap_tolerance = 1e-6,
                            verbose = false
                        )

            # Solve MIP for reference
            mip_model = Model()
            customize_mip_model!(mip_model, data)
            optimize!(mip_model)
            @assert termination_status(mip_model) == OPTIMAL
            mip_opt_val = objective_value(mip_model)

            # @testset "Unified oracle" begin
            #     @info "solving MCNDP r01.$i - unified oracle - seq..."
            #     master = Master(data; customize = customize_master_model!)
            #     oracle = UnifiedOracle(data, master; customize = customize_sub_model!)
            #     env = BendersSeq(master, oracle; param = benders_param)
            #     log = solve!(env)
            #     @test env.termination_status == Optimal()
            #     @test isapprox(mip_opt_val, env.obj_value, atol=1e-5)
            # end 

            @testset "Unified oracle with GBC" begin
                @info "solving MCNDP r01.$i - unified oracle - seq..."
                master = Master(data; customize = customize_master_model!)
                oracle = UnifiedOracle(data, master; customize = customize_sub_model_gbc!)
                env = BendersSeq(master, oracle; param = benders_param)
                log = solve!(env)
                @test env.termination_status == Optimal()
                @test isapprox(mip_opt_val, env.obj_value, atol=1e-5)
            end 
        end
    end
end