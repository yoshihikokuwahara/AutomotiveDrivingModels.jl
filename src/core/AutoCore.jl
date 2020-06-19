﻿"""
    AutoCore
Defines the core Automotive Types
"""
module AutoCore

using Compat
using Vec

export

    # curves
    CurvePt,
    Curve,
    CurveIndex,
    CurveProjection,

    CURVEINDEX_START,

    get_lerp_time,
    index_closest_to_point,
    get_curve_index,
    curveindex_end,

    # roadway
    LaneTag,
    LaneBoundary,
    Lane,
    LaneConnection,
    SpeedLimit,
    RoadSegment,
    Roadway,
    RoadProjection,
    RoadIndex,

    NULL_BOUNDARY,
    NULL_LANETAG,
    NULL_ROADINDEX,

    DEFAULT_SPEED_LIMIT,
    DEFAULT_LANE_WIDTH,

    is_in_exits,
    is_in_entrances,
    is_at_curve_end,
    is_between_segments_lo,
    is_between_segments_hi,
    is_between_segments,
    has_segment,
    has_lanetag,
    has_next,
    has_prev,
    next_lane,
    prev_lane,
    next_lane_point,
    prev_lane_point,
    connect!,
    prev,
    project_to_closest_lane,
    move_along,
    n_lanes_left,
    n_lanes_right,
    get_neighbor_lanetag_left,
    get_neighbor_lanetag_right,
    read_dxf,

    # vehicles
    Frenet,
    VehicleState,
    Vehicle,
    AgentClass,
    VehicleDef,

    DEFAULT_VEHICLE_DEF,
    NULL_VEHICLEDEF,
    NULL_FRENET,

    get_posG,
    get_vel_s,
    get_vel_t,
    get_center,
    get_footpoint,
    get_front_center,
    get_rear_center,

    # trajdata
    TrajdataFrame,
    TrajdataState,
    Trajdata,
    TrajdataVehicleIterator,

    get_ids,
    nframes,
    frame_inbounds,
    carsinframe,
    nth_carid,
    iscarinframe,
    get_first_frame_with_id,
    get_last_frame_with_id,
    get_time,
    get_elapsed_time,
    get_mean_timestep,
    get_vehiclestate,
    get_vehicledef,
    get_vehicle!,
    get_vehicle,

    # scene
    Scene,

    get_by_id,
    get_index_of_first_vehicle_with_id,
    get_first_available_id,
    record_length,
    get_scene,
    push_back_records!,
    update!,

    NeighborLongitudinalResult,
    get_neighbor_fore_along_lane,
    get_neighbor_fore_along_left_lane,
    get_neighbor_fore_along_right_lane,
    get_neighbor_rear_along_lane,
    get_neighbor_rear_along_left_lane,
    get_neighbor_rear_along_right_lane,

    FrenetRelativePosition,
    get_frenet_relative_position,

    # scene record
    SceneRecord,

    pastframe_inbounds



include(Pkg.dir("AutomotiveDrivingModels", "src", "core", "utils.jl"))
include(Pkg.dir("AutomotiveDrivingModels", "src", "core", "splines.jl"))
include(Pkg.dir("AutomotiveDrivingModels", "src", "core", "curves.jl"))
include(Pkg.dir("AutomotiveDrivingModels", "src", "core", "roadways.jl"))
include(Pkg.dir("AutomotiveDrivingModels", "src", "core", "vehicles.jl"))
include(Pkg.dir("AutomotiveDrivingModels", "src", "core", "trajdatas.jl"))
include(Pkg.dir("AutomotiveDrivingModels", "src", "core", "scenes.jl"))
include(Pkg.dir("AutomotiveDrivingModels", "src", "core", "scene_records.jl"))

end # module