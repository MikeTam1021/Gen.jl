@everywhere using Gen
@everywhere using Distributions
@everywhere using PyCall
@pyimport matplotlib.patches as patches

@everywhere include("path_planner.jl")

function uniform_2d_simulate(xmin::Real, xmax::Real, ymin::Real, ymax::Real)
    x, log_weight_x = uniform_simulate(xmin, xmax)
    y, log_weight_y = uniform_simulate(ymin, ymax)
    Point(x, y), log_weight_x + log_weight_y
end
function uniform_2d_regenerate(point::Point, xmin::Real, xmax::Real, ymin::Real, ymax::Real)
    log_weight_x = uniform_regenerate(point.x, xmin, xmax)
    log_weight_y = uniform_regenerate(point.y, ymin, ymax)
    log_weight_x + log_weight_y
end
@register_module2(:uniform_2d, uniform_2d_simulate, uniform_2d_regenerate)
export uniform_2d_simulate
export uniform_2d_regenerate
uniform_2d = (args...) -> (uniform_2d_simulate)(args...)[1]
export uniform_2d


@everywhere function agent_model(T::Trace)

    xmin = 0
    xmax = 100
    ymin = 0
    ymax = 100
    scene = Scene(xmin, xmax, ymin, ymax)

    # add trees
    i = 1
    while true
        if (flip(0.7) ~ "is-tree-$i")
            location = uniform_2d(xmin, xmax, ymin, ymax)
            size = 15.
            add!(scene, Tree(location, size) ~ "tree-$i")
            i += 1
        else
            break
        end
    end

    # add walls
    wall_height = 30.
    wall_thickness = 2.
    i = 1
    while true
        if (flip(0.7) ~ "is-wall-$i")
            start = uniform_2d(xmin, xmax, ymin, ymax)
            orientation = flip(0.5) ? 1 : 2
            length = uniform(0.0, 100.0)
            add!(scene, Wall(start, orientation, length, wall_thickness, wall_height) ~ "wall-$i")
            i += 1
        else
            break
        end
    end

    # set starting location of the drone
    start = uniform_2d(xmin, xmax, ymin, ymax) ~ "start"

    # set destination of the drone
    destination = uniform_2d(xmin, xmax, ymin, ymax) ~ "destination"

    # plan a path from starting location to destination
    planner_params = PlannerParams(2000, 3.0, 10000, 1.)
    tree, path, optimized_path = plan_path(start, destination, scene,
                                           planner_params)

    if isnull(optimized_path)
        # no path found
        fail(T)
    else
        # walk the path at a constant speed, and record locations at times
        speed = 10. ~ "speed"
        times = collect(linspace(0.0, 15.0, 30)) ~ "times"
        locations = walk_path(get(optimized_path), speed, times) ~ "locations"

        # add measurement noise to the true locations
        measurement_noise = 8.0 ~ "measurement_noise"
        measurements = Array{Point,1}(length(times))
        for (i, loc) in enumerate(locations)
            measurements[i] = Point(normal(loc.x, measurement_noise) ~ "x$i", 
                                    normal(loc.y, measurement_noise) ~ "y$i")
        end
    end

    # record for rendering purposes
    tree ~ "tree"
    path ~ "path"
    optimized_path ~ "optimized_path"
    
    return nothing
end

@everywhere function add_scene_elements!(trace::Trace)
    # TODO rewrite
    intervene!(trace, "num_trees", 3)
    constrain!(trace, "tree-1-location", Point(30, 20))
    constrain!(trace, "tree-2-location", Point(83, 80))
    constrain!(trace, "tree-3-location", Point(80, 40))
    constrain!(trace, "tree-1-size", 10.)
    constrain!(trace, "tree-2-size", 10.)
    constrain!(trace, "tree-3-size", 10.)
    constrain!(trace, "start", Point(90., 10.))
end

@everywhere function add_observations!(trace::Trace, measured_xs::Array{Float64,1}, measured_ys::Array{Float64,1}, tmax::Int)
    for s=1:tmax
        constrain!(trace, "x$s", measured_xs[s])
        constrain!(trace, "y$s", measured_ys[s])
    end
end

@everywhere function mh_inference(measured_xs::Array{Float64,1}, measured_ys::Array{Float64,1}, t::Int, num_iter::Int)
    # initialize
    trace = Trace()
    add_scene_elements!(trace)
    add_observations!(trace, measured_xs, measured_ys, t)
    agent_model(trace)

    for iter=0:num_iter

        # propose
        proposal_trace = Trace()
        add_scene_elements!(proposal_trace)
        add_observations!(proposal_trace, measured_xs, measured_ys, t)
        agent_model(proposal_trace)
        if log(rand()) < score(proposal_trace) - score(trace)
            trace = proposal_trace
        end
    end
    trace
end

include("povray_rendering.jl")

function particle_cloud_demo(num_particles::Int, num_iter::Int)

    camera_location = [50., -30., 120.]
    camera_look_at = [50., 50., 0.]
    light_location = [50., 50., 150.]

    function render(trace::Trace, fname::String) 
        frame = PovrayRendering(camera_location, camera_look_at, light_location)
        frame.quality = 10
        frame.num_threads = 4
        render_trace(frame, trace)
        finish(frame, fname)
        println(fname)
    end

#-> draw(trace, fname, camera_location, camera_look_at, light_location)

    # frame index
    f = 0

    # first show a few unconstrained and unintervened samples
    num_unconstrained_samples = 5
    for i=1:num_unconstrained_samples
        trace = Trace()
        agent_model(trace)
        render(trace, "frames/frame_$f.png") ; f += 1
    end

    # build up the scene incrementally, starting from an empty trace
    trace = Trace()
    render(trace, "frames/frame_$f.png") ; f += 1
    intervene!(trace, "is-tree-1", true)
    intervene!(trace, "tree-1", Tree(Point(30, 20), 10.))
    render(trace, "frames/frame_$f.png") ; f += 1
    intervene!(trace, "is-tree-2", true)
    intervene!(trace, "tree-2", Tree(Point(83, 80), 10.))
    render(trace, "frames/frame_$f.png") ; f += 1
    intervene!(trace, "is-tree-3", true)
    intervene!(trace, "tree-3", Tree(Point(80, 40), 10.))
    render(trace, "frames/frame_$f.png") ; f += 1

    wall_height = 30.
    intervene!(trace, "is-wall-1", true)
    intervene!(trace, "wall-1", Wall(Point(20., 40.), 1, 40., 2., wall_height))
    render(trace, "frames/frame_$f.png") ; f += 1
    intervene!(trace, "is-wall-2", true)
    intervene!(trace, "wall-2", Wall(Point(60., 40.), 2, 40., 2., wall_height))
    render(trace, "frames/frame_$f.png") ; f += 1
    intervene!(trace, "is-wall-3", true)
    intervene!(trace, "wall-3", Wall(Point(60.-15., 80.), 1, 15. + 2., 2., wall_height))
    render(trace, "frames/frame_$f.png") ; f += 1
    intervene!(trace, "is-wall-4", true)
    intervene!(trace, "wall-4", Wall(Point(20., 80.), 1, 15., 2., wall_height))
    render(trace, "frames/frame_$f.png") ; f += 1
    intervene!(trace, "is-wall-5", true)
    intervene!(trace, "wall-5", Wall(Point(20., 40.), 2, 40., 2., wall_height))
    render(trace, "frames/frame_$f.png") ; f += 1

    boundary_wall_height = 2.
    intervene!(trace, "is-wall-6", true)
    intervene!(trace, "wall-6", Wall(Point(0., 0.), 1, 100., 2., boundary_wall_height))
    render(trace, "frames/frame_$f.png") ; f += 1
    intervene!(trace, "is-wall-7", true)
    intervene!(trace, "wall-7", Wall(Point(100., 0.), 2, 100., 2., boundary_wall_height))
    render(trace, "frames/frame_$f.png") ; f += 1
    intervene!(trace, "is-wall-8", true)
    intervene!(trace, "wall-8", Wall(Point(0., 100.), 1, 100., 2., boundary_wall_height))
    render(trace, "frames/frame_$f.png") ; f += 1
    intervene!(trace, "is-wall-9", true)
    intervene!(trace, "wall-9", Wall(Point(0., 0.), 2, 100., 2., boundary_wall_height))
    render(trace, "frames/frame_$f.png") ; f += 1

    # add the drone starting position
    constrain!(trace, "start", Point(90., 10.))
    render(trace, "frames/frame_$f.png") ; f += 1

    # add a known ground truth goal
    intervene!(trace, "measurement_noise", 1.0)
    intervene!(trace, "destination", Point(40., 60.))
    render(trace, "frames/frame_$f.png") ; f += 1

    # run model and extract observations, render ground druth
    # (prevent the model from adding new wall or trees)
    intervene!(trace, "is-tree-4", false)
    intervene!(trace, "is-wall-10", false)
    agent_model(trace)
    times = value(trace, "times")
    measured_xs = map((i) -> value(trace, "x$i"), 1:length(times))
    measured_ys = map((i) -> value(trace, "y$i"), 1:length(times))
    render(trace, "frames/frame_$f.png") ; f += 1

    # delete the ground truth information from the trace
    delete!(trace, "tree")
    delete!(trace, "path")
    delete!(trace, "optimized_path")
    delete!(trace, "destination")
    for i=1:length(times)
        delete!(trace, "x$i")
        delete!(trace, "y$i")
    end
    render(trace, "frames/frame_$f.png") ; f += 1

    # add the data incrementally using constraints
    for t=1:length(times)
        constrain!(trace, "x$t", measured_xs[t])
        constrain!(trace, "y$t", measured_ys[t])
        render(trace, "frames/frame_$f.png") ; f += 1
    end

    # remove observations
    for t=1:length(times)
        delete!(trace, "x$t")
        delete!(trace, "y$t")
    end

    # change the walls to add a bottom passageway
    delete!(trace, "wall-1")
    intervene!(trace, "wall-1", Wall(Point(20., 40.), 1, 15., 2., wall_height))
    delete!(trace, "is-tree-10")
    delete!(trace, "is-wall-10")
    intervene!(trace, "is-wall-10", true)
    intervene!(trace, "wall-10", Wall(Point(60.- 15, 40.), 1, 15., 2., wall_height))
    intervene!(trace, "is-wall-11", false)
    render(trace, "frames/frame_$f.png") ; f += 1

    # add the data incrementally using constraints
    for t=1:length(times)
        constrain!(trace, "x$t", measured_xs[t])
        constrain!(trace, "y$t", measured_ys[t])
        render(trace, "frames/frame_$f.png") ; f += 1
    end

    println("done with first phase!")
    # REWRITE BELOW
    # generate the particle clouds (use higher noise in algorithm)
    for t=1:length(measured_xs)
        println("time: $t")
        
        # note: can parallelize
        particles::Array{Trace,1} = pmap((i) -> mh_inference(measured_xs, measured_ys, t, num_iter), 1:num_particles)

        # TODO this part needs to get rewritten
        frame = new_frame()
        render_samples(frame, particles)
        finish(frame, "particle_cloud/mh_$(num_iter)_$t.png")
    end

end

srand(3)
particle_cloud_demo(20, 100)
