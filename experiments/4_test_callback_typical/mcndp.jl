using BendersX
using Test
using JuMP
using CPLEX

@testset verbose = true "MCNDP Callback Benders Tests" begin
    instances = 1:6
    
    for i in instances
        @testset "Instance: r01.$i" begin
            # Load problem data
            data = read_mcndp_instance("r01.$i.dow")

            # BnB parameters
            benders_param = BendersBnBParam(;
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
            #     @testset "NoSeq" begin
            #         @info "solving MCNDP p$i - unified oracle - no seq..."
            #         # This setting can use default initializer
            #         master = Master(data; customize = customize_master_model!)
            #         oracle = UnifiedOracle(data, master; customize = customize_sub_model!)

            #         # root_preprocessing = NoRootNodePreprocessing()
            #         # lazy_callback = LazyCallback(oracle)
            #         # user_callback = NoUserCallback()
            #         # env = BendersBnB(master, root_preprocessing, lazy_callback, user_callback; param = benders_param)

            #         env = BendersBnB(master, oracle; param = benders_param)
            #         log = solve!(env)
            #         @test env.termination_status == Optimal()
            #         @test isapprox(mip_opt_val, env.obj_value, atol=1e-5)
            #     end

            #     @testset "Seq" begin
            #         @info "solving MCNDP p$i - unified oracle - seq..."
            #         master = Master(data; customize = customize_master_model!)
            #         oracle = UnifiedOracle(data, master; customize = customize_sub_model!)

            #         root_seq_type = BendersSeq
            #         root_param = BendersSeqParam(;
            #                     time_limit = 200.0,
            #                     gap_tolerance = 1e-9,
            #                     verbose = false
            #                 )

            #         root_preprocessing = RootNodePreprocessing(oracle, root_seq_type, root_param)
            #         lazy_callback = LazyCallback(oracle)
            #         user_callback = NoUserCallback()

            #         env = BendersBnB(master, root_preprocessing, lazy_callback, user_callback; param = benders_param)
            #         log = solve!(env)
            #         @test env.termination_status == Optimal()
            #         @test isapprox(mip_opt_val, env.obj_value, atol=1e-5)
            #     end

            #     @testset "SeqInOut" begin
            #         @info "solving MCNDP p$i - unified oracle - seqinout..."
            #         master = Master(data; customize = customize_master_model!)
            #         oracle = UnifiedOracle(data, master; customize = customize_sub_model!)

            #         root_seq_type = BendersSeqInOut
            #         root_param = BendersSeqInOutParam(
            #                     time_limit = 300.0,
            #                     gap_tolerance = 1e-9,
            #                     stabilizing_x = ones(data.num_arcs),
            #                     α = 0.9,
            #                     λ = 0.1,
            #                     verbose = false
            #                 )

            #         root_preprocessing = RootNodePreprocessing(oracle, root_seq_type, root_param)
            #         lazy_callback = LazyCallback(oracle)
            #         user_callback = NoUserCallback()

            #         env = BendersBnB(master, root_preprocessing, lazy_callback, user_callback; param = benders_param)
            #         log = solve!(env)
            #         @test env.termination_status == Optimal()
            #         @test isapprox(mip_opt_val, env.obj_value, atol=1e-5)
            #     end
            # end

            @testset "Unified oracle" begin
                @testset "NoSeq" begin
                    @info "solving MCNDP p$i - unified oracle - no seq..."
                    # This setting can use default initializer
                    master = Master(data; customize = customize_master_model!)
                    oracle = UnifiedOracle(data, master; customize = customize_sub_model_gbc!)

                    # root_preprocessing = NoRootNodePreprocessing()
                    # lazy_callback = LazyCallback(oracle)
                    # user_callback = NoUserCallback()
                    # env = BendersBnB(master, root_preprocessing, lazy_callback, user_callback; param = benders_param)

                    env = BendersBnB(master, oracle; param = benders_param)
                    log = solve!(env)
                    @test env.termination_status == Optimal()
                    @test isapprox(mip_opt_val, env.obj_value, atol=1e-5)
                end

                @testset "Seq" begin
                    @info "solving MCNDP p$i - unified oracle - seq..."
                    master = Master(data; customize = customize_master_model!)
                    oracle = UnifiedOracle(data, master; customize = customize_sub_model_gbc!)

                    root_seq_type = BendersSeq
                    root_param = BendersSeqParam(;
                                time_limit = 200.0,
                                gap_tolerance = 1e-9,
                                verbose = false
                            )

                    root_preprocessing = RootNodePreprocessing(oracle, root_seq_type, root_param)
                    lazy_callback = LazyCallback(oracle)
                    user_callback = NoUserCallback()

                    env = BendersBnB(master, root_preprocessing, lazy_callback, user_callback; param = benders_param)
                    log = solve!(env)
                    @test env.termination_status == Optimal()
                    @test isapprox(mip_opt_val, env.obj_value, atol=1e-5)
                end

                @testset "SeqInOut" begin
                    @info "solving MCNDP p$i - unified oracle - seqinout..."
                    master = Master(data; customize = customize_master_model!)
                    oracle = UnifiedOracle(data, master; customize = customize_sub_model_gbc!)

                    root_seq_type = BendersSeqInOut
                    root_param = BendersSeqInOutParam(
                                time_limit = 300.0,
                                gap_tolerance = 1e-9,
                                stabilizing_x = ones(data.num_arcs),
                                α = 0.9,
                                λ = 0.1,
                                verbose = false
                            )

                    root_preprocessing = RootNodePreprocessing(oracle, root_seq_type, root_param)
                    lazy_callback = LazyCallback(oracle)
                    user_callback = NoUserCallback()

                    env = BendersBnB(master, root_preprocessing, lazy_callback, user_callback; param = benders_param)
                    log = solve!(env)
                    @test env.termination_status == Optimal()
                    @test isapprox(mip_opt_val, env.obj_value, atol=1e-5)
                end
            end
        end
    end
end