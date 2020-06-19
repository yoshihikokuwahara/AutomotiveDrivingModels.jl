function get_test_trajdata()
    roadway = get_test_roadway()
    trajdata = Trajdata(roadway)

    trajdata.vehdefs[1] = VehicleDef(1, AgentClass.CAR, 5.0, 3.0)
    trajdata.vehdefs[2] = VehicleDef(2, AgentClass.CAR, 5.0, 3.0)

    push!(trajdata.states, TrajdataState(1, VehicleState(VecSE2(0.0,0.0,0.0), roadway, 10.0))) # car 1, frame 1
    push!(trajdata.states, TrajdataState(2, VehicleState(VecSE2(3.0,0.0,0.0), roadway, 20.0))) # car 2, frame 1
    push!(trajdata.states, TrajdataState(1, VehicleState(VecSE2(1.0,0.0,0.0), roadway, 10.0))) # car 1, frame 2
    push!(trajdata.states, TrajdataState(2, VehicleState(VecSE2(5.0,0.0,0.0), roadway, 20.0))) # car 2, frame 2

    push!(trajdata.frames, TrajdataFrame(1,2,0.0))
    push!(trajdata.frames, TrajdataFrame(3,4,0.1))

    trajdata
end

let
    trajdata = get_test_trajdata()
    roadway = trajdata.roadway

    @test nframes(trajdata) == 2
    @test !frame_inbounds(trajdata, 0)
    @test frame_inbounds(trajdata, 1)
    @test frame_inbounds(trajdata, 2)
    @test !frame_inbounds(trajdata, 3)

    @test carsinframe(trajdata, 1) == 2
    @test carsinframe(trajdata, 2) == 2

    @test nth_carid(trajdata, 1) == 1
    @test nth_carid(trajdata, 1, 2) == 2
    @test nth_carid(trajdata, 2, 1) == 1
    @test nth_carid(trajdata, 2, 2) == 2

    @test get_first_frame_with_id(trajdata, 1) == 1
    @test get_first_frame_with_id(trajdata, 2) == 1
    @test get_first_frame_with_id(trajdata, -1) == -1
    @test get_last_frame_with_id(trajdata, 1) == 2
    @test get_last_frame_with_id(trajdata, 2) == 2
    @test get_last_frame_with_id(trajdata, -1) == -1

    @test sort!(get_ids(trajdata)) == [1,2]

    @test iscarinframe(trajdata, 1, 1)
    @test iscarinframe(trajdata, 1, 2)
    @test iscarinframe(trajdata, 2, 1)
    @test iscarinframe(trajdata, 2, 2)
    @test !iscarinframe(trajdata, 3, 1)

    @test isapprox(get_time(trajdata, 1), 0.0)
    @test isapprox(get_time(trajdata, 2), 0.1)

    @test isapprox(get_elapsed_time(trajdata, 1, 2),  0.1)
    @test isapprox(get_elapsed_time(trajdata, 2, 1), -0.1)

    @test isapprox(get_mean_timestep(trajdata), 0.1)

    veh = get_vehicle(trajdata, 1, 1)
    @test veh.state == VehicleState(VecSE2(0.0,0.0,0.0), roadway, 10.0)
    @test_throws ErrorException get_vehicle(trajdata, 10, 1)
    @test_throws BoundsError get_vehicle(trajdata, 1, 10)

    get_vehicle!(veh, trajdata, 1, 2)
    @test veh.state == VehicleState(VecSE2(1.0,0.0,0.0), roadway, 10.0)

    let
        iter = TrajdataVehicleIterator(trajdata, 1)
        vehs = collect(iter)
        @test length(vehs) == 2
        @test vehs[1][1] == 1
        @test vehs[1][2].state == get_vehiclestate(trajdata, 1, 1)
        @test vehs[2][1] == 2
        @test vehs[2][2].state == get_vehiclestate(trajdata, 1, 2)

        iter = TrajdataVehicleIterator(trajdata, 2)
        vehs = collect(iter)
        @test length(vehs) == 2
        @test vehs[1][1] == 1
        @test vehs[1][2].state == get_vehiclestate(trajdata, 2, 1)
        @test vehs[2][1] == 2
        @test vehs[2][2].state == get_vehiclestate(trajdata, 2, 2)
    end

    path, io = mktemp()
    write(io, trajdata)
    close(io)

    lines = open(readlines, path)

    for (line_orig, line_test) in zip(lines,
            ["TRAJDATA",
             "2",
             "2 2 5.000 3.000",
             "1 2 5.000 3.000",
             "4",
             "1 (0.0000 0.0000 0.0000e+00) (1 0.0000 2 1) (0.0000 0.0000 0.0000e+00) 10.0000",
             "2 (3.0000 0.0000 0.0000e+00) (4 0.0078 2 1) (3.0078 0.0000 0.0000e+00) 20.0000",
             "1 (1.0000 0.0000 0.0000e+00) (2 0.0000 2 1) (1.0000 0.0000 0.0000e+00) 10.0000",
             "2 (5.0000 0.0000 0.0000e+00) (1 1.0000 3 1) (1.0000 0.0000 0.0000e+00) 20.0000",
             "2",
             "1 2 0.0000",
             "3 4 0.1000"]
        )

        @test strip(line_orig) == line_test
    end

    io = open(path)
    trajdata2 = read(io, Trajdata)
    close(io)
    rm(path)

    @test nframes(trajdata2) == nframes(trajdata)
    for i in 1 : nframes(trajdata2)
        @test carsinframe(trajdata2, i) == carsinframe(trajdata, i)
        for j in 1 : carsinframe(trajdata, i)
            veh1 = get_vehicle(trajdata, j, i)
            veh2 = get_vehicle(trajdata2, j, i)
            @test veh1.def.id == veh2.def.id
            @test veh1.def.class == veh2.def.class
            @test isapprox(veh1.def.length, veh2.def.length)
            @test isapprox(veh1.def.width, veh2.def.width)

            @test isapprox(veh1.state.v, veh2.state.v)
            @test isapprox(veh1.state.posG, veh2.state.posG, atol=1e-3)
            @test isapprox(veh1.state.posF.s, veh2.state.posF.s, atol=1e-3)
            @test isapprox(veh1.state.posF.t, veh2.state.posF.t, atol=1e-3)
            @test isapprox(veh1.state.posF.ϕ, veh2.state.posF.ϕ, atol=1e-6)
            @test veh1.state.posF.roadind.tag == veh2.state.posF.roadind.tag
            @test veh1.state.posF.roadind.ind.i == veh2.state.posF.roadind.ind.i
            @test isapprox(veh1.state.posF.roadind.ind.t, veh2.state.posF.roadind.ind.t, atol=1e-3)
        end
    end


    trajdata3 = Trajdata(trajdata2, 1, nframes(trajdata2))
    @test nframes(trajdata3) == nframes(trajdata2)
    for i in 1 : nframes(trajdata3)
        @test carsinframe(trajdata3, i) == carsinframe(trajdata2, i)
        for j in 1 : carsinframe(trajdata2, i)
            veh1 = get_vehicle(trajdata2, j, i)
            veh2 = get_vehicle(trajdata3, j, i)
            @test veh1.def.id == veh2.def.id
            @test veh1.def.class == veh2.def.class
            @test isapprox(veh1.def.length, veh2.def.length)
            @test isapprox(veh1.def.width, veh2.def.width)

            @test isapprox(veh1.state.v, veh2.state.v)
            @test isapprox(veh1.state.posG, veh2.state.posG, atol=1e-3)
            @test isapprox(veh1.state.posF.s, veh2.state.posF.s, atol=1e-3)
            @test isapprox(veh1.state.posF.t, veh2.state.posF.t, atol=1e-3)
            @test isapprox(veh1.state.posF.ϕ, veh2.state.posF.ϕ, atol=1e-6)
            @test veh1.state.posF.roadind.tag == veh2.state.posF.roadind.tag
            @test veh1.state.posF.roadind.ind.i == veh2.state.posF.roadind.ind.i
            @test isapprox(veh1.state.posF.roadind.ind.t, veh2.state.posF.roadind.ind.t, atol=1e-3)
        end
    end

    trajdata3 = Trajdata(trajdata2, 1, 1)
    @test nframes(trajdata3) == 1
    let
        i = 1
        @test carsinframe(trajdata3, i) == carsinframe(trajdata2, i)
        for j in 1 : carsinframe(trajdata2, i)
            veh1 = get_vehicle(trajdata2, j, i)
            veh2 = get_vehicle(trajdata3, j, i)
            @test veh1.def.id == veh2.def.id
            @test veh1.def.class == veh2.def.class
            @test isapprox(veh1.def.length, veh2.def.length)
            @test isapprox(veh1.def.width, veh2.def.width)

            @test isapprox(veh1.state.v, veh2.state.v)
            @test isapprox(veh1.state.posG, veh2.state.posG, atol=1e-3)
            @test isapprox(veh1.state.posF.s, veh2.state.posF.s, atol=1e-3)
            @test isapprox(veh1.state.posF.t, veh2.state.posF.t, atol=1e-3)
            @test isapprox(veh1.state.posF.ϕ, veh2.state.posF.ϕ, atol=1e-6)
            @test veh1.state.posF.roadind.tag == veh2.state.posF.roadind.tag
            @test veh1.state.posF.roadind.ind.i == veh2.state.posF.roadind.ind.i
            @test isapprox(veh1.state.posF.roadind.ind.t, veh2.state.posF.roadind.ind.t, atol=1e-3)
        end
    end
end