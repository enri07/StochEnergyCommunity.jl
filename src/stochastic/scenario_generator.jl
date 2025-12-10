"""
    pem_extraction(scen_s_sample::Int, sigma_load, mean_pv, sigma_pv, mean_wind, sigma_wind, uncertain_var)

Extract scenario points and probabilities using the Point Estimate Method (PEM) for long-term uncertainty.

This function applies the Point Estimate Method to sample from probability distributions representing
long-term uncertainty in load demand or renewable production. PEM provides a discrete approximation
of continuous distributions with a small number of representative points and associated probabilities.

# Arguments
- `stoch_data::Dict`: Dictionary containing all the necessary information for the extraction of
  long period scenarios.

# Returns
A tuple `(point_load, point_pv, point_wind, scen_probability)` where:
- `point_load::Vector{Float64}`: Sampled load demand multipliers (length `scen_s_sample`)
- `point_pv::Vector{Float64}`: Sampled PV production multipliers (length `scen_s_sample`)
- `point_wind::Vector{Float64}`: Sampled wind production multipliers (length `scen_s_sample`)
- `scen_probability::Vector{Float64}`: Probability associated with each scenario (sums to 1.0)

# Distribution Details
- For load demand (`uncertain_var="L"`): Truncated Normal distribution ``N(1.0, σ_{load})`` with support ``[0, +∞)``
- For PV production (`uncertain_var="P"`): Truncated Normal distribution ``N(μ_{pv}, σ_{pv})`` with support ``[0, +∞)``
- For wind production (`uncertain_var="W"`): Truncated Normal distribution ``N(μ_{wind}, σ_{wind})`` with support ``[0, +∞)``

# Point Estimate Method
PEM approximates the moments of a random variable using a weighted sum of strategically chosen points.
For `scen_s_sample` scenarios, it selects points and weights that match the first `scen_s_sample` 
moments of the underlying distribution.

# Special Cases
- If `scen_s_sample = 1`: Returns deterministic values (load=1.0, pv=mean_pv, wind=mean_wind) with probability 1.0
- For uncertain variables: Only the specified variable has uncertainty; others are set to their mean values

# Errors

- Throws ArgumentError if uncertain_var is not "L", "P", or "W"

"""

function pem_extraction(stoch_data)

	# Extract specific information
	scen_s_sample = field(stoch_data, "n_s") # number of long period scenarios

	# Type of uncertain variable to consider:
  	# "L": Long-term uncertainty on load demand only
    # "P": Long-term uncertainty on PV production only
    # "W": Long-term uncertainty on wind production only
	uncertain_var = field(stoch_data, "uncertain_var")

	if scen_s_sample > 1 # More than a single scenario s to generate
		if uncertain_var == "L" # We are considering long uncertainties on load demand
			# Extract mean and std associated with long term uncertanties on load demand
			mean_load = field(stoch_data, "mean_load")
			sigma_load = field(stoch_data, "sigma_load")

			Distribution_load = truncated(Normal(1.0,sigma_load), 0.0, +Inf) # Load distribution
			pem_load = pem(Distribution_load,scen_s_sample) # Extracted point for load (with their probability)
			point_load = pem_load.x
			scen_probability = pem_load.p # probability associated to each extracted point from load distribution
			
			point_wind = ones(scen_s_sample) # No uncertainty on wind
			point_pv = ones(scen_s_sample) # No uncertainty on PV

		elseif uncertain_var == "P" # We are considering long uncertainties on PV
			# Extract mean and std associated with long term uncertanties on load demand
			mean_pv = field(stoch_data, "mean_pv")
			sigma_pv = field(stoch_data, "sigma_pv")

			Distribution_pv = truncated(Normal(mean_pv,sigma_pv), 0.0, +Inf) # Renewable production distribution
			pem_pv = pem(Distribution_pv,scen_s_sample) # Extracted point for PV
			point_pv = pem_pv.x
			scen_probability = pem_pv.p # probability associated to each extracted point from renewable distribution

			point_load = ones(scen_s_sample) # No uncertainty on load demand
			point_wind = ones(scen_s_sample) # No uncertainty on wind

		elseif uncertain_var == "W" # We are considering long uncertainties on wind
			# Extract mean and std associated with long term uncertanties on load demand
			mean_wind = field(stoch_data, "mean_wind")
			sigma_wind = field(stoch_data, "sigma_wind")

			Distribution_wind = truncated(Normal(mean_wind,sigma_wind), 0.0, +Inf) # Renewable production distribution
			pem_wind = pem(Distribution_wind,scen_s_sample) # Extracted point for PV
			point_wind = pem_wind.x
			scen_probability = pem_wind.p # probability associated to each extracted point from renewable distribution

			point_load = ones(scen_s_sample) # No uncertainty on load demand
			point_pv = ones(scen_s_sample) # No uncertainty on PV
		else
			throw( ArgumentError("The uncertain_var value must be R, P or W") )
		end
		
	else
		point_load = [1.0]
		point_pv = [1.0]
		point_wind = [1.0]

		scen_probability = [1.0]
	end

	return (point_load,point_pv,point_wind,scen_probability)
end

"""
    Scenario_eps_Point_Sampler(data_user, uncertain_var; deterministic::Bool = false)

Sample points from the distribution associated with short-term (epsilon scenario) uncertainty.

This function generates random samples for load demand and renewable production based on the 
specified uncertainty variable. The samples are normalized multiplicative factors applied to 
the base profiles.

# Arguments
- `data_user::Dict`: Dictionary containing user data with load and renewable generation profiles
- `uncertain_var::String`: Type of uncertain variable to consider:
  - `"L"`: Uncertainty on load demand only
  - `"P"`: Uncertainty on PV production only
  - `"W"`: Uncertainty on wind production only
- `deterministic::Bool=false`: If `true`, returns deterministic samples (all ones) instead of random samples

# Returns
A tuple `(point_load_demand, point_ren_production)` where:
- `point_load_demand::Dict{String, Array{Float64}}`: Normalized load demand multipliers for each user
- `point_ren_production::Dict{String, Dict{String, Array{Float64}}}`: Normalized renewable production 
  multipliers for each user and renewable asset
"""
function Scenario_eps_Point_Sampler(data_user, uncertain_var, deterministic)

    point_load_demand = Dict{String,Array{Float64}}() # extracted point for each user
    point_ren_production = Dict{String,Dict{String,Array{Float64}}}() # extracted point for each user and asset

    n_step = length(profile_component(data_user["user1"], "load", "load") )
    user_set = keys(data_user)
    time_set = 1:n_step

    for u in user_set

        if deterministic == true
            array_n_load = ones(n_step)
            point_load_demand[u] = array_n_load

            point_ren_production[u] = Dict{String,Array{Float64}}()
            for name = asset_names(data_user[u], REN)
                point_ren = ones(n_step)
                get!(point_ren_production[u],name,point_ren)
            end
        else
            if uncertain_var == "L" # We are considering uncertainties on load demand
        
                # Calculate the normalized std for load
                std_n_load = (profile_component(data_user[u], "load", "std"))./profile_component(data_user[u], "load", "load") 

                # We are supposing that to have a day-ahead uncertainty and a short-term uncertainty (in first approximation, considered equal)
                std_st_load = std_n_load

                # Define load distribution for short period uncertainty
                load_distribution = MvNormal(ones(n_step), std_st_load)
                
                # Load extraction
                array_n_load = broadcast(abs, rand(load_distribution))

                # Control when the extracted point are < 0
                for t in time_set
                    if array_n_load[t] < 0
                        array_n_load[t] = 0
                    end
                end

                # New load demand of user u in the specific scenario s considered
                point_load_demand[u] = array_n_load

                # Add deterministic renewable production
                point_ren_production[u] = Dict{String,Array{Float64}}()
                for name = asset_names(data_user[u], REN)
                    point_ren = ones(n_step)
                    get!(point_ren_production[u],name,point_ren)
                end

            else # We are considering uncertainties on renewable production

                # Add deterministic load 
                array_n_load = ones(n_step)
                point_load_demand[u] = array_n_load
            
                point_ren_production[u] = Dict{String,Array{Float64}}()
                for name = asset_names(data_user[u], REN)

                    if ( name == "PV" && uncertain_var == "P" ) || ( name == "wind" && uncertain_var == "W" ) # Add uncertainties on desired variable

                        # We are supposing that to have a day-ahead uncertainty and a short-term uncertainty (in first approximation, considered equal)
                        std_st_ren = profile_component(data_user[u], name, "std")

                        # Define load distribution for short period uncertainty
                        ren_distribution = MvNormal(ones(n_step), std_st_ren)

                        # Renewable extraction
                        point_ren = broadcast(abs, rand(ren_distribution))

                        # Control to set 0 the extracted production when initial renewable production was 0 or when the extracted point are < 0
                        for t in time_set
                            if profile_component(data_user[u], name, "ren_pu")[t] == 0 || point_ren[t] < 0
                                point_ren[t] = 0
                            end
                        end
                    else
                        point_ren = ones(n_step) # No uncertainties to consider
                    end
                    # Fill with extracted points
                    get!(point_ren_production[u],name,point_ren)
                end
            end
        end
    end
    return (point_load_demand,point_ren_production)
end

"""
    scenarios_generator(data, stoch_params, point_s_load, point_s_pv, point_s_wind, point_probability)

Generate scenarios combining long-term and short-term uncertainties for stochastic optimization.

This function creates a hierarchical scenario tree where each long-term scenario (s) branches into 
multiple short-term scenarios (ε). The scenarios include load demand and renewable production profiles 
affected by three levels of uncertainty: long-term, day-ahead, and short-term.

# Arguments
- `data::Dict{Any, Any}`: Dictionary containing all user, market, and general data
- `stoch_data::Dict{Any, Any}`: Dictionary containing all stochastic parameters
- `point_s_load::Vector{Float64}`: Sampled points for long-term load demand uncertainty (one per scenario s)
- `point_s_pv::Vector{Float64}`: Sampled points for long-term PV production uncertainty (one per scenario s)
- `point_s_wind::Vector{Float64}`: Sampled points for long-term wind production uncertainty (one per scenario s)
- `point_probability::Vector{Float64}`: Probability of each long-term scenario s

# Returns
- `sampled_scenarios::Array{Scenario_Load_Renewable}`: Array of generated scenarios
"""

function scenarios_generator(
	data::Dict{Any, Any},
    stoch_data::Dict{Any, Any},
	point_s_load::Vector{Float64}, # extracted point for long period uncertainty distribution in load demand
	point_s_pv::Vector{Float64}, # extracted point for long period uncertainty distribution in PV production
    point_s_wind::Vector{Float64}, # extracted point for long period uncertainty distribution in wind production
    point_probability::Vector{Float64}
)

    ## In this implementation, we consider uncertanties only on the uncertain_var under analyses.
    
    # Extract users and market data
    data_user = users(data)
	data_market = market(data)
    user_set = keys(data_user)

    # Extract specific information
	n_scen_s = field(stoch_data, "n_s") # number of long period scenarios
    n_scen_eps = field(stoch_data, "n_eps") # number of long period scenarios
    n_scen = n_scen_s*n_scen_eps # total number of scenarios

    # Type of uncertain variable to consider:
  	# "L": Long-term uncertainty on load demand only
    # "P": Long-term uncertainty on PV production only
    # "W": Long-term uncertainty on wind production only
	uncertain_var = field(stoch_data, "uncertain_var")

    deterministic = (n_scen_s == 1 && n_scen_eps == 1)

    # Array containing each scenario
    sampled_scenarios = Array{Scenario_Load_Renewable}(undef,n_scen)
    for scen = 1:n_scen
        sampled_scenarios[scen] = zero(Scenario_Load_Renewable) # initialize an empty scenario 
    end
    
    for s = 1:n_scen_s
        # Extract first day-ahead uncertainties which are common among different scenarios epsilon
        point_load_dayahead = Dict{String,Array{Float64}}() # dictionary used to store all the extracted point for day-ahead load demand
        point_ren_dayahead = Dict{String,Dict{String,Array{Float64}}}() # dictionary used to store all the extracted point for day-ahead renewable production
        (point_load_dayahead,point_ren_dayahead) = Scenario_eps_Point_Sampler(data_user,uncertain_var,deterministic)

        for eps = 1:n_scen_eps
            scen = (s-1)*n_scen_eps+eps

            # we have now to evaluate the real value sampled for load and renewable production
            # It is evaluated as: mean_L * sigma^LT_s * sigma^DA_{s,d} * sigma^ST_{s,d,epsilon}
            load_demand = Dict{String,Dict{Int,Float64}}()
            ren_production = Dict{String,Dict{String,Dict{Int,Float64}}}()

            # Extract now short-term uncertainties which are different among different scenarios epsilon
            point_load_shortterm = Dict{String,Array{Float64}}() # dictionary used to store all the extracted point for day-ahead load demand
            point_ren_shortterm = Dict{String,Dict{String,Array{Float64}}}() # dictionary used to store all the extracted point for day-ahead renewable production
            (point_load_shortterm,point_ren_shortterm) = Scenario_eps_Point_Sampler(data_user,uncertain_var,deterministic)

            for u in user_set
                # Fill the scenarios with extracted values
                load_demand[u] = array2dict(( profile_component(data_user[u], "load", "load") * point_s_load[s] ) # Scenario s demand
                                                .* point_load_dayahead[u] # Day-Ahead demand
                                                    .* point_load_shortterm[u] ) # Short-term demand
                
                ren_production[u] = Dict{String,Dict{Int,Float64}}()
                for name = asset_names(data_user[u], REN)
                    if name == "PV"
                        temp = array2dict( ( profile_component(data_user[u], name, "ren_pu") * point_s_pv[s] ) # Scenario s production
                                                .* point_ren_dayahead[u][name] # Day-Ahead production 
                                                    .* point_ren_shortterm[u][name] ) # Short-term
                    elseif name == "wind"
                        temp = array2dict( ( profile_component(data_user[u], name, "ren_pu") * point_s_wind[s] ) # Scenario s production
                                                .* point_ren_dayahead[u][name] # Day-Ahead production 
                                                    .* point_ren_shortterm[u][name] ) # Short-term
                    else
                        throw( ArgumentError("Accepted renewable assets name are wind and PV") )
                    end
                    get!(ren_production[u],name,temp)
                end
            end

            sampled_scenarios[scen] = Scenario_Load_Renewable(
                s,
                eps,
                profile(data_market, "peak_tariff"),
                array2dict(profile(data_market, "buy_price")),
                array2dict(profile(data_market, "consumption_price")),
                array2dict(profile(data_market, "sell_price")),
                array2dict(profile(data_market, "penalty_price")),
                load_demand,
                ren_production,
                probability = point_probability[s]/n_scen_eps)
        end
    end
    return sampled_scenarios    
end

"""
    build_scenarios(data)

Generate a complete set of scenarios by combining long-term and short-term uncertainties for stochastic optimization.

Starting from the provided input data, this function first samples long-term scenarios and then, for each of them, 
derives the corresponding short-term scenarios. The result is a hierarchical scenario tree in which each 
long-term scenario (s) branches into multiple short-term scenarios (ε).

# Arguments
- `input_file::String`: Path to the input file containing all user, market, and general data

# Returns
- `sampled_scenarios::Array{Scenario_Load_Renewable}`: Array of generated scenarios
"""

function build_scenarios(input_file::String)
    data = read_input(input_file)
    # Extract all data
    (gen_data,
    users_data,
    market_data) = explode_data(data)

    # Extract specific stochastic parameters
    stoch_parameters = stoch_params(gen_data)

    # Extraction of the points used to sample the distributions associated to the long period uncertainty
    (point_s_load,
    point_s_pv,
    point_s_wind,
    scen_probability) = pem_extraction(stoch_parameters)

    # Generate the set of scenarios to initialize the stochastic model
    sampled_scenarios = scenarios_generator(data, stoch_parameters,
                              point_s_load,
                              point_s_pv,
                              point_s_wind,
                              scen_probability)

    return sampled_scenarios

end