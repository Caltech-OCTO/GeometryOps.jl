include("clipping_test_utils.jl")

"""
    compare_GO_LG_difference(p1, p2, ϵ)::Bool

    Returns true if the 'difference' function from LibGEOS and 
    GeometryOps return similar enough polygons (determined by ϵ).
"""
function compare_GO_LG_difference(p1, p2, ϵ)
    GO_difference = GO.difference(p1,p2)
    LG_difference = LG.difference(p1,p2)
    if isempty(GO_difference[1]) && LG.isEmpty(LG_difference)
        return true
    end

    if length(GO_difference)==1
        temp = convert_tuple_to_array(GO_difference)
        GO_difference_poly = LG.Polygon(temp[1])
    else
        temp = convert_tuple_to_array(GO_difference)
        GO_difference_poly = LG.MultiPolygon(temp)
    end
    return LG.area(LG.difference(GO_difference_poly, LG_difference)) < ϵ
end

@testset "Difference_polygons" begin
    # Two "regular" polygons that intersect
    p1 = [[0.0, 0.0], [5.0, 5.0], [10.0, 0.0], [5.0, -5.0], [0.0, 0.0]]
    p2 = [[3.0, 0.0], [8.0, 5.0], [13.0, 0.0], [8.0, -5.0], [3.0, 0.0]]
    @test compare_GO_LG_difference(GI.Polygon([p1]), GI.Polygon([p2]), 1e-5)

    # Two ugly polygons with 2 holes each
    p3 = [[(0.0, 0.0), (5.0, 0.0), (5.0, 8.0), (0.0, 8.0), (0.0, 0.0)], [(4.0, 0.5), (4.5, 0.5), (4.5, 3.5), (4.0, 3.5), (4.0, 0.5)], [(2.0, 4.0), (4.0, 4.0), (4.0, 6.0), (2.0, 6.0), (2.0, 4.0)]]
    p4 = [[(3.0, 1.0), (8.0, 1.0), (8.0, 7.0), (3.0, 7.0), (3.0, 5.0), (6.0, 5.0), (6.0, 3.0), (3.0, 3.0), (3.0, 1.0)], [(3.5, 5.5), (6.0, 5.5), (6.0, 6.5), (3.5, 6.5), (3.5, 5.5)], [(5.5, 1.5), (5.5, 2.5), (3.5, 2.5), (3.5, 1.5), (5.5, 1.5)]]
    @test compare_GO_LG_difference(GI.Polygon(p3), GI.Polygon(p4), 1e-5)

    # # The two polygons that intersect from the Greiner paper
    # greiner_1 = [(0.0, 0.0), (0.0, 4.0), (7.0, 4.0), (7.0, 0.0), (0.0, 0.0)]
    # greiner_2 = [(1.0, -3.0), (1.0, 1.0), (3.5, -1.5), (6.0, 1.0), (6.0, -3.0), (1.0, -3.0)]
    # @test compare_GO_LG_difference(GI.Polygon([greiner_1]), GI.Polygon([greiner_2]), 1e-5)

    # ugly difference test
    pa = [[(0.0, 0.0), (8.0, 0.0), (8.0, 8.0), (0.0, 8.0), (0.0, 0.0)], [(5.0, 5.0), (7.0, 5.0), (7.0, 7.0), (5.0, 7.0), (5.0, 5.0)]]
    pb = [[(3.0, -1.0), (10.0, -1.0), (10.0, 9.0), (3.0, 9.0), (3.0, -1.0)], [(4.0, 3.0), (5.0, 3.0), (5.0, 4.0), (4.0, 4.0), (4.0, 3.0)], [(6.0, 1.0), (7.0, 1.0), (7.0, 2.0), (6.0, 2.0), (6.0, 1.0)]]
    

end