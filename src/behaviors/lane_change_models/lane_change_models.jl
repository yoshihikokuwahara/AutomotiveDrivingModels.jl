﻿export
        LaneChangeAction,
        LaneChangeChoice,
        LaneChangeModel,
        get_lane_offset,

        DIR_RIGHT,
        DIR_MIDDLE,
        DIR_LEFT,

        TimLaneChanger

abstract type LaneChangeAction <: DriveAction end

"""
    LaneChangeChoice
A choice of whether to change lanes, and what direction to do it in
"""
const DIR_RIGHT = -1
const DIR_MIDDLE =  0
const DIR_LEFT =  1
immutable LaneChangeChoice <: LaneChangeAction
    dir::Int # -1, 0, 1
end
Base.show(io::IO, a::LaneChangeChoice) = @printf(io, "LaneChangeChoice(%d)", dir)
Base.length(::Type{LaneChangeChoice}) = 1
Base.convert(::Type{LaneChangeChoice}, v::Vector{Float64}) = LaneChangeChoice(convert(Int, v[1]))
function Base.copy!(v::Vector{Float64}, a::LaneChangeChoice)
    v[1] = a.dir
    v
end
function get_lane_offset(a::LaneChangeChoice, rec::SceneRecord, roadway::Roadway, vehicle_index::Int, pastframe::Int=0)
    if a.dir == DIR_MIDDLE
        rec[vehicle_index, pastframe].state.posF.t
    elseif a.dir == DIR_LEFT
        convert(Float64, get(LANEOFFSETLEFT, rec, roadway, vehicle_index, pastframe))
    else
        @assert(a.dir == DIR_RIGHT)
        convert(Float64, get(LANEOFFSETRIGHT, rec, roadway, vehicle_index, pastframe))
    end
end

####################

abstract type LaneChangeModel{LaneChangeAction} end
get_name(::LaneChangeModel) = "???"
set_desired_speed!(::LaneChangeModel, v_des::Float64) = model # # do nothing by default
reset_hidden_state!(model::LaneChangeModel) = model # do nothing by default
observe!(model::LaneChangeModel, scene::Scene, roadway::Roadway, egoid::Int) = model  # do nothing by default
Base.rand(model::LaneChangeModel) = error("rand not implemented for model $model")

####################

type TimLaneChanger <: LaneChangeModel{LaneChangeAction}
    dir::Int
    rec::SceneRecord

    v_des::Float64
    threshold_fore::Float64
    threshold_lane_change_gap_fore::Float64
    threshold_lane_change_gap_rear::Float64

    function TimLaneChanger(
        action_context::IntegratedContinuous;
        v_des::Float64=29.0,
        rec::SceneRecord=SceneRecord(2,action_context.Δt),
        threshold_fore::Float64 = 50.0,
        threshold_lane_change_gap_fore::Float64 = 10.0,
        threshold_lane_change_gap_rear::Float64 = 10.0,
        dir::Int=DIR_MIDDLE,
        )

        retval = new()
        retval.dir = dir
        retval.rec = rec
        retval.v_des = v_des
        retval.threshold_fore = threshold_fore
        retval.threshold_lane_change_gap_fore = threshold_lane_change_gap_fore
        retval.threshold_lane_change_gap_rear = threshold_lane_change_gap_rear
        retval
    end
end
get_name(::TimLaneChanger) = "TimLaneChanger"
function set_desired_speed!(model::TimLaneChanger, v_des::Float64)
    model.v_des = v_des
    model
end
function observe!(model::TimLaneChanger, scene::Scene, roadway::Roadway, egoid::Int)
    #debug = open("debug.log", "a"); println(debug, "observe!(model::TimLaneChanger, scene::Scene, roadway::Roadway, egoid::Int)");  close(debug)

    rec = model.rec
    update!(rec, scene)
    vehicle_index = get_index_of_first_vehicle_with_id(rec, egoid)

    veh_ego = scene[vehicle_index]
    v = veh_ego.state.v

    left_lane_exists = convert(Float64, get(N_LANE_LEFT, rec, roadway, vehicle_index)) > 0
    right_lane_exists = convert(Float64, get(N_LANE_RIGHT, rec, roadway, vehicle_index)) > 0
    fore_M = get_neighbor_fore_along_lane(scene, vehicle_index, roadway, VehicleTargetPointFront(), VehicleTargetPointRear(), VehicleTargetPointFront(), max_distance_fore=model.threshold_fore)
    fore_L = get_neighbor_fore_along_left_lane(scene, vehicle_index, roadway, VehicleTargetPointRear(), VehicleTargetPointRear(), VehicleTargetPointFront())
    fore_R = get_neighbor_fore_along_right_lane(scene, vehicle_index, roadway, VehicleTargetPointRear(), VehicleTargetPointRear(), VehicleTargetPointFront())
    rear_L = get_neighbor_rear_along_left_lane(scene, vehicle_index, roadway, VehicleTargetPointFront(), VehicleTargetPointFront(), VehicleTargetPointRear())
    rear_R = get_neighbor_rear_along_right_lane(scene, vehicle_index, roadway, VehicleTargetPointFront(), VehicleTargetPointFront(), VehicleTargetPointRear())

    model.dir = DIR_MIDDLE
    if fore_M.Δs < model.threshold_fore # there is a lead vehicle
        veh_M = scene[fore_M.ind]
        speed_M = veh_M.state.v
        if speed_M ≤ min(model.v_des, v) # they are driving slower than we want

            speed_ahead = speed_M

            # consider changing to a different lane
            if right_lane_exists &&
               fore_R.Δs > model.threshold_lane_change_gap_rear && # there is space rear
               rear_R.Δs > model.threshold_lane_change_gap_fore && # there is space fore
               (rear_R.ind == 0 || scene[rear_R.ind].state.v ≤ v) && # we are faster than any follower
               (fore_R.ind == 0 || scene[fore_R.ind].state.v > speed_ahead) # we are faster than any leader

                speed_ahead = fore_R.ind != 0 ? scene[fore_R.ind].state.v : Inf
                model.dir = DIR_RIGHT
            end
            if left_lane_exists &&
               fore_L.Δs > model.threshold_lane_change_gap_rear && # there is space rear
               rear_L.Δs > model.threshold_lane_change_gap_fore && # there is space fore
               (rear_L.ind == 0 || scene[rear_L.ind].state.v ≤ v) && # we are faster than any follower
               (fore_L.ind == 0 || scene[fore_L.ind].state.v > speed_ahead) # we are faster than any leader

                speed_ahead = fore_L.ind != 0 ? scene[fore_L.ind].state.v : Inf
                model.dir = DIR_LEFT
            end
        end
    end

    model
end
Base.rand(model::TimLaneChanger) = LaneChangeChoice(model.dir)