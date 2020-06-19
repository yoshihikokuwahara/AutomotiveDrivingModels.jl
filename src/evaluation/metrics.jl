﻿export
    TraceMetricExtractor,

    get_score,
    reset!,
    extract!,

    extract_log_likelihood,
    extract_sum_square_jerk,

    RootWeightedSquareError,
    SumSquareJerk,
    EmergentKLDivergence

abstract type TraceMetricExtractor end

########################################
#        RootWeightedSquareError       #
########################################

type RootWeightedSquareError{F<:AbstractFeature} <: TraceMetricExtractor
    f::F
    horizon::Float64 # [s]
    running_sum::Float64
    n_obs::Int
end
RootWeightedSquareError{F<:AbstractFeature}(f::F, horizon::Float64) = RootWeightedSquareError(f, horizon, 0.0, 0)

Base.Symbol(m::RootWeightedSquareError) = Symbol(@sprintf("RWSE_%s_%d_%02d", string(Symbol(m.f)), floor(Int, m.horizon), floor(Int, 100*rem(m.horizon, 1.0))))
get_score(m::RootWeightedSquareError) = sqrt(m.running_sum / m.n_obs)
function reset!(metric::RootWeightedSquareError)
    metric.running_sum = 0.0
    metric.n_obs = 0
    metric
end
function extract!(
    metric::RootWeightedSquareError,
    rec_orig::SceneRecord, # the records are exactly as long as the simulation (ie, contain everything)
    rec_sim::SceneRecord,
    roadway::Roadway,
    egoid::Int,
    )
    #debug = open("debug.log", "a"); println(debug, "extract!(metric::RootWeightedSquareError,...)");  close(debug)

    # TODO: how to handle missing values???

    pastframe = 1-length(rec_orig) + clamp(round(Int, metric.horizon/rec_orig.timestep), 0, length(rec_orig)-1)

    # pull true value
    vehicle_index = get_index_of_first_vehicle_with_id(rec_orig, egoid, pastframe)
    v_true = convert(Float64, get(metric.f, rec_orig, roadway, vehicle_index, pastframe))

    # pull sim value
    vehicle_index = get_index_of_first_vehicle_with_id(rec_sim, egoid, pastframe)
    v_montecarlo = convert(Float64, get(metric.f, rec_sim, roadway, vehicle_index, pastframe))

    Δ = v_true - v_montecarlo
    metric.running_sum += Δ*Δ
    metric.n_obs += 1

    metric
end

########################################
#            SumSquareJerk             #
########################################

type SumSquareJerk <: TraceMetricExtractor
    running_sum::Float64
    n_obs::Int

    SumSquareJerk(running_sum::Float64=0.0, n_obs::Int=0) = new(running_sum, n_obs)
end
Base.Symbol(::SumSquareJerk) = :sumsquarejerk
get_score(m::SumSquareJerk) = m.running_sum / m.n_obs
function reset!(metric::SumSquareJerk)
    #debug = open("debug.log", "a"); println(debug, "reset!(metric::SumSquareJerk)");  close(debug)
    metric.running_sum = 0.0
    metric.n_obs = 0
    metric
end
function extract_sum_square_jerk(rec::SceneRecord, roadway::Roadway, egoid::Int)
    #debug = open("debug.log", "a"); println(debug, "extract_sum_square_jerk(rec::SceneRecord, roadway::Roadway, egoid::Int)");  close(debug)
    sumsquarejerk = 0.0
    for pastframe in 3-length(rec) : 0
        vehicle_index = get_index_of_first_vehicle_with_id(rec, egoid, pastframe)
        jerk = convert(Float64, get(JERK, rec, roadway, vehicle_index, pastframe))
        sumsquarejerk += jerk*jerk
    end
    sumsquarejerk
end
function extract!(
    metric::SumSquareJerk,
    rec_orig::SceneRecord, # the records are exactly as long as the simulation (ie, contain everything)
    rec_sim::SceneRecord,
    roadway::Roadway,
    egoid::Int,
    )
    #debug = open("debug.log", "a"); println(debug, "extract!(metric::SumSquareJerk,...)");  close(debug)

    metric.running_sum += extract_sum_square_jerk(rec_sim, roadway, egoid)
    metric.n_obs += 1

    metric
end

########################################
#         EmergentKLDivergence         #
########################################

type EmergentKLDivergence <: TraceMetricExtractor
    f::Union{AbstractFeature, TraceMetricExtractor}
    disc::LinearDiscretizer
    counts_orig::Vector{Int}
    counts_sim::Vector{Int}

    function EmergentKLDivergence(
        f::Union{AbstractFeature, TraceMetricExtractor},
        lo::Float64, hi::Float64, nbins::Int,
        )

        disc = LinearDiscretizer(collect(linspace(lo, hi, nbins+1)), Int)
        counts_orig = zeros(Int, nbins)
        counts_sim = fill!(deepcopy(counts_orig), 1) # NOTE(tim): uniform Dirichlet prior
        new(f, disc, counts_orig, counts_sim)
    end
end
Base.Symbol(metric::EmergentKLDivergence) = Symbol("kldiv_" * string(Symbol(metric.f)))

function calc_kl_div_categorical{I<:Real, J<:Real}(counts_p::AbstractVector{I}, counts_q::AbstractVector{J})
    #debug = open("debug.log", "a"); println(debug, "calc_kl_div_categorical{I<:Real, J<:Real}(counts_p::AbstractVector{I}, counts_q::AbstractVector{J})");  close(debug)

    #=
    Calculate the KL-divergence between two categorical distributions
    (also works if is it a piecewise uniform univariate with equally-spaced bins)
    =#

    tot_p = sum(counts_p)
    tot_q = sum(counts_q)

    kldiv = 0.0
    for (P,Q) in zip(counts_p, counts_q)
        if P > 0
            p = P/tot_p # convert to probability
            q = Q/tot_q # convert to probability
            kldiv += p * log(p/q)
        end
    end
    kldiv
end

get_score(m::EmergentKLDivergence) = calc_kl_div_categorical(m.counts_orig, m.counts_sim)
function reset!(metric::EmergentKLDivergence)
    fill!(metric.counts_orig, 0)
    fill!(metric.counts_sim, 1)
    metric
end
function extract!(
    metric::EmergentKLDivergence,
    rec_orig::SceneRecord,
    rec_sim::SceneRecord,
    roadway::Roadway,
    egoid::Int,
    )
    #debug = open("debug.log", "a"); println(debug, "extract!(metric::EmergentKLDivergence,...)");  close(debug)

    v_orig, v_sim = NaN, NaN
    if isa(metric.f, AbstractFeature)
        F::AbstractFeature = metric.f
        pastframe = 0
        vehicle_index = get_index_of_first_vehicle_with_id(rec_orig, egoid, pastframe)
        v_orig = convert(Float64, get(F, rec_orig, roadway, vehicle_index, pastframe))
        vehicle_index = get_index_of_first_vehicle_with_id(rec_sim, egoid, pastframe)
        v_sim = convert(Float64, get(F, rec_sim, roadway, vehicle_index, pastframe))
    elseif isa(metric.f, SumSquareJerk)
        v_orig = extract_sum_square_jerk(rec_orig, roadway, egoid)
        v_sim = extract_sum_square_jerk(rec_sim, roadway, egoid)
    else
        error("UNKNOWN EMERGENT KLDIV METRIC $(metric.f)")
    end

    metric.counts_orig[encode(metric.disc, v_orig)] += 1
    metric.counts_sim[encode(metric.disc, v_sim)] += 1

    metric
end

########################################
#            LogLikelihood             #
########################################

function extract_log_likelihood(model::DriverModel, rec::SceneRecord, roadway::Roadway, egoid::Int;
    prime_history::Int = 0,
    scene::Scene = Scene(),
    )
    #debug = open("debug.log", "a"); println(debug, "extract_log_likelihood(model::DriverModel, rec::SceneRecord, roadway::Roadway, egoid::Int;)");  close(debug)

    A = action_type(model)

    pastframe_prime = prime_history-length(rec)
    prime_with_history!(model, rec, roadway, egoid, pastframe_end=pastframe_prime)

    logl = 0.0
    for pastframe in pastframe_prime+1 : -1
        observe!(model, get_scene(rec, pastframe), roadway, egoid)
        vehicle_index = get_index_of_first_vehicle_with_id(rec, egoid, pastframe+1)
        action = get(A, rec, roadway, vehicle_index, pastframe+1)
        logl += logpdf(model, action)
    end
    logl
end