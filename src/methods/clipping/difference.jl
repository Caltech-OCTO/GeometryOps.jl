# #  Difference Polygon Clipping
export difference

# The 'difference' function returns the difference of two polygons. Note that this file
# currently only contains the difference of two polygons, which will always return
# a vector of a vector of a vector of tuples of floats.
# The algorithm to determine the difference was adapted from "Efficient 
# clipping of efficient polygons," by Greiner and Hormann (1998).
# DOI: https://doi.org/10.1145/274363.274364

"""
    difference(geom1, geom2)::Vector{Vector{Vector{Tuple{Float64}}}}

Returns the difference of geom1 minus geom2. The vector of a vector inside
the outermost vector is empty if the difference is empty. If the polygons
don't intersect, it just returns geom1.

## Example 

```jldoctest
import GeoInterface as GI, GeometryOps as GO

poly1 = GI.Polygon([[[0.0, 0.0], [5.0, 5.0], [10.0, 0.0], [5.0, -5.0], [0.0, 0.0]]])
poly2 = GI.Polygon([[[3.0, 0.0], [8.0, 5.0], [13.0, 0.0], [8.0, -5.0], [3.0, 0.0]]])
GO.difference(poly1, poly2)

# output
1-element Vector{Vector{Vector{Tuple{Float64, Float64}}}}:
[[[(6.5, 3.5), (5.0, 5.0), (0.0, 0.0), (5.0, -5.0), (6.5, -3.5), (3.0, 0.0), (6.5, 3.5)]]]
```
"""
difference(geom_a, geom_b) =
    difference(GI.trait(geom_a), geom_a, GI.trait(geom_b), geom_b)
    
function difference(::GI.PolygonTrait, poly_a, ::GI.PolygonTrait, poly_b)
    # Get the exterior of the polygons
    ext_poly_a = GI.getexterior(poly_a)
    ext_poly_b = GI.getexterior(poly_b)
    # Find the difference of the exterior of the polygons
    a_list, b_list, a_idx_list = _build_ab_list(ext_poly_a, ext_poly_b)
    polys, diff_polys = _trace_difference(ext_poly_a, ext_poly_b,a_list, b_list, a_idx_list)
    # If the original polygons had holes, take that into account.
    final_polys = if GI.nhole(poly_a) == 0 && GI.nhole(poly_b) == 0
        if !diff_polys
            [polys]
        else
            [[p] for p in polys]
        end
    else
        _get_difference_holes(polys, poly_a, poly_b, diff_polys)
    end
    return final_polys
end

"""
    _trace_difference(poly_a, poly_b, a_list, b_list, tracker)::Vector{Vector{Tuple{Float64}}}, Bool

Traces the outlines of two polygons in order to find their difference.
It returns the outlines of all the components of the difference. The Bool
indicates whether or not these components (each Vector{Tuple{Float64} inside
the larger Vector) are part of the same polygon (true) or each different
polygons (true).
"""

function _trace_difference(poly_a, poly_b, a_list, b_list, tracker)
    return_polys = _trace_polynodes(a_list, b_list, tracker, (x, y) -> (x ⊻ y) ? 1 : (-1))

    # If at this point return_polys contains multiple polygons,
    # those polygons are all separate polygons. They cannot be holes
    # of each other. This is because we took the difference of two polygon
    # exteriors. If at this point return_polys is empty, it is possible
    # that poly_b is entirely contained in poly_a and the list that this function
    # returns will have length greater than 1 but only represent one polygon.
    diff_polygons = length(return_polys) > 1

    # Check if one polygon totally within other
    if isempty(return_polys)
        list_b = []
        for point in GI.getpoint(poly_b)
            push!(list_b, _tuple_point(point))
        end

        list_a = []
        for point in GI.getpoint(poly_a)
            push!(list_a, _tuple_point(point))
        end

        if _point_filled_curve_orientation(
            a_list[1].point, poly_b;
            in = true, on = false, out = false
        )
            return return_polys, diff_polygons
        elseif _point_filled_curve_orientation(
            b_list[1].point, poly_a;
            in = true, on = false, out = false
        )
            push!(return_polys, list_a)
            push!(return_polys, list_b)
            return return_polys, diff_polygons

        else
            # equivalent of push!(return_polys, list_a) since return_polys empty
            # This is the case where the two polygons don't intersect and are not
            # contained in one another. Thus, we are returning the original poly_a
            return [list_a], false
        end
    end

    return return_polys, diff_polygons
end

    """
    _get_difference_holes(return_polys, poly_a, poly_b, diff_polygons)::Vector{Vector{Vector{Tuple{Float64, Float64}}}}

When the _trace_difference function was called, it only took into account the
exteriors of the two polygons when computing the difference. The function
'_get_difference_holes' takes into account the holes of the original polygons
and adjust the output of _trace_difference (return_polys) accordingly.

"""

function _get_difference_holes(return_polys, poly_a, poly_b, diff_polygons)
    # Initialize the array that we are going to return
    final_polys =  Vector{Vector{Vector{Tuple{Float64, Float64}}}}(undef, 0)

    if !diff_polygons
        # If the output from _trace_difference represents a single polygon,
        # we just add the holes from the original polygons the output of
        # _trace_difference (return polys)
        poly = [return_polys]
        
        for hole in GI.gethole(poly_a)
            replacement_p = Vector{Vector{Vector{Tuple{Float64, Float64}}}}(undef, 0)
            for p in poly
                # We need to make 'new_ps' to replace p because 'difference'
                # might return more than one polygon
                new_ps = difference(GI.Polygon(p), GI.Polygon([hole]))
                append!(replacement_p, new_ps)
            end
            poly = replacement_p
        end
        
        append!(final_polys, poly)

        for hole in GI.gethole(poly_b)
            # We add back the polygons formed at the intersection of the holes
            # of poly_b and poly_a
            append!(final_polys, intersection(GI.Polygon([hole]), poly_a))
        end

    else
        # When the innards of 'return_polys' represent multiple polygons
        for poly in return_polys
            # Make a new Vector{Vector{Vector{Tuple{Float64}}}} for each polygon in 
            # return_polys
            poly = [[poly]]
            for hole in GI.gethole(poly_a)
                replacement_p = Vector{Vector{Vector{Tuple{Float64, Float64}}}}(undef, 0)
                # Even though originally each polygon had no holes so they were only represented
                # by one 'polygon array' each, after taking into account the holes, each poly
                # might contain multiple 'polygon arrays' which I called 'p' to describe it.
                for p in poly
                    new_ps = difference(GI.Polygon(p), GI.Polygon([hole]))
                    append!(replacement_p, new_ps)
                end
                poly = replacement_p
            end
            
            append!(final_polys, poly)
        end

        for hole in GI.gethole(poly_b)
            # We add back the polygons formed at the intersection of the holes
            # of poly_b and poly_a
            append!(final_polys, intersection(GI.Polygon([hole]), poly_a))
        end
    end

    return final_polys
        
end