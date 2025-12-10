# # Optimizing different stochastic configurations
# This example aims to showcase the use of EnergyCommunity.jl to optimize the different configurations of energy communities supported by the tool under a stochastic setting, namely:
# - Stochastic Non Cooperative (SNC)
# - Stochastic Cooperative (CO)

# The energy community considered in this example consists of 3 users, where:
# * all users can install PV system
# * only the first user cannot install batteries, whereas the others can
# * the third user can install also wind turbines

# The example is based on a subset of users taken from the following article, yet for a subset of users.
# > E. Calandrini, D. Fioriti, A. Frangioni, D. Poli, "Three-stage Stochastic Planning of Energy Communities with active market participation under demand and renewable uncertainties," in TechRxiv, power, energy and industry applications, [doi: 10.36227/techrxiv.176403982.29415500/v1](https://www.techrxiv.org/doi/full/10.36227/techrxiv.176403982.29415500/v1#)

# ## Stochastic Cooperative (CO) Energy Community

# ### Initialization

# Import the needed packages
using EnergyCommunity, JuMP
using HiGHS, Plots

# Create a base Energy Community example in the data folder; use the default configuration.
folder = joinpath(@__DIR__, "stoch_data")
create_example_data(folder, config_name="default")

# Input file to load the structure of the energy community based on a yaml file.
input_file = joinpath(@__DIR__, "stoch_data/energy_community_model.yml");

# define optimizer and options
optimizer = optimizer_with_attributes(HiGHS.Optimizer, "ipm_optimality_tolerance"=>1e-4)

# Generate the set of scenarios used to optimize the EC
scenarios = build_scenarios(input_file)

# ### Create, build and optimize the model

# Define the Stochastic COoperative model (SCO)
ECModel_SCO = StochasticEC(input_file, EnergyCommunity.GroupCO(), scenarios, optimizer = optimizer)

# build SCO model
build_specific_model!(GroupCO(),ECModel_SCO, optimizer)

# optimize SCO model
optimize_deterministic_ECmodel(ECModel_SCO)

# ### Results

# print summary
print_summary(ECModel_SCO)

# ## Stochastic Non Cooperative (SNC) Energy Community

# ### Initialization
# Given that the initialization is the same as for the CO model, we can reuse the input file and the optimizer defined above. So we can directly move to the model creation.

# ### Create, build and optimize the model
# Define the Non Cooperative model
ECModel_SNC = StochasticEC(input_file, EnergyCommunity.GroupNC(), scenarios, optimizer = optimizer)

# build SNC model
build_base_model!(ECModel_SNC, optimizer)

# optimize SNC model
optimize_deterministic_ECmodel(ECModel_SNC)

# ### Results
# print summary of SNC model
print_summary(ECModel_SNC)

# ## Plots of installed resources

# Extract installed quantity of resources in both configurations
x_tot_SCO = calculate_x_tot(ECModel_SCO)
x_tot_SNC = calculate_x_tot(ECModel_SNC)

# Renewable assets
colors = palette(:default)
plot_resource(output_plot_ren, ["PV","wind"], ECModel_SCO, x_tot_SCO, x_tot_SNC, colors[1:2]) 

# Battery
plot_resource(output_plot_batt, ["batt"], ECModel_SCO, x_tot_SCO, x_tot_SNC, [colors[3]])