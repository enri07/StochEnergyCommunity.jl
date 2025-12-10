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
output_plot_isolated = "outputs/Img/plot_user_{:s}_SNC.png"  # Output png file of plot - model users alone

output_file_combined = "outputs/output_file_SCO.xlsx"  # Output file - model Energy community
output_plot_combined = "outputs/Img/plot_user_{:s}_SCO.pdf"  # Output png file of plot - model energy community

# Generate the set of scenarios used to optimize the EC
scenarios = build_scenarios(input_file)

## Model CO

## Initialization

# Read data from excel file
ECModel_SCO = StochasticEC(input_file, EnergyCommunity.GroupCO(), scenarios, optimizer = HiGHS.Optimizer)

# build CO model
build_specific_model!(GroupCO(),ECModel_SCO, HiGHS.Optimizer)

# optimize CO model
optimize_deterministic_ECmodel(ECModel_SCO)

# # create plots of CO model
# plot(ECModel, output_plot_combined)

# # print summary
# print_summary(ECModel)

# # save summary data
# save_summary(ECModel, output_file_combined)

# # Plot sankey plot of CO model
# plot_sankey(ECModel)

# # DataFrame of the business plan
# business_plan(ECModel)

# # plot 20 years business plan of CO model
# business_plan_plot(ECModel)

# ## Model NC

# Read data from excel file
ECModel_SNC = StochasticEC(input_file, EnergyCommunity.GroupNC(), scenarios, optimizer = HiGHS.Optimizer)

# build NC model
build_base_model!(GroupNC(),ECModel_SNC, HiGHS.Optimizer)

# optimize NC model
optimize_deterministic_ECmodel(ECModel_SNC)

# # create plots of NC model
# plot(NC_Model, output_plot_isolated)

# # print summary of NC model
# print_summary(NC_Model)

# # save summary of NC model
# save_summary(NC_Model, output_file_isolated)

# # plot Sankey plot of NC model
# plot_sankey(NC_Model)

# # DataFrame of the business plan of NC model
# business_plan(NC_Model)

# # plot business plan of NC model
# business_plan_plot(NC_Model)







# # save the data of the first stage model
# output_file_NC = "first_stage_output_NC_($scen_s_sample,$scen_eps_sample)"

# print_first_stage(output_file_NC * ".xlsx",EC_NonCooperative)
# save(output_file_NC * ".jld2", EC_NonCooperative)

# # get the number of installed resource by users
# x_NC_fixed = EC_NonCooperative.results[:x_us].data

# # add the installed capacity of the entire EC
# x_tot_NC = calculate_x_tot(EC_NonCooperative)

# #Free memory
# EC_NonCooperative = StochasticEC();

# GC.gc() # garbage collector

# # save the data of the first stage model
# output_file_CO = "first_stage_output_CO_($scen_s_sample,$scen_eps_sample)"
# print_first_stage(output_file_CO * ".xlsx",EC_Cooperative)
# save(output_file_CO * ".jld2", EC_Cooperative)
# # get the number of installed resource by users
# x_CO_fixed = EC_Cooperative.results[:x_us].data

# # Plot some useful image of the installed capacity
# colors = Makie.wong_colors()

# # add the installed capacity of the entire EC
# x_tot_CO = calculate_x_tot(EC_Cooperative)

# plot_resource("installed_capacity1_($scen_s_sample,$scen_eps_sample).png",["PV","wind"],users_data,x_tot_CO,x_tot_NC,colors[1:2]) # renewable asset
# plot_resource("installed_capacity_($scen_s_sample,$scen_eps_sample).png",["batt"],users_data,x_tot_CO,x_tot_NC,[colors[3]]) #battery
