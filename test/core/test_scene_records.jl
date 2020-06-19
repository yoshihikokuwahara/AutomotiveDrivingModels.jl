let
    trajdata = get_test_trajdata()

    Δt = 0.1
    rec = SceneRecord(5, Δt)
    @test record_length(rec) == 5
    @test length(rec) == 0
    @test !pastframe_inbounds(rec, 0)
    @test !pastframe_inbounds(rec, -1)
    @test !pastframe_inbounds(rec, 1)

    scene = get!(Scene(), trajdata, 1)
    update!(rec, scene)
    @test length(rec) == 1
    @test pastframe_inbounds(rec, 0)
    @test !pastframe_inbounds(rec, -1)
    @test !pastframe_inbounds(rec, 1)
    @test isapprox(get_elapsed_time(rec, 0), Δt)
    @test rec[1,0].state == get_vehiclestate(trajdata, 1, 1)
    @test rec[1,0].def == get_vehicledef(trajdata, 1)
    @test rec[2,0].state == get_vehiclestate(trajdata, 2, 1)
    @test rec[2,0].def == get_vehicledef(trajdata, 2)
    show(IOBuffer(), rec)


    get!(scene, trajdata, 2)
    update!(rec, scene)
    @test length(rec) == 2
    @test pastframe_inbounds(rec, 0)
    @test pastframe_inbounds(rec, -1)
    @test !pastframe_inbounds(rec, 1)
    @test isapprox(get_elapsed_time(rec,  0),  Δt)
    @test isapprox(get_elapsed_time(rec, -1), 2Δt)
    @test isapprox(get_elapsed_time(rec, -1, 0), Δt)
    @test rec[1,0].state == get_vehiclestate(trajdata, 1, 2)
    @test rec[1,0].def == get_vehicledef(trajdata, 1)
    @test rec[2,0].state == get_vehiclestate(trajdata, 2, 2)
    @test rec[2,0].def == get_vehicledef(trajdata, 2)
    @test rec[1,-1].state == get_vehiclestate(trajdata, 1, 1)
    @test rec[1,-1].def == get_vehicledef(trajdata, 1)
    @test rec[2,-1].state == get_vehiclestate(trajdata, 2, 1)
    @test rec[2,-1].def == get_vehicledef(trajdata, 2)

    @test  iscarinframe(rec, 1, 0)
    @test !iscarinframe(rec, 10, 0)

    @test get_index_of_first_vehicle_with_id(rec, 1, 0) == 1
    @test get_index_of_first_vehicle_with_id(rec, 2, 0) == 2
    @test get_index_of_first_vehicle_with_id(rec, 5, 0) == 0

    scene2 = get!(Scene(), rec)
    @test scene2[1].state == get_vehiclestate(trajdata, 1, 2)
    @test scene2[1].def == get_vehicledef(trajdata, 1)
    @test scene2[2].state == get_vehiclestate(trajdata, 2, 2)
    @test scene2[2].def == get_vehicledef(trajdata, 2)

    get!(scene2, rec, -1)
    @test scene2[1].state == get_vehiclestate(trajdata, 1, 1)
    @test scene2[1].def == get_vehicledef(trajdata, 1)
    @test scene2[2].state == get_vehiclestate(trajdata, 2, 1)
    @test scene2[2].def == get_vehicledef(trajdata, 2)

    empty!(rec)
    @test length(rec) == 0

    test_veh_state = VehicleState(VecSE2(7.0,7.0,2.0), trajdata.roadway, 10.0)
    test_veh_def = VehicleDef(999, AgentClass.CAR, 5.0, 3.0)
    test_veh = Vehicle(test_veh_state, test_veh_def)
    rec[1,-1] = test_veh
    @test get_vehiclestate(rec,999,-1) == test_veh_state
end
