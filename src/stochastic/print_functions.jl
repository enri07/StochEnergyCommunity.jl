"""
PRINT FILE, containin all the functions to store results in the first,second and third stage
""" 

"""
    print_first_stage(output_file::String, ECModel::StochasticEC)

Export the results of the first-stage stochastic optimization to an Excel file.

# Arguments
- `output_file::String`: Path to the output Excel file where results will be saved
- `ECModel::StochasticEC`: The stochastic energy community model containing optimization results

# Excel Sheets Created
The function creates an Excel file with the following sheets:
1. **info solution**: General solution information (configuration, computation time, exit flag, gap, number of scenarios, objective value)
2. **design users**: Installed capacity design for each user and the EC aggregator
3. **info scenarios**: Scenario-specific information (scenario indices, probabilities, social welfare, shared power)
4. **economic data**: Economic metrics (CAPEX, O&M costs, replacement costs, revenues, generation costs, grid costs, rewards, peak costs)
5. **forecast dispatch**: Forecasted power declarations (P_dec_P and P_dec_N) for each scenario
6. **energy dispatch**: Detailed energy flows (load demand, grid exchanges, renewable production, generator output, converter power) for each scenario

# Notes
- Results are organized by user and scenario
- For GroupCO configuration, aggregator-level results are included
- For GroupNC configuration, individual user grid exchanges are reported
- All energy values are converted to appropriate units (kWh) using time resolution and energy weight
- Subscript notation is used for scenario indexing in column names
"""
function print_stochastic_results(output_file::String,
        ECModel::StochasticEC)

    users_data = ECModel.users_data
    gen_data = ECModel.gen_data
    market_data = ECModel.market_data

    user_set = ECModel.user_set
    user_set_EC = vcat(EC_CODE, user_set)
    n_users = length(user_set)

    init_step = field(gen_data, "init_step")
    final_step = field(gen_data, "final_step")
    n_steps = final_step - init_step + 1

    project_lifetime = field(gen_data, "project_lifetime")
    year_set = 1:project_lifetime
    time_set = 1:n_steps

    energy_weight = profile(market_data, "energy_weight")[1]
    time_res = profile(market_data, "time_res")[1]

    d_model = ECModel.deterministic_model # JuMP model

    scenarios = ECModel.scenarios

    set_asset = unique([name for u in user_set for name in device_names(users_data[u])])

    # get general data solutions
    gap = MOI.get(d_model,MOI.RelativeGap())*100
    _solve_time = solve_time(d_model)
    _termination_status = Int(termination_status(d_model))
    _n_scen_s = ECModel.n_scen_s
    _n_scen_eps = ECModel.n_scen_eps

    _n_scen = _n_scen_s * _n_scen_eps
    # get the installed capacities for users and EC
    _x_us_EC = calculate_x_tot(ECModel)

    # get the total load demand in the scenarios considered
    load_demand = calculate_demand(ECModel)

    # subscript label (used in the results array)
    num_sub = Array{String}(undef,_n_scen)
    for i = 1:_n_scen
        if i<10
            num_sub[i] = string(Char(0x02080+i))
        else
            first_n = (i - mod(i,10))/10
            second_n = mod(i,10)
            num_sub[i] = Char(0x02080+first_n)*Char(0x02080+second_n)
        end
    end

    info_solution = DataFrames.DataFrame(configuration = name(get_group_type(ECModel)),
                        comp_time = _solve_time, 
                        exit_flag=_termination_status, 
                        primal_gap = gap,
                        n_scen_s = _n_scen_s,
                        n_scen_eps = _n_scen_eps,
                        obj_value = sum(ECModel.results[Symbol("SW"*num_sub[scen])] * probability(scenarios[scen]) for scen = 1:_n_scen))
    
    design_users = DataFrames.DataFrame(
        vcat(
            [[u for u in user_set_EC]],
            [[(u == EC_CODE) ? _x_us_EC[u, a] : 
                (a in device_names(users_data[u])) ? _x_us_EC[u, a] * field_component(users_data[u], a, "nom_capacity") : missing
                    for u in user_set_EC]
                        for a in set_asset]
        ),
        map(Symbol, vcat("User id", ["x_us_$a (x^{$a,U})" for a in set_asset]))
    )

    info_scenarios = DataFrames.DataFrame(
        vcat(
            [[convert_scen(_n_scen_s,_n_scen_eps,scen)[1] for scen = 1:_n_scen]],
            [[convert_scen(_n_scen_s,_n_scen_eps,scen)[2] for scen = 1:_n_scen]],
            [[probability(scenarios[scen]) for scen = 1:_n_scen]],
            [[ECModel.results[Symbol("SW"*num_sub[scen])] for scen = 1:_n_scen]],
            [[(get_group_type(ECModel) == GroupCO()) ? sum(ECModel.results[Symbol("P_shared_agg"*num_sub[scen])]) * time_res * energy_weight : missing for scen = 1:_n_scen]],
            [[(get_group_type(ECModel) == GroupCO()) ? sum(ECModel.results[Symbol("P_sq_P_agg"*num_sub[scen])]) * time_res * energy_weight : missing for scen = 1:_n_scen]],
            [[(get_group_type(ECModel) == GroupCO()) ? sum(ECModel.results[Symbol("P_sq_N_agg"*num_sub[scen])]) * time_res * energy_weight : missing for scen = 1:_n_scen]]
        ),
        map(Symbol, vcat("Scenario s","Scenario epsilon", "Scenario probability", "SW Scenario", "tot_P_shared", "tot_sq_P_agg","tot_sq_N_agg"))
    )

    economic_data = DataFrames.DataFrame(
        vcat(
            [[u for u in user_set]],
            [[ECModel.results[:CAPEX_tot_us][u] for u in user_set]],
            [[ECModel.results[:C_OEM_tot_us][u] for u in user_set]],
            [[ECModel.results[:C_REP_tot_us][y,u] for u in user_set] for y in year_set],
            [[ECModel.results[:R_RV_tot_us][y,u] for u in user_set] for y in year_set],
            [[ECModel.results[Symbol("R_Energy_tot_us" * num_sub[scen])].data[u] for u = 1:n_users] for scen = 1:_n_scen],
            [[ECModel.results[Symbol("C_gen_tot_us" * num_sub[scen])].data[u] for u = 1:n_users] for scen = 1:_n_scen],
            [[(get_group_type(ECModel) == GroupCO()) ? ECModel.results[Symbol("C_sq_tot_agg" * num_sub[scen])]/n_users :
                ECModel.results[Symbol("C_sq_tot_us" * num_sub[scen])].data[u] for u = 1:n_users] 
                    for scen = 1:_n_scen],
            [[(get_group_type(ECModel) == GroupCO()) ? ECModel.results[Symbol("R_Reward_agg_NPV" * num_sub[scen])]/n_users : missing for u = 1:n_users] for scen = 1:_n_scen],
            [[ECModel.results[Symbol("C_Peak_tot_us" * num_sub[scen])].data[u] for u = 1:n_users] for scen = 1:_n_scen]
        ),
        map(Symbol, vcat("User id",
                "CAPEX_tot_us",
                "C_OEM_tot_us",
                ["C_REP_tot_us_year_$y" for y in year_set],
                ["R_RV_tot_us_year_$y" for y in year_set],
                ["R_Energy_tot_us_($(convert_scen(_n_scen_s,_n_scen_eps,scen)[1]),$(convert_scen(_n_scen_s,_n_scen_eps,scen)[2]))" for scen = 1:_n_scen],
                ["C_gen_tot_us_($(convert_scen(_n_scen_s,_n_scen_eps,scen)[1]),$(convert_scen(_n_scen_s,_n_scen_eps,scen)[2]))" for scen = 1:_n_scen],
                ["C_Sq_tot_us_($(convert_scen(_n_scen_s,_n_scen_eps,scen)[1]),$(convert_scen(_n_scen_s,_n_scen_eps,scen)[2]))" for scen = 1:_n_scen],
                ["R_reward_agg_NPV_($(convert_scen(_n_scen_s,_n_scen_eps,scen)[1]),$(convert_scen(_n_scen_s,_n_scen_eps,scen)[2]))" for scen = 1:_n_scen],
                ["C_peak_tot_us_($(convert_scen(_n_scen_s,_n_scen_eps,scen)[1]),$(convert_scen(_n_scen_s,_n_scen_eps,scen)[2]))" for scen = 1:_n_scen]
            )
        )
    )
    
    if ECModel.group_type == GroupNC() # Non Cooperative version
        forecast_dispatch = DataFrames.DataFrame(
            vcat(
                [[u for u in user_set]],
                [[sum(ECModel.results[:P_us_dec_P].data,dims=3)[u,scen] * time_res * energy_weight for u = 1:n_users] for scen = 1:_n_scen_s],
                [[sum(ECModel.results[:P_us_dec_N].data,dims=3)[u,scen] * time_res * energy_weight for u = 1:n_users] for scen = 1:_n_scen_s]
            ),
            map(Symbol, vcat("User id",
                    ["P_dec_P_($(convert_scen(_n_scen_s,_n_scen_eps,scen)[1]),$(convert_scen(_n_scen_s,_n_scen_eps,scen)[2]))" for scen = 1:_n_scen_s],
                    ["P_dec_N_($(convert_scen(_n_scen_s,_n_scen_eps,scen)[1]),$(convert_scen(_n_scen_s,_n_scen_eps,scen)[2]))" for scen = 1:_n_scen_s]
                )
            )
        )
    else
        forecast_dispatch = DataFrames.DataFrame(
            vcat(
                [[s for s = 1:_n_scen_s]],
                [[sum(ECModel.results[Symbol("P_agg_dec_P")].data,dims=2)[scen] * time_res * energy_weight for scen = 1:_n_scen_s]],
                [[sum(ECModel.results[Symbol("P_agg_dec_N")].data,dims=2)[scen] * time_res * energy_weight for scen = 1:_n_scen_s]]
            ),
            map(Symbol, vcat("Scenario s","P_dec_P","P_dec_N"
                )
            )
        )
    end

    energy_dispatch = DataFrames.DataFrame(
        vcat(
            [[u for u in user_set]],
            [[load_demand[scen][u] for u in user_set] for scen = 1:_n_scen],
            [[sum(ECModel.results[Symbol("P_P_us" * num_sub[scen])][u,t] for t in time_set) * time_res * energy_weight for u in user_set] for scen = 1:_n_scen],
            [[sum(ECModel.results[Symbol("P_N_us" * num_sub[scen])][u,t] for t in time_set) * time_res * energy_weight for u in user_set] for scen = 1:_n_scen],
            [[(get_group_type(ECModel) == GroupNC()) ? sum(ECModel.results[Symbol("P_sq_P_us" * num_sub[scen])][u,t] for t in time_set) * time_res * energy_weight : missing for u in user_set] for scen = 1:_n_scen],
            [[(get_group_type(ECModel) == GroupNC()) ? sum(ECModel.results[Symbol("P_sq_N_us" * num_sub[scen])][u,t] for t in time_set) * time_res * energy_weight : missing for u in user_set] for scen = 1:_n_scen],
            [[sum(ECModel.results[Symbol("P_ren_us" * num_sub[scen])][u,t] for t in time_set) * time_res * energy_weight for u in user_set] for scen = 1:_n_scen],
            [[(has_asset(users_data[u], THER)) ?  sum(ECModel.results[Symbol("P_gen_us" * num_sub[scen])][u,g,t] for t in time_set for g in asset_names(users_data[u],THER)) * time_res * energy_weight : missing
                for u in user_set] 
                    for scen = 1:_n_scen],
            [[(has_asset(users_data[u], CONV)) ?  sum(ECModel.results[Symbol("P_conv_P_us" * num_sub[scen])][u,c,t] for t in time_set for c in asset_names(users_data[u],CONV)) * time_res * energy_weight : missing
                    for u in user_set] 
                        for scen = 1:_n_scen],
            [[(has_asset(users_data[u], CONV)) ?  sum(ECModel.results[Symbol("P_conv_N_us" * num_sub[scen])][u,c,t] for t in time_set for c in asset_names(users_data[u],CONV)) * time_res * energy_weight : missing
                    for u in user_set] 
                        for scen = 1:_n_scen]
            
        ),
        map(Symbol, vcat("User id",
            ["load_demand_($(convert_scen(_n_scen_s,_n_scen_eps,scen)[1]),$(convert_scen(_n_scen_s,_n_scen_eps,scen)[2]))" for scen = 1:_n_scen],
            ["P_P_us_($(convert_scen(_n_scen_s,_n_scen_eps,scen)[1]),$(convert_scen(_n_scen_s,_n_scen_eps,scen)[2]))" for scen = 1:_n_scen],
            ["P_N_us_($(convert_scen(_n_scen_s,_n_scen_eps,scen)[1]),$(convert_scen(_n_scen_s,_n_scen_eps,scen)[2]))" for scen = 1:_n_scen],
            ["P_sq_P_us_($(convert_scen(_n_scen_s,_n_scen_eps,scen)[1]),$(convert_scen(_n_scen_s,_n_scen_eps,scen)[2]))" for scen = 1:_n_scen],
            ["P_sq_N_us_($(convert_scen(_n_scen_s,_n_scen_eps,scen)[1]),$(convert_scen(_n_scen_s,_n_scen_eps,scen)[2]))" for scen = 1:_n_scen],
            ["P_ren_us_($(convert_scen(_n_scen_s,_n_scen_eps,scen)[1]),$(convert_scen(_n_scen_s,_n_scen_eps,scen)[2]))" for scen = 1:_n_scen],
            ["P_gen_us_($(convert_scen(_n_scen_s,_n_scen_eps,scen)[1]),$(convert_scen(_n_scen_s,_n_scen_eps,scen)[2]))" for scen = 1:_n_scen],
            ["P_conv_P_us_($(convert_scen(_n_scen_s,_n_scen_eps,scen)[1]),$(convert_scen(_n_scen_s,_n_scen_eps,scen)[2]))" for scen = 1:_n_scen],
            ["P_conv_N_us_($(convert_scen(_n_scen_s,_n_scen_eps,scen)[1]),$(convert_scen(_n_scen_s,_n_scen_eps,scen)[2]))" for scen = 1:_n_scen]
            )
        )
    )

    XLSX.openxlsx(output_file, mode="w") do xf

        xs = xf[1]
        XLSX.rename!(xs, "info solution")
        XLSX.writetable!(xs, collect(DataFrames.eachcol(info_solution)),
            DataFrames.names(info_solution))
            
        xs = XLSX.addsheet!(xf, "design users") 
        XLSX.writetable!(xs, collect(DataFrames.eachcol(design_users)),
        DataFrames.names(design_users))

        xs = XLSX.addsheet!(xf, "info scenarios") 
        XLSX.writetable!(xs, collect(DataFrames.eachcol(info_scenarios)),
        DataFrames.names(info_scenarios))

        xs = XLSX.addsheet!(xf, "economic data") 
        XLSX.writetable!(xs, collect(DataFrames.eachcol(economic_data)),
        DataFrames.names(economic_data))

        xs = XLSX.addsheet!(xf, "forecast dispatch") 
        XLSX.writetable!(xs, collect(DataFrames.eachcol(forecast_dispatch)),
        DataFrames.names(forecast_dispatch))

        xs = XLSX.addsheet!(xf, "energy dispatch") 
        XLSX.writetable!(xs, collect(DataFrames.eachcol(energy_dispatch)),
        DataFrames.names(energy_dispatch))
    end
end


"""
    plot_resource(output_file::String, asset, ..)

    Plot the installed capacity by each user and community for the resources in asset
"""
function plot_resource(
    output_file::String,
    asset::Array{String},
    users_data,
    x_CO,
    x_NC,
    colors
    )

    user_set = collect(keys(users_data))
    n_users = length(user_set)
    n_resource = length(asset)

    max_installed_us_CO = maximum((has_asset(users_data[u], a)) ? x_CO[u,a] : 0.0 for u in user_set for a in asset)
    max_installed_us_NC = maximum((has_asset(users_data[u], a)) ? x_NC[u,a] : 0.0 for u in user_set for a in asset)
    max_installed_us = max(max_installed_us_CO,max_installed_us_NC)

    # Create the grid for the plot
    f = Figure(size = (1500, 400))

    gEC = f[1,1] = GridLayout()
    gusers = f[1,2:n_users+1] = GridLayout()
    gLegend = f[1,n_users+2] = GridLayout()

    # adding barplot for EC
    axEC = Axis(gEC[1,1],
        ylabel = "Capacity [kW]",
        xticks = (1:2, ["CO","NC"]))
    
    Label(gEC[1,1,Top()], "Community", valign = :bottom, font = :bold, padding = (0, 0, 5, 0))

    for j = 1:n_resource
        barplot!(axEC, [1,2], [x_CO[EC_CODE, asset[j]],x_NC[EC_CODE, asset[j]]],
            gap = 0.05,
            label = asset[j],
            color = colors[j])
    end

    hidexdecorations!(axEC, ticks=false, ticklabels=false)

    ylims!(axEC, low = 0)

    # adding barplot for users

    ylimus = (0, max_installed_us + 20);
    for i = 1:n_users
        if i ==1
            axUs = Axis(gusers[1,i],
                ylabel = "Capacity [kW]",
                xticks = (1:2, ["CO","NC"]))
            ylims!(axUs, ylimus)
        else
            axUs = Axis(gusers[1,i],
                xticks = (1:2, ["CO","NC"]),
                yticklabelsvisible = false,
                yticksvisible = false)
            ylims!(axUs, ylimus)
        end
        user = user_set[i]

        hidexdecorations!(axUs, ticks=false, ticklabels=false)

        Label(gusers[1,i,Top()], user, valign = :bottom, font = :bold, padding = (0, 0, 5, 0))

        for j = 1:n_resource
            installed_CO_NC = (has_asset(users_data[user], asset[j])) ? [x_CO[user, asset[j]],x_NC[user, asset[j]]] : [0.0,0.0]
            barplot!(axUs, [1,2], installed_CO_NC,
                gap = 0.05,
                color = colors[j])
        end
    end

    Legend(gLegend[1,1], axEC, framevisible = false)

    asset_string = ""
    for j = 1:n_resource
        asset_string = asset_string * asset[j] * "_"
    end
    asset_output_file = asset_string * output_file

    save(asset_output_file, f)
end