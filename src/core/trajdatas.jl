﻿immutable TrajdataFrame
    lo::Int # index in states of first vehicle in scene
    hi::Int # index in states of last vehicle in scene
    t::Float64 # time
end
immutable TrajdataState
    id::Int # vehicle ID
    state::VehicleState
end
Base.length(frame::TrajdataFrame) = frame.hi - frame.lo + 1 # number of cars in the frame

type Trajdata
    roadway::Roadway
    vehdefs::Dict{Int, VehicleDef} # vehicle id -> vehdef
    states::Vector{TrajdataState} # list of vehicle states (for each scene)
    frames::Vector{TrajdataFrame} # list of frames
end
Trajdata(roadway::Roadway) = Trajdata(roadway, Dict{Int, VehicleDef}(), TrajdataState[], TrajdataFrame[])
function Trajdata(trajdata::Trajdata, frame_lo::Int, frame_hi::Int)
    roadway = trajdata.roadway
    vehdefs = Dict{Int, VehicleDef}()

    nstates = 0
    for frame in trajdata.frames[frame_lo : frame_hi]
        nstates += length(frame)
    end

    states = Array{TrajdataState}(nstates)
    copy!(states, 1, trajdata.states, trajdata.frames[frame_lo].lo, nstates)
    for s in states
        if !haskey(vehdefs, s.id)
            vehdefs[s.id] = trajdata.vehdefs[s.id]
        end
    end

    frames = Array{TrajdataFrame}(frame_hi - frame_lo + 1)
    Δstate_index = trajdata.frames[frame_lo].lo - 1
    for (i,frame) in enumerate(trajdata.frames[frame_lo : frame_hi])
        frames[i] = TrajdataFrame(frame.lo - Δstate_index, frame.hi - Δstate_index, frame.t)
    end

    Trajdata(roadway, vehdefs, states, frames)
end

function Base.write(io::IO, trajdata::Trajdata)
    # writes to a text file
    # - does not write the roadway

    println(io, "TRAJDATA")

    # vehdefs
    println(io, length(trajdata.vehdefs)) # number of vehdefs
    for def in values(trajdata.vehdefs)
        @printf(io, "%d %d %.3f %.3f\n", def.id, def.class, def.length, def.width)
    end

    # states
    println(io, length(trajdata.states)) # number of states
    for trajdatastate in trajdata.states
        state = trajdatastate.state
        @printf(io, "%d (%.4f %.4f %.4e) (%d %.4f %d %d) (%.4f %.4f %.4e) %.4f\n",
                     trajdatastate.id,
                     state.posG.x, state.posG.y, state.posG.θ,
                     state.posF.roadind.ind.i, state.posF.roadind.ind.t,
                     state.posF.roadind.tag.segment, state.posF.roadind.tag.lane,
                     state.posF.s, state.posF.t, state.posF.ϕ,
                     state.v
                )
    end

    # frames
    println(io, length(trajdata.frames)) # number of frames
    for tf in trajdata.frames
        @printf(io, "%d %d %.4f\n", tf.lo, tf.hi, tf.t)
    end
end
function Base.read(io::IO, ::Type{Trajdata}, roadway::Roadway=Roadway())
    lines = readlines(io)
    line_index = 1
    if contains(lines[line_index], "TRAJDATA")
        line_index += 1
    end

    function advance!()
        line = strip(lines[line_index])
        line_index += 1
        line
    end

    vehdefs = Dict{Int, VehicleDef}()
    N = parse(Int, advance!())
    for i in 1 : N
        tokens = split(advance!(), ' ')
        id = parse(Int, tokens[1])
        class = parse(Int, tokens[2])
        length = parse(Float64, tokens[3])
        width = parse(Float64, tokens[4])
        vehdefs[id] = VehicleDef(id, class, length, width)
    end

    N = parse(Int, advance!())
    states = Array{TrajdataState}(N)
    for i in 1 : N
        line = advance!()
        cleanedline = replace(line, r"(\(|\))", "")
        tokens = split(cleanedline, ' ')
        id = parse(Int, tokens[1])
        x = parse(Float64, tokens[2])
        y = parse(Float64, tokens[3])
        θ = parse(Float64, tokens[4])
        ind_i = parse(Int, tokens[5])
        ind_t = parse(Float64, tokens[6])
        seg = parse(Int, tokens[7])
        lane = parse(Int, tokens[8])
        s = parse(Float64, tokens[9])
        t = parse(Float64, tokens[10])
        ϕ = parse(Float64, tokens[11])
        v = parse(Float64, tokens[12])
        states[i] = TrajdataState(id, VehicleState(VecSE2(x,y,θ), Frenet(RoadIndex(CurveIndex(ind_i, ind_t), LaneTag(seg, lane)), s, t, ϕ), v))
    end

    N = parse(Int, advance!())
    frames = Array{TrajdataFrame}(N)
    for i in 1:N
        tokens = split(advance!(), ' ')
        lo = parse(Int, tokens[1])
        hi = parse(Int, tokens[2])
        t = parse(Float64, tokens[3])
        frames[i] = TrajdataFrame(lo, hi, t)
    end

    Trajdata(roadway, vehdefs, states, frames)
end

get_ids(trajdata::Trajdata) = collect(keys(trajdata.vehdefs))
nframes(trajdata::Trajdata) = length(trajdata.frames)
frame_inbounds(trajdata::Trajdata, frame::Int) = 1 ≤ frame ≤ nframes(trajdata)
carsinframe(trajdata::Trajdata, frame::Int) = length(trajdata.frames[frame])
nth_carid(trajdata::Trajdata, frame::Int, n::Int=1) = trajdata.states[trajdata.frames[frame].lo + n-1].id
get_time(trajdata::Trajdata, frame::Int) = trajdata.frames[frame].t
get_elapsed_time(trajdata::Trajdata, frame_lo::Int, frame_hi::Int) = trajdata.frames[frame_hi].t - trajdata.frames[frame_lo].t
get_mean_timestep(trajdata::Trajdata) = (trajdata.frames[end].t - trajdata.frames[1].t) / (nframes(trajdata)-1)

function get_first_frame_with_id(trajdata::Trajdata, id::Int)
    for (frame_index, frame) in enumerate(trajdata.frames)
        for i in frame.lo : frame.hi
            if trajdata.states[i].id == id
                return frame_index
            end
        end
    end

    -1
end
function get_last_frame_with_id(trajdata::Trajdata, id::Int)
    for frame_index in reverse(1:length(trajdata.frames))
        frame = trajdata.frames[frame_index]
        for i in frame.lo : frame.hi
            if trajdata.states[i].id == id
                return frame_index
            end
        end
    end

    -1
end

function iscarinframe(trajdata::Trajdata, id::Int, frame::Int)
    frame = trajdata.frames[frame]
    for i in frame.lo : frame.hi
        s = trajdata.states[i]
        if s.id == id
            return true
        end
    end
    false
end

function get_vehiclestate(trajdata::Trajdata, id::Int, frame::Int)
    frame = trajdata.frames[frame]
    for i in frame.lo : frame.hi
        s = trajdata.states[i]
        if s.id == id
            return s.state
        end
    end
    error("vehicle not found for id $id and frame $(frame)!")
end
get_vehicledef(trajdata::Trajdata, id::Int) = trajdata.vehdefs[id]

function get_vehicle!(veh::Vehicle, trajdata::Trajdata, id::Int, frame::Int)
    veh.state = get_vehiclestate(trajdata, id, frame)
    veh.def = get_vehicledef(trajdata, id)
    veh
end
get_vehicle(trajdata::Trajdata, id::Int, frame::Int) = get_vehicle!(Vehicle(), trajdata, id, frame)


#################################

immutable TrajdataVehicleIterator
    trajdata::Trajdata
    id::Int
end
Base.length(iter::TrajdataVehicleIterator) = sum(frame->iscarinframe(iter.trajdata, iter.id, frame), 1 : nframes(iter.trajdata))
function Base.start(iter::TrajdataVehicleIterator)
    frame = 1
    while frame < nframes(iter.trajdata) &&
          !iscarinframe(iter.trajdata, iter.id, frame)

        frame += 1
    end
    frame
end
Base.done(iter::TrajdataVehicleIterator, frame::Int) = frame > nframes(iter.trajdata)
function Base.next(iter::TrajdataVehicleIterator, frame::Int)
    item = (frame, get_vehicle(iter.trajdata, iter.id, frame))
    frame += 1
    while frame < nframes(iter.trajdata) &&
          !iscarinframe(iter.trajdata, iter.id, frame)

        frame += 1
    end
    (item, frame)
end

