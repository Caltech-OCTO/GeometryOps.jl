# # Polygon clipping helpers
# This file contains the shared helper functions for the polygon clipping functionalities.

# @enum PointEdgeSide left=0, right=1

#= This is the struct that makes up a_list and b_list. Many values are only used if point is
an intersection point (ipt). =#
struct PolyNode{T <: AbstractFloat}
    point::Tuple{T,T}  # (x, y) values of given point
    inter::Bool        # If ipt, true, else 0
    neighbor::Int      # If ipt, index of equivalent point in a_list or b_list, else 0
    ent_exit::Bool     # If ipt, true if enter and false if exit, else false
    fracs::Tuple{T,T}  # If ipt, fractions along edges to ipt (a_frac, b_frac), else (0, 0)
    crossing::Bool
end

#=
    _build_ab_list(::Type{T}, poly_a, poly_b) -> (a_list, b_list, a_idx_list)

This function takes in two polygon rings and calls '_build_a_list', '_build_b_list', and
'_flag_ent_exit' in order to fully form a_list and b_list. The 'a_list' and 'b_list' that it
returns are the fully updated vectors of PolyNodes that represent the rings 'poly_a' and
'poly_b', respectively. This function also returns 'a_idx_list', which at its "ith" index
stores the index in 'a_list' at which the "ith" intersection point lies.
=#
function _build_ab_list(::Type{T}, poly_a, poly_b) where T
    # Make a list for nodes of each polygon
    a_list, a_idx_list, n_b_intrs = _build_a_list(T, poly_a, poly_b)
    b_list = _build_b_list(T, a_idx_list, a_list, n_b_intrs, poly_b)

    #TODO: for now put crossing stuff here

    # Flag the entry and exits
    _flag_ent_exit!(poly_b, a_list)
    _flag_ent_exit!(poly_a, b_list)
    # Flag crossings
    _classify_crossing!(a_list, b_list)

    return a_list, b_list, a_idx_list
end

#=
    _build_a_list(::Type{T}, poly_a, poly_b) -> (a_list, a_idx_list)

This function take in two polygon rings and creates a vector of PolyNodes to represent
poly_a, including its intersection points with poly_b. The information stored in each
PolyNode is needed for clipping using the Greiner-Hormann clipping algorithm.
    
Note: After calling this function, a_list is not fully formed because the neighboring
indicies of the intersection points in b_list still need to be updated. Also we still have
not update the entry and exit flags for a_list.
    
The a_idx_list is a list of the indicies of intersection points in a_list. The value at
index i of a_idx_list is the location in a_list where the ith intersection point lies.
=#
function _build_a_list(::Type{T}, poly_a, poly_b) where T
    n_a_edges = _nedge(poly_a)
    a_list = Vector{PolyNode{T}}(undef, n_a_edges)  # list of points in poly_a
    a_idx_list = Vector{Int}()  # finds indices of intersection points in a_list
    a_count = 0  # number of points added to a_list
    n_b_intrs = 0
    # Loop through points of poly_a
    local a_pt1
    for (i, a_p2) in enumerate(GI.getpoint(poly_a))
        a_pt2 = (T(GI.x(a_p2)), T(GI.y(a_p2)))
        if i <= 1
            a_pt1 = a_pt2
            continue
        end
        # Add the first point of the edge to the list of points in a_list
        new_point = PolyNode(a_pt1, false, 0, false, (zero(T), zero(T)), false)
        a_count += 1
        _add!(a_list, a_count, new_point, n_a_edges)
        # Find intersections with edges of poly_b
        local b_pt1
        prev_counter = a_count
        for (j, b_p2) in enumerate(GI.getpoint(poly_b))
            b_pt2 = _tuple_point(b_p2)
            if j <=1
                b_pt1 = b_pt2
                continue
            end
            int_pt, fracs = _intersection_point(T, (a_pt1, a_pt2), (b_pt1, b_pt2))
            if !isnothing(fracs)
                α, β = fracs
                collinear = isnothing(int_pt)
                # if no intersection point, skip this edge
                if !collinear && 0 < α < 1 && 0 < β < 1
                    # Intersection point that isn't a vertex
                    new_intr = PolyNode(int_pt, true, j - 1, false, fracs, false)
                    a_count += 1
                    n_b_intrs += 1
                    _add!(a_list, a_count, new_intr, n_a_edges)
                    push!(a_idx_list, a_count)
                else
                    if (0 < β < 1 && (collinear || α == 0)) || (α == β == 0)
                        # a_pt1 is an intersection point
                        n_b_intrs += β == 0 ? 0 : 1
                        a_list[prev_counter] = PolyNode(a_pt1, true, j - 1, false, fracs, false)
                        push!(a_idx_list, prev_counter)
                    end
                    if (0 < α < 1 && (collinear || β == 0))
                        # b_pt1 is an intersection point
                        new_intr = PolyNode(b_pt1, true, j - 1, false, fracs, false)
                        a_count += 1
                        _add!(a_list, a_count, new_intr, n_a_edges)
                        push!(a_idx_list, a_count)
                    end
                end
            end
            b_pt1 = b_pt2
        end

        # Order intersection points by placement along edge using fracs value
        if prev_counter < a_count
            Δintrs = a_count - prev_counter
            inter_points = @view a_list[(a_count - Δintrs + 1):a_count]
            sort!(inter_points, by = x -> x.fracs[1])
        end
    
        a_pt1 = a_pt2
    end
    return a_list, a_idx_list, n_b_intrs
end

# Add value x at index i to given array - if list isn't long enough, push value to array
function _add!(arr, i, x, l = length(arr))
    if i <= l
        arr[i] = x
    else
        push!(arr, x)
    end
    return
end

#=
    _build_b_list(::Type{T}, a_idx_list, a_list, poly_b) -> b_list

This function takes in the a_list and a_idx_list build in _build_a_list and poly_b and
creates a vector of PolyNodes to represent poly_b. The information stored in each PolyNode
is needed for clipping using the Greiner-Hormann clipping algorithm.
    
Note: after calling this function, b_list is not fully updated. The entry/exit flags still
need to be updated. However, the neightbor value in a_list is now updated.
=#
function _build_b_list(::Type{T}, a_idx_list, a_list, n_b_intrs, poly_b) where T
    # Sort intersection points by insertion order in b_list
    sort!(a_idx_list, by = x-> a_list[x].neighbor + a_list[x].fracs[2])
    # Initialize needed values and lists
    n_b_edges = _nedge(poly_b)
    n_intr_pts = length(a_idx_list)
    b_list = Vector{PolyNode{T}}(undef, n_b_edges + n_b_intrs)
    intr_curr = 1
    b_count = 0
    # Loop over points in poly_b and add each point and intersection point
    for (i, p) in enumerate(GI.getpoint(poly_b))
        (i == n_b_edges + 1) && break
        b_count += 1
        pt = (T(GI.x(p)), T(GI.y(p)))
        b_list[b_count] = PolyNode(pt, false, 0, false, (zero(T), zero(T)), false)
        if intr_curr ≤ n_intr_pts
            curr_idx = a_idx_list[intr_curr]
            curr_node = a_list[curr_idx]
            prev_counter = b_count
            while curr_node.neighbor == i  # Add all intersection points in current edge
                b_idx = if equals(curr_node.point, b_list[prev_counter].point)
                    # intersection point is vertex of b
                    prev_counter
                else
                    b_count += 1
                    b_count
                end
                b_list[b_idx] = PolyNode(curr_node.point, true, curr_idx, false, curr_node.fracs, false)
                a_list[curr_idx] = PolyNode(curr_node.point, curr_node.inter, b_idx, curr_node.ent_exit, curr_node.fracs, curr_node.crossing)
                intr_curr += 1
                intr_curr > n_intr_pts && break
                curr_idx = a_idx_list[intr_curr]
                curr_node = a_list[curr_idx]
            end
        end
    end
    sort!(a_idx_list)  # return a_idx_list to order of points in a_list
    return b_list
end

#=
    _flag_ent_exit(poly_b, a_list)

This function flags all the intersection points as either an 'entry' or 'exit' point in
relation to the given polygon.
=#
function _flag_ent_exit!(poly, pt_list)
    local status
    for ii in eachindex(pt_list)
        if ii == 1
            status = !_point_filled_curve_orientation(
                pt_list[ii].point, poly;
                in = true, on = false, out = false
            )
        elseif pt_list[ii].inter
            pt_list[ii] = PolyNode(pt_list[ii].point, pt_list[ii].inter, pt_list[ii].neighbor, status, pt_list[ii].fracs, false)
            status = !status
        end
    end
    return
end

#=
    _trace_polynodes(::Type{T}, a_list, b_list, a_idx_list, f_step)::Vector{GI.Polygon}

This function takes the outputs of _build_ab_list and traces the lists to determine which
polygons are formed as described in Greiner and Hormann. The function f_step determines in
which direction the lists are traced.  This function is different for intersection,
difference, and union. f_step must take in two arguments: the most recent intersection
node's entry/exit status and a boolean that is true if we are currently tracing a_list and
false if we are tracing b_list. The functions used for each clipping operation are follows:
    - Intersection: (x, y) -> x ? 1 : (-1)
    - Difference: (x, y) -> (x ⊻ y) ? 1 : (-1)
    - Union: (x, y) -> (x ⊻ y) ? 1 : (-1)

A list of GeoInterface polygons is returned from this function. 
=#
function _trace_polynodes(::Type{T}, a_list, b_list, a_idx_list, f_step) where T
    n_a_pts, n_b_pts = length(a_list), length(b_list)
    n_intr_pts = length(a_idx_list)
    return_polys = Vector{_get_poly_type(T)}(undef, 0)
    # Keep track of number of processed intersection points
    processed_pts = 0
    while processed_pts < n_intr_pts
        curr_list, curr_npoints = a_list, n_a_pts
        on_a_list = true
        # Find first unprocessed intersecting point in subject polygon
        processed_pts += 1
        first_idx = findnext(x -> x != 0, a_idx_list, processed_pts)
        idx = a_idx_list[first_idx]
        a_idx_list[first_idx] = 0
        start_pt = a_list[idx]

        # Set first point in polygon
        curr = curr_list[idx]
        pt_list = [curr.point]

        curr_not_start = true
        while curr_not_start
            step = f_step(curr.ent_exit, on_a_list)
            curr_not_intr = true
            while curr_not_intr
                # Traverse polygon either forwards or backwards
                idx += step
                idx = (idx > curr_npoints) ? mod(idx, curr_npoints) : idx
                idx = (idx == 0) ? curr_npoints : idx

                # Get current node and add to pt_list
                curr = curr_list[idx]
                push!(pt_list, curr.point)
                if curr.inter 
                    # Keep track of processed intersection points
                    curr_not_start = curr != start_pt && curr != b_list[start_pt.neighbor]
                    if curr_not_start
                        processed_pts += 1
                        for (i, a_idx) in enumerate(a_idx_list)
                            if a_idx != 0 && equals(a_list[a_idx].point, curr.point)
                                a_idx_list[i] = 0
                            end
                        end
                        # a_idx_list[curr.idx] = 0
                    end
                    curr_not_intr = false
                end
            end

            # Switch to next list and next point
            curr_list, curr_npoints = on_a_list ? (b_list, n_b_pts) : (a_list, n_a_pts)
            on_a_list = !on_a_list
            idx = curr.neighbor
            curr = curr_list[idx]
        end
        push!(return_polys, GI.Polygon([pt_list]))
    end
    return return_polys
end

# Get type of polygons that will be made
# TODO: Increase type options
_get_poly_type(::Type{T}) where T =
    GI.Polygon{false, false, Vector{GI.LinearRing{false, false, Vector{Tuple{T, T}}, Nothing, Nothing}}, Nothing, Nothing}

#=
    _add_holes_to_polys!(::Type{T}, return_polys, hole_iterator)

The holes specified by the hole iterator are added to the polygons in the return_polys list.
If this creates more polygon, they are added to the end of the list. If this removes
polygons, they are removed from the list
=#
function _add_holes_to_polys!(::Type{T}, return_polys, hole_iterator) where T
    n_polys = length(return_polys)
    # Remove set of holes from all polygons
    for i in 1:n_polys
        n_new_per_poly = 0
        for hole in hole_iterator  # loop through all holes
            hole_poly = GI.Polygon([hole])
            # loop through all pieces of original polygon (new pieces added to end of list)
            for j in Iterators.flatten((i:i, (n_polys + 1):(n_polys + n_new_per_poly)))
                if !isnothing(return_polys[j])
                    new_polys = difference(return_polys[j], hole_poly, T; target = GI.PolygonTrait)
                    n_new_polys = length(new_polys)
                    if n_new_polys == 0  # hole covered whole polygon
                        return_polys[j] = nothing
                    else
                        return_polys[j] = new_polys[1]  # replace original
                        if n_new_polys > 1  # add any extra pieces
                            append!(return_polys, @view new_polys[2:end])
                            n_new_per_poly += n_new_polys - 1
                        end
                    end
                end
            end
        end
        n_polys += n_new_per_poly
    end
    # Remove all polygon that were marked for removal
    filter!(!isnothing, return_polys)
    return
end

function _signed_area_triangle(P, Q, R)
    return (GI.x(Q)-GI.x(P))*(GI.y(R)-GI.y(P))-(GI.y(Q)-GI.y(P))*(GI.x(R)-GI.x(P))
end

function _classify_crossing!(a_list, b_list)
    skip_idx = 0
    for i in eachindex(a_list)
        # check if it's intersection point, if not, continue
        if !(a_list[i].inter)
            continue
        end
        # check if it is already a crossing point, if so mark it in b, then continue
        if a_list[i].crossing
            j = a_list[i].neighbor
            b = b_list[j]
            b_list[j] = PolyNode(b.point, b.inter, b.neighbor, b.ent_exit, b.fracs, true)
            continue
        end
        # check if we have already processed this point because it was in a chain
        if i <= skip_idx
            continue
        end
        # Now deal with the degenerate points
        I = a_list[i].point
        j = a_list[i].neighbor
        P₋, P₊, Q₋, Q₊ = _get_ps_qs(i, a_list, b_list)

        skip_idx = _classify_crossing_intersection!(Q₋, P₋, I, P₊, Q₊, a_list, b_list, i, j)
    end

end

function _get_ps_qs(i, a_list, b_list)
    j = a_list[i].neighbor
    idx = i-1
    if i-1<1
        idx = length(a_list)
    end
    P₋ = a_list[idx].point
    idx = i+1
    if idx>length(a_list)
        idx = 1
    end
    P₊ = a_list[idx].point
    idx = j-1
    if j-1<1
        idx = length(b_list)
    end
    Q₋ = b_list[idx].point
    idx = j + 1
    if j+1 > length(b_list)
        idx = 1
    end
    Q₊ = b_list[idx].point
    
    return P₋, P₊, Q₋, Q₊
end

function _classify_crossing_intersection!(Q₋, P₋, I, P₊, Q₊, a_list, b_list, i, j)
    # Check what sides Q- and Q+ are on
    side_Q₋ = _get_side(Q₋, P₋, I, P₊)
    side_Q₊ = _get_side(Q₊, P₋, I, P₊)
    a = a_list[i]
    b = b_list[j]
    
    if (P₊ == Q₋) || (P₊ == Q₊)
        # mark first node in chain as bounce
        a_list[i] = PolyNode(a.point, a.inter, a.neighbor, a.ent_exit, a.fracs, false)
        b_list[j] = PolyNode(b.point, b.inter, b.neighbor, b.ent_exit, b.fracs, false)
        # get the side of the first point of the chain
        local start_chain_side
        if (P₊ == Q₋)
            start_chain_side = side_Q₊
        else
            start_chain_side = side_Q₋
        end
        # look ahead at intersection poitns
        while true
            i = i+1
            if i>length(a_list)
                i = 1
            end
            I = a_list[i].point
            j = a_list[i].neighbor
            a = a_list[i]
            b = b_list[j]
            P₋, P₊, Q₋, Q₊ = _get_ps_qs(i, a_list, b_list)
            # if poly P is on poly Q to both sides of i
            if ((P₋ == Q₋) && (P₊ == Q₊)) || ((P₋ == Q₊) && (P₊ == Q₋))
                a_list[i] = PolyNode(a.point, a.inter, a.neighbor, a.ent_exit, a.fracs, false)
                b_list[j] = PolyNode(b.point, b.inter, b.neighbor, b.ent_exit, b.fracs, false)
            else # we must be at the end of the polynode overlap chain
                # get the side of the end of the chain
                if (P₋ == Q₋) 
                    end_chain_side = _get_side(Q₊, P₋, I, P₊)
                elseif (P₋ == Q₊)
                    end_chain_side = _get_side(Q₋, P₋, I, P₊)
                end
                # figure out if delayed crossing or delayed bounce
                if start_chain_side == end_chain_side
                    a_list[i] = PolyNode(a.point, a.inter, a.neighbor, a.ent_exit, a.fracs, false)
                    b_list[j] = PolyNode(b.point, b.inter, b.neighbor, b.ent_exit, b.fracs, false)
                else
                    a_list[i] = PolyNode(a.point, a.inter, a.neighbor, a.ent_exit, a.fracs, true)
                    b_list[j] = PolyNode(b.point, b.inter, b.neighbor, b.ent_exit, b.fracs, true)
                end
                # break because we are at the end of the polynode overlap chain
                break
            end

        end
    else
        if side_Q₋ == side_Q₊
            a_list[i] = PolyNode(a.point, a.inter, a.neighbor, a.ent_exit, a.fracs, false)
            b_list[j] = PolyNode(b.point, b.inter, b.neighbor, b.ent_exit, b.fracs, false)
        else
            a_list[i] = PolyNode(a.point, a.inter, a.neighbor, a.ent_exit, a.fracs, true)
            b_list[j] = PolyNode(b.point, b.inter, b.neighbor, b.ent_exit, b.fracs, true)
        end
    end

    # return what index we ended up at so we know how many intersection points to skip in a_list
    return i
end

# output 0 means left, 1 means right
function _get_side(Q, P1, P2, P3)
    s1 = _signed_area_triangle(Q, P1, P2)
    s2 = _signed_area_triangle(Q, P2, P3)
    s3 = _signed_area_triangle(P1, P2, P3)

    if s3 >= 0
        if (s1 > 0) && (s2 > 0)
            return 0
        else
            return 1
        end
    else
        if (s1 > 0) || (s2 > 0)
            return 1
        else
            return 0
        end
    end
end