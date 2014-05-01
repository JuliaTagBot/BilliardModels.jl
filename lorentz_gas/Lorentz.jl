module Lorentz

using Vector2d
#using ImmutableArrays
#import Base.convert

export run_Lorentz_gas


# typealias Vector2D Vector2{Float64}
# convert(::Type{Vector2{Float64}}, v::Array{Float64, 1}) = 
#     Vector2{Float64}(v[1], v[2])

# Vector2D(v::Array{Float64, 1}) = Vector2D(v[1], v[2])


type Particle
    # x::Vector{Float64}
    # v::Vector{Float64}

    x::Vector2D
    v::Vector2D
end

Particle(x::Vector{Float64}, v::Vector{Float64}) = Particle(Vector2D(x), Vector2D(v))

immutable Disc
    # centre::Array{Float64}
    # radius::Float64

    centre::Vector2D
    radius::Float64
end

#Disc(centre::Vector{Float64}, radius::Float64) = Disc(Vector2D(centre), radius)


function collision_time(p::Particle, disc::Disc)
    
    #A = dot(p.v, p.v)  # 1 in principle, but varies in practice
    disp = p.x-disc.centre
    # B = dot(p.v, p.x-disc.centre)
    # C = dot(p.x-disc.centre, p.x-disc.centre) - disc.radius^2
    B = dot(p.v, disp)
    C = dot(disp, disp) - disc.radius*disc.radius


    #discriminant = B*B - A*C
    discriminant = B*B - C

    if discriminant < 0
        return -1.
    end
    
    #return (-B - sqrt(discriminant)) / A  # suppose outside disc
    return -B - sqrt(discriminant)  # suppose outside disc

end

function normal(disc::Disc, x)
    # normal to disc at point x *on boundary*
    return (x - disc.centre) / disc.radius
end


immutable Plane
    c::Vector2D  # point on plane
    normal::Vector2D
end

#Plane(c::Vector{Float64}, normal::Vector{Float64}) =
#    Plane(Vector2D(c), Vector2D(normal))


collision_time(p::Particle, plane::Plane) =
    dot(plane.c - p.x, plane.normal) / dot(p.v, plane.normal)

normal(plane::Plane, x) = plane.normal


function collision(p::Particle, current_cell, boundaries, jump_directions, previous_hit)

    
    min_collision_time = 100.0
    which_hit = -1

    for i in 1:5
        if i == previous_hit
            continue
        end

        collision_t = collision_time(p, boundaries[i])

     
        if collision_t > 0.0 && collision_t < min_collision_time
            which_hit, min_collision_time = i, collision_t
        end
    end
    
    
    x_new = p.x + p.v*min_collision_time 
    new_cell = current_cell

    @assert which_hit > 0
    
    if which_hit == 1  # reflect off disc
        n = normal(boundaries[1], x_new) 

        v_new = p.v - 2.0*n*dot(n, p.v)  # reflejar solo si es disco; si es plano, pasar a traves

        speed = sqrt(dot(v_new, v_new))
        v_new /= speed

    else
        # hit plane, so periodise
        jump = jump_directions[which_hit]  
        # print "jump = ", jump

        new_cell += jump
        x_new -= jump  # this is supposing that we are in exactly unit cell
        
        v_new = p.v

        which_hit += 2
        if which_hit > 5
            which_hit -= 4
        end
    end
        
    return x_new, v_new, new_cell, min_collision_time, which_hit
end


function initial_condition(radius)

    x, y = 0.0, 0.0

    while true
        x, y = rand(2) .- 0.5

        if (x*x + y*y) >= radius^2
            break
        end
    end

    # velocity in 2D:
    theta = rand() * 2*pi

    xx = Vector2D(x, y)
    vv = Vector2D(cos(theta), sin(theta))

    return xx, vv
end

function collision_time_with_disc(x, v, r)
    B = dot(v, x);
    C = dot(x, x) - r*r;
    
    discriminant = B*B - C;
    
    if (discriminant < 0) 
        return -1.0;
    
    else 
        return -B - sqrt(discriminant);
    end
end

# intersection_horiz_boundary(p::Particle, y) = 
#     (y - p.x[2]) / p.v[2]

# intersection_vert_boundary(p::Particle, x) = 
#     (x - p.x[1]) / p.v[1]

# function find_collision()
#     min_collision_time = 1000.

#     collision_times = 
#         [   collision_time_with_disc(p),
#             intersection_vert_boundary(-0.5),
#             intersection_horiz_boundary(0.5),
#             intersection_vert_boundary(0.5),
#             intersection_horiz_boundary(-0.5)
#         ]

#     for i in 1:5  # num of collision times
#         coll_time = collision_times[i]
#         min_collision_time = coll_time
#         object_hit = i
#     end
       





### Main program

function make_boundaries(radius)

    boundaries = {}

    push!(boundaries, Disc([0., 0.], radius) )

    push!(boundaries, Plane([-0.5, -0.5], [0., -1.]) )
    push!(boundaries, Plane([0.5, -0.5], [1., 0.]) )
    push!(boundaries, Plane([0.5, 0.5], [0., 1.]) )
    push!(boundaries, Plane([-0.5, 0.5], [-1., 0.]) )

    jump_directions = [Vector2D(0.,0.)]  # dummy

    for boundary in boundaries[2:end]
        push!(jump_directions, normal(boundary, 0))
    end

    println("# Boundaries: ", boundaries)
    println("# Jump directions: ", jump_directions)

    return boundaries, jump_directions
end


function Lorentz_gas(radius, boundaries, jump_directions, t_final)

    current_cell = Vector2D(0., 0.)

    #collision_times = -ones(5)


    x0, v0 = initial_condition(radius)
    p = Particle(x0, v0)
    
    total_time = 0.0

    xs = [x0[1]]
    ys = [x0[2]]

    which_hit = -1

    while total_time < t_final
        x_new, v_new, new_cell, collision_t, which_hit = 
            collision(p, current_cell, boundaries, 
                    jump_directions, which_hit)
        
        if total_time + collision_t < t_final
            total_time += collision_t
            current_cell = new_cell
            
            p.x, p.v = x_new, v_new


           # println(x_new[1], "\t", x_new[2], "\t", v_new[1], "\t", v_new[2])

            if which_hit == 1  # disc

                x_new += new_cell

                push!(xs, x_new[1])
                push!(ys, x_new[2])
            end
            
        else
            collision_t = t_final - total_time
            
            x_new = p.x + p.v*collision_t
            x_new += current_cell
            
            println("# Position at time ", t_final, " = ", x_new)
            println("# Cell: ", current_cell)
            println("# Distance from origin = ", (dot(x_new, x_new))^0.5)
#            println("# Distance squared from origin = ", dot(x_new, x_new))
            
            break
        end
        
    end

    return xs, ys
end


# function continuous_time_trajectory()

#     p = Particle(initial_condition()...)

#     t = 0.0;
#     next_output_time = output_time;
    
#     step = 1;  /// location in data array
    
#     while (t < max_time) {
        
#         next_t = t + min_collision_time;
        
#         while (next_t > next_output_time) {
#             /// use a while in case have very long path
            
#             new_position = p.position + (next_output_time - t)*p.velocity;
            
#             new_position += Vec(x_cell, y_cell);
            
#             displacement = new_position - p.initial_position;
#             disp_norm = dot(displacement, displacement);

#             /// |Delta x|
#             basic_moment = sqrt(sqrt(disp_norm)); /// |Delta x|^{1/2}
#             /// the basic unit is |Delta x|^{1/2}
            
#             moment = basic_moment;
#             /// moment is multiplied over and over by basic_moment to give the powers
            
#             for (int m=1; m<=num_moments; m++) {
#                 moments_data[m][step] += moment;
#                 moment *= basic_moment;
#             }
            
#             vel_vel_correlation_data[step] += dot(p.velocity, p.initial_velocity);
#             vel_pos_correlation_data[step] += dot(displacement, p.initial_velocity);
#             current_vel_pos_correlation_data[step] += dot(displacement, p.velocity);
            
#             step++;
#             next_output_time += output_time;
            
#             if (step > num_data) return;
            
#         }
        
#         implementCollision();
    
#         t = next_t;
            
#     //cout << "After collision:\n";
#     //cout << "Pos: ";
        
#         findCollision();
            
#     }

            
# }


function run_Lorentz_gas(radius, max_time)

    println("# Using radius: ", radius)

    boundaries, jump_directions = make_boundaries(radius)
    @time xs, ys = Lorentz_gas(radius, boundaries, jump_directions, max_time)
end


if length(ARGS) > 1
    radius = float(ARGS[1])
    run_Lorentz_gas(radius)
end


# using PyPlot
# plot(xs, ys)

end