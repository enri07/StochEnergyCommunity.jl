#using StochasticPrograms#master
#using JuMP
#using Base.Threads
#using DataStructures
#using LinearAlgebra
#using Parameters
#using Distributions
#using Random
#using JLD2
#using FileIO
#using PointEstimateMethod
#using YAML
#using DataFrames
#using CSV
#using XLSX
#using Formatting
# Useful package to built plot
#using Makie
#using CairoMakie
#using ColorSchemes
#using StochasticPrograms

#import CPLEX

# # Run this script from EnergyCommunity.jl root!!!
# using Pkg
# Pkg.activate("examples")

using EnergyCommunity, JuMP
using HiGHS, Plots

## Create basic example for the Energy Community in the stoch_data folder

folder = "stoch_data"
create_stoch_example_data(folder, config_name="default")

## Parameters

input_file = "$folder/energy_community_model.yml"  # Input file

output_file_isolated = "outputs/output_file_SNC.xlsx"  # Output file - model users alone

output_file_combined = "outputs/output_file_SCO.xlsx"  # Output file - model Energy community

output_plot_ren = "outputs/Img/plot_stoch_renewable_assets.png"  # Output png file of plot - renewable assets
output_plot_batt = "outputs/Img/plot_stoch_battery_assets.pdf"  # Output png file of plot - battery assets

# Generate the set of scenarios used to optimize the EC
scenarios = build_scenarios(input_file)

## Model SCO

## Initialization

# Read data from excel file
ECModel_SCO = StochasticEC(input_file, EnergyCommunity.GroupCO(), scenarios, optimizer = HiGHS.Optimizer)

# build SCO model
build_specific_model!(GroupCO(),ECModel_SCO, HiGHS.Optimizer)

# optimize SCO model
optimize_deterministic_ECmodel(ECModel_SCO)

# print summary
print_summary(ECModel_SCO)

# Save results
print_stochastic_results(output_file_combined, ECModel_SCO)

# ## Model SNC

# Read data from excel file
ECModel_SNC = StochasticEC(input_file, EnergyCommunity.GroupNC(), scenarios, optimizer = HiGHS.Optimizer)

# build SNC model
build_base_model!(GroupNC(),ECModel_SNC, HiGHS.Optimizer)

# optimize SNC model
optimize_deterministic_ECmodel(ECModel_SNC)

# print summary of SNC model
print_summary(ECModel_SNC)

# Save results
print_stochastic_results(output_file_isolated, ECModel_SNC)

# Plot some useful image of the installed capacity
colors = wong_colors()

# Evaluate the installed capacity of the entire EC - model Energy community
x_tot_SCO = calculate_x_tot(EC_Cooperative)

# Evaluate the installed capacity of the entire EC - model users alone
x_tot_SNC = calculate_x_tot(EC_NonCooperative)

# Plot installed renewable assets in both SCO and SNC versions
plot_resource(output_plot_ren, users_data, ["PV","wind"], x_tot_SCO, x_tot_SNC, colors[1:2]) # renewable asset
plot_resource(output_plot_batt, users_data, ["batt"], x_tot_SCO, x_tot_SNC, [colors[3]]) #battery