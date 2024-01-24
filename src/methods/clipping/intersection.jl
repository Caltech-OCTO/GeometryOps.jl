# #  Intersection Polygon Clipping
export intersection, intersection_points

# This 'intersection' implementation returns the intersection of two polygons.
# It returns a Vector{Vector{Vector{Tuple{Float}}}. The Vector{Vector{Tuple{Float}
# is empty if the two polygons don't intersect. The algorithm to determine the 
# intersection was adapted from "Efficient clipping of efficient polygons," by 
# Greiner and Hormann (1998). DOI: https://doi.org/10.1145/274363.274364

"""
    intersection(geom_a, geom_b)::Union{Tuple{::Real, ::Real}, ::Nothing}

Return an intersection point between two geometries. Return nothing if none are
found. Else, the return type depends on the input. It will be a union between:
a point, a line, a linear ring, a polygon, or a multipolygon

## Example

```jldoctest
import GeoInterface as GI, GeometryOps as GO

line1 = GI.Line([(124.584961,-12.768946), (126.738281,-17.224758)])
line2 = GI.Line([(123.354492,-15.961329), (127.22168,-14.008696)])
GO.intersection(line1, line2)

# output
(125.58375366067547, -14.83572303404496)
```
"""
intersection(geom_a, geom_b) =
    intersection(GI.trait(geom_a), geom_a, GI.trait(geom_b), geom_b)
"""
    intersection(
        ::GI.PolygonTrait, poly_a,
        ::GI.PolygonTrait, poly_b,
    )::Vector{Vector{Vector{Tuple{Float64}}}}    

Calculates the intersection between two polygons. If the intersection is empty, 
the vector of a vector is empty (note the outermost vector is technically not empty).
## Example

```jldoctest
import GeoInterface as GI, GeometryOps as GO

p1 = GI.Polygon([[(0.0, 0.0), (5.0, 5.0), (10.0, 0.0), (5.0, -5.0), (0.0, 0.0)]])
p2 = GI.Polygon([[(3.0, 0.0), (8.0, 5.0), (13.0, 0.0), (8.0, -5.0), (3.0, 0.0)]])
GO.intersection(p1, p2)

# output
1-element Vector{Vector{Vector{Tuple{Float64, Float64}}}}:
[[[(6.5, 3.5), (10.0, 0.0), (6.5, -3.5), (3.0, 0.0), (6.5, 3.5)]]]
```
"""

function intersection(::GI.PolygonTrait, poly_a, ::GI.PolygonTrait, poly_b)
    # First we get the exteriors of 'poly_a' and 'poly_b'
    ext_poly_a = GI.getexterior(poly_a)
    ext_poly_b = GI.getexterior(poly_b)
    # Then we find the intersection of the exteriors
    a_list, b_list, a_idx_list = _build_ab_list(ext_poly_a, ext_poly_b)
    polys = _trace_intersection(ext_poly_a, ext_poly_b, a_list, b_list, a_idx_list)
    # If the original polygons had no holes, then we are done. Otherwise,
    # we call '_get_inter_holes' to take into account the holes.
    final_polys = if GI.nhole(poly_a) == 0 && GI.nhole(poly_b) == 0
        [[p] for p in polys]
    else
        _get_inter_holes(polys, poly_a, poly_b)
    end    
    return final_polys
end



"""
    intersection(
        ::GI.LineTrait, line_a,
        ::GI.LineTrait, line_b,
    )::Union{
        ::Tuple{::Real, ::Real},
        ::Nothing
    }

Calculates the intersection between two line segments. Return nothing if
there isn't one.
"""
function intersection(::GI.LineTrait, line_a, ::GI.LineTrait, line_b)
    # Get start and end points for both lines
    a1 = GI.getpoint(line_a, 1)
    a2 = GI.getpoint(line_a, 2)
    b1 = GI.getpoint(line_b, 1)
    b2 = GI.getpoint(line_b, 2)
    # Determine the intersection point
    point, fracs = _intersection_point((a1, a2), (b1, b2))
    # Determine if intersection point is on line segments
    if !isnothing(point) && 0 <= fracs[1] <= 1 && 0 <= fracs[2] <= 1
        return point
    end
    return nothing
end

intersection(
    trait_a::Union{GI.LineStringTrait, GI.LinearRingTrait},
    geom_a,
    trait_b::Union{GI.LineStringTrait, GI.LinearRingTrait},
    geom_b,
) = intersection_points(trait_a, geom_a, trait_b, geom_b)

"""
    intersection(
        ::GI.AbstractTrait, geom_a,
        ::GI.AbstractTrait, geom_b,
    )::Union{
        ::Vector{Vector{Tuple{::Real, ::Real}}}, # is this a good return type?
        ::Nothing
    }

Calculates the intersection between two line segments. Return nothing if
there isn't one.
"""
function intersection(
    trait_a::GI.AbstractTrait, geom_a,
    trait_b::GI.AbstractTrait, geom_b,
)
    @assert(
        false,
        "Intersection between $trait_a and $trait_b isn't implemented yet.",
    )
    return nothing
end

"""
    _trace_intersection(poly_a, poly_b, a_list, b_list, tracker)::Vector{Vector{Tuple{Float64}}}

Traces the outlines of two polygons in order to find their intersection.
It returns the outlines of all polygons formed in the intersection. If
they do not intersect, it returns an empty array.

"""
function _trace_intersection(poly_a, poly_b, a_list, b_list, tracker)
    n_a_points, n_b_points = length(a_list), length(b_list)
    # Pre-allocate array for return polygons
    return_polys = Vector{Vector{Tuple{Float64, Float64}}}(undef, 0)
    # Keep track of number of processed intersection points
    n_inter_pts = length(tracker)
    processed_pts = 0

    while processed_pts < n_inter_pts
        curr_list, next_list = a_list, b_list
        curr_npoints, next_npoints = n_a_points, n_b_points
        # Find first unprocessed intersecting point in subject polygon
        processed_pts += 1
        tracker_idx = findnext(x -> x != 0, tracker, processed_pts)
        idx = tracker[tracker_idx]
        tracker[tracker_idx] = 0
        start_pt = a_list[idx]

        # Set first point in polygon
        curr = curr_list[idx]
        pt_list = [curr.point]

        curr_not_start = true
        while curr_not_start
            forward = false
            curr_not_intr = true
            while curr_not_intr
                forward = curr.inter ? curr.ent_exit : forward
                # Traverse polygon either forwards or backwards
                idx += forward ? 1 : (-1)
                idx = (idx > curr_npoints) ? mod(idx, curr_npoints) : idx
                idx = (idx == 0) ? curr_npoints : idx

                # Get current node and add to pt_list
                curr = curr_list[idx]
                push!(pt_list, curr.point)
                if curr.inter 
                    # Keep track of processed intersection points
                    curr_not_start = curr != start_pt && curr != b_list[start_pt.neighbor]
                    if curr_not_start
                        processed_pts = processed_pts + 1
                        tracker[curr.idx] = 0
                    end
                    curr_not_intr = false
                end
            end

            # Switch to next list and next point
            curr_list, next_list = next_list, curr_list
            curr_npoints, next_npoints = next_npoints, curr_npoints
            idx = curr.neighbor
            curr = curr_list[idx]
        end
        push!(return_polys, pt_list)
    end

    # Check if one polygon totally within other, and if so
    # return the smaller polygon as the intersection
    if isempty(return_polys)
        if _point_filled_curve_orientation(
            a_list[1].point, poly_b;
            in = true, on = false, out = false
        )
            list = [_tuple_point(p) for p in GI.getpoint(poly_a)]
            push!(return_polys, list)
        elseif _point_filled_curve_orientation(
            b_list[1].point, poly_a;
            in = true, on = false, out = false
        )
            list = [_tuple_point(p) for p in GI.getpoint(poly_b)]
            push!(return_polys, list)
        end
    end

    # If the polygons don't intersect and aren't contained within each
    # other, return_polys will be empty
    return return_polys
end

"""
    _get_inter_holes(return_polys, poly_a, poly_b)::Vector{Vector{Vector{Tuple{Float64, Float64}}}}

When the _trace_difference function was called, it only took into account the
exteriors of the two polygons when computing the difference. The function
'_get_difference_holes' takes into account the holes of the original polygons
and adjust the output of _trace_difference (return_polys) accordingly.

"""

function _get_inter_holes(return_polys, poly_a, poly_b)
    # Initiaze our return object
    final_polys =  Vector{Vector{Vector{Tuple{Float64, Float64}}}}(undef, 0)

    for poly in return_polys
        # Turning polygon into the desired return type I can add more polygons to it
        poly = [[poly]]

        # We subtract the holes of 'poly_a' and 'poly_b' from the output we got
        # from _trace_intersection (return_polys)
        for hole in GI.gethole(poly_a) 
            replacement_p = Vector{Vector{Vector{Tuple{Float64, Float64}}}}(undef, 0)
            for p in poly
                # When we take the difference of our existing intersectio npolygons and 
                # the holes of polygon_a, we might split it up into smaller polygons. 
                new_ps = difference(GI.Polygon(p), GI.Polygon([hole]))
                append!(replacement_p, new_ps)
            end
            poly = replacement_p
        end
        
        for hole in GI.gethole(poly_b)
            replacement_p = Vector{Vector{Vector{Tuple{Float64, Float64}}}}(undef, 0)
            for p in poly
                # When we take the difference of our existing intersectio npolygons and 
                # the holes of polygon_a, we might split it up into smaller polygons. 
                new_ps = difference(GI.Polygon(p), GI.Polygon([hole]))
                append!(replacement_p, new_ps)
            end
            poly = replacement_p
        end
        
        append!(final_polys, poly)
    end

    return final_polys
        
end

"""
>>>>>>> main:src/methods/geom_relations/intersects.jl
    intersection_points(
        geom_a,
        geom_b,
    )::Union{
        ::Vector{::Tuple{::Real, ::Real}},
        ::Nothing,
    }

Return a list of intersection points between two geometries. If no intersection
point was possible given geometry extents, return nothing. If none are found,
return an empty list.
"""
intersection_points(geom_a, geom_b) =
    intersection_points(GI.trait(geom_a), geom_a, GI.trait(geom_b), geom_b)

"""
    intersection_points(
        ::GI.AbstractTrait, geom_a,
        ::GI.AbstractTrait, geom_b,
    )::Union{
        ::Vector{::Tuple{::Real, ::Real}},
        ::Nothing,
    }

Calculates the list of intersection points between two geometries, inlcuding
line segments, line strings, linear rings, polygons, and multipolygons. If no
intersection points were possible given geometry extents, return nothing. If
none are found, return an empty list.
"""
function intersection_points(::GI.AbstractTrait, a, ::GI.AbstractTrait, b)
    # Check if the geometries extents even overlap
    Extents.intersects(GI.extent(a), GI.extent(b)) || return nothing
    # Create a list of edges from the two input geometries
    edges_a, edges_b = map(sort! ∘ to_edges, (a, b))
    npoints_a, npoints_b  = length(edges_a), length(edges_b)
    a_closed = npoints_a > 1 && edges_a[1][1] == edges_a[end][1]
    b_closed = npoints_b > 1 && edges_b[1][1] == edges_b[end][1]
    if npoints_a > 0 && npoints_b > 0
        # Initialize an empty list of points
        T = typeof(edges_a[1][1][1]) # x-coordinate of first point in first edge
        result = Tuple{T,T}[]
        # Loop over pairs of edges and add any intersection points to results
        for i in eachindex(edges_a)
            for j in eachindex(edges_b)
                point, fracs = _intersection_point(edges_a[i], edges_b[j])
                if !isnothing(point)
                    #=
                    Determine if point is on edge (all edge endpoints excluded
                    except for the last edge for an open geometry)
                    =#
                    α, β = fracs
                    on_a_edge = (!a_closed && i == npoints_a && 0 <= α <= 1) ||
                        (0 <= α < 1)
                    on_b_edge = (!b_closed && j == npoints_b && 0 <= β <= 1) ||
                        (0 <= β < 1)
                    if on_a_edge && on_b_edge
                        push!(result, point)
                    end
                end
            end
        end
        return result
    end
    return nothing
end

"""
    _intersection_point(
        (a1, a2)::Tuple,
        (b1, b2)::Tuple,
    )

Calculates the intersection point between two lines if it exists, and as if the
line extended to infinity, and the fractional component of each line from the
initial end point to the intersection point.
Inputs:
    (a1, a2)::Tuple{Tuple{::Real, ::Real}, Tuple{::Real, ::Real}} first line
    (b1, b2)::Tuple{Tuple{::Real, ::Real}, Tuple{::Real, ::Real}} second line
Outputs:
    (x, y)::Tuple{::Real, ::Real} intersection point
    (t, u)::Tuple{::Real, ::Real} fractional length of lines to intersection
    Both are ::Nothing if point doesn't exist!

Calculation derivation can be found here:
    https://stackoverflow.com/questions/563198/
"""
function _intersection_point((a1, a2)::Tuple, (b1, b2)::Tuple)
    # First line runs from p to p + r
    px, py = GI.x(a1), GI.y(a1)
    rx, ry = GI.x(a2) - px, GI.y(a2) - py
    # Second line runs from q to q + s 
    qx, qy = GI.x(b1), GI.y(b1)
    sx, sy = GI.x(b2) - qx, GI.y(b2) - qy
    # Intersection will be where p + tr = q + us where 0 < t, u < 1 and
    r_cross_s = rx * sy - ry * sx
    if r_cross_s != 0
        Δqp_x = qx - px
        Δqp_y = qy - py
        t = (Δqp_x * sy - Δqp_y * sx) / r_cross_s
        u = (Δqp_x * ry - Δqp_y * rx) / r_cross_s
        x = px + t * rx
        y = py + t * ry
        return (x, y), (t, u)
    end
    return nothing, nothing
end


