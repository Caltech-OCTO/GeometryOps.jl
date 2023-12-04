# converts a vector of vector of vector of tuples to vec of vec of vec of array
"""
convert_tuple_to_array(Vector{Vector{Vector{Tuple{::Real}}}})::Vector{Vector{Vector{Vector{::Real}}}}

    This function converts a vector of vectors of vectors of tuples to a 
    vector of vectors of vectors of vectors.
"""
function convert_tuple_to_array(VVVT)
    new_return_obj = Vector{Vector{Vector{Vector{Float64}}}}(undef, 0)
    for vec1 in VVVT
        new_vec1 = Vector{Vector{Vector{Float64}}}(undef, 0)
        for vec2 in vec1
            new_vec2 = Vector{Vector{Float64}}(undef, 0)
            for tup in vec2
                push!(new_vec2, [tup[1], tup[2]])
            end
            push!(new_vec1, new_vec2)
        end
        push!(new_return_obj, new_vec1)
    end
    return new_return_obj
end

"""
    compare_GO_LG_union(p1, p2, ϵ)::Bool

    Returns true if the 'union' function from LibGEOS and 
    GeometryOps return similar enough polygons (determined by ϵ).
"""
function compare_GO_LG_union(p1, p2, ϵ)
    GO_union = GO.union(p1,p2)
    LG_union = LG.union(p1,p2)
    if isempty(GO_union[1]) && LG.isEmpty(LG_union)
        return true
    end

    temp = convert_tuple_to_array(GO_union)
    GO_union_poly = LG.Polygon(temp[1])

    return LG.area(LG.difference(GO_union_poly, LG_union)) < ϵ
end

@testset "Union_polygons" begin
    # Two "regular" polygons that intersect
    p1 = [[0.0, 0.0], [5.0, 5.0], [10.0, 0.0], [5.0, -5.0], [0.0, 0.0]]
    p2 = [[3.0, 0.0], [8.0, 5.0], [13.0, 0.0], [8.0, -5.0], [3.0, 0.0]]
    @test compare_GO_LG_union(GI.Polygon([p1]), GI.Polygon([p2]), 1e-5)

    # Two ugly polygons with 2 holes each
    p1 = [[(0.0, 0.0), (5.0, 0.0), (5.0, 8.0), (0.0, 8.0), (0.0, 0.0)], [(4.0, 0.5), (4.5, 0.5), (4.5, 3.5), (4.0, 3.5), (4.0, 0.5)], [(2.0, 4.0), (4.0, 4.0), (4.0, 6.0), (2.0, 6.0), (2.0, 4.0)]]
    p2 = [[(3.0, 1.0), (8.0, 1.0), (8.0, 7.0), (3.0, 7.0), (3.0, 5.0), (6.0, 5.0), (6.0, 3.0), (3.0, 3.0), (3.0, 1.0)], [(3.5, 5.5), (6.0, 5.5), (6.0, 6.5), (3.5, 6.5), (3.5, 5.5)], [(5.5, 1.5), (5.5, 2.5), (3.5, 2.5), (3.5, 1.5), (5.5, 1.5)]]
    @test compare_GO_LG_union(GI.Polygon(p1), GI.Polygon(p2), 1e-5)

    # Union test when the two polygons are disjoint and each have one hole (two disjoint square donuts)
    p1 = [[(0.0, 0.0), (3.0, 0.0), (3.0, 3.0), (0.0, 3.0), (0.0, 0.0)], [(1.0, 1.0), (2.0, 1.0), (2.0, 2.0), (1.0, 2.0), (1.0, 1.0)]]
    p2 = [[(5.0, 0.0), (8.0, 0.0), (8.0, 3.0), (5.0, 3.0), (5.0, 0.0)], [(6.0, 1.0), (7.0, 1.0), (7.0, 2.0), (7.0, 1.0), (6.0, 1.0)]]
    @test compare_GO_LG_union(GI.Polygon(p1), GI.Polygon(p2), 1e-5)

    # The two polygons that intersect from the Greiner paper
    greiner_1 = [(0.0, 0.0), (0.0, 4.0), (7.0, 4.0), (7.0, 0.0), (0.0, 0.0)]
    greiner_2 = [(1.0, -3.0), (1.0, 1.0), (3.5, -1.5), (6.0, 1.0), (6.0, -3.0), (1.0, -3.0)]
    @test compare_GO_LG_union(GI.Polygon([greiner_1]), GI.Polygon([greiner_2]), 1e-5)
end