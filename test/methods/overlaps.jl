@testset "Points/MultiPoints" begin
    p1 = LG.Point([0.0, 0.0])
    p2 = LG.Point([0.0, 1.0])
    # Two points can't overlap
    @test GO.overlaps(p1, p1) == LG.overlaps(p1, p2)

    mp1 = LG.MultiPoint([[0.0, 1.0], [4.0, 4.0]])
    mp2 = LG.MultiPoint([[0.0, 1.0], [2.0, 2.0]])
    mp3 = LG.MultiPoint([[0.0, 1.0], [2.0, 2.0], [3.0, 3.0]])
    # No shared points, doesn't overlap
    @test GO.overlaps(p1, mp1) == LG.overlaps(p1, mp1)
    # One shared point, does overlap
    @test GO.overlaps(p2, mp1) == LG.overlaps(p2, mp1)
    # All shared points, doesn't overlap
    @test GO.overlaps(mp1, mp1) == LG.overlaps(mp1, mp1)
    # Not all shared points, overlaps
    @test GO.overlaps(mp1, mp2) == LG.overlaps(mp1, mp2)
    # One set of points entirely inside other set, doesn't overlap
    @test GO.overlaps(mp2, mp3) == LG.overlaps(mp2, mp3)
    # Not all points shared, overlaps
    @test GO.overlaps(mp1, mp3) == LG.overlaps(mp1, mp3)

    mp1 = LG.MultiPoint([
        [-36.05712890625, 26.480407161007275],
        [-35.7220458984375, 27.137368359795584],
        [-35.13427734375, 26.83387451505858],
        [-35.4638671875, 27.254629577800063],
        [-35.5462646484375, 26.86328062676624],
        [-35.3924560546875, 26.504988828743404],
    ])
    mp2 = GI.MultiPoint([
        [-35.4638671875, 27.254629577800063],
        [-35.5462646484375, 26.86328062676624],
        [-35.3924560546875, 26.504988828743404],
        [-35.2001953125, 26.12091815959972],
        [-34.9969482421875, 26.455820238459893],
    ])
    # Some shared points, overlaps
    @test GO.overlaps(mp1, mp2) == LG.overlaps(mp1, mp2)
    @test GO.overlaps(mp1, mp2) == GO.overlaps(mp2, mp1)
end

@testset "Lines/Rings" begin
    l1 = LG.LineString([[0.0, 0.0], [0.0, 10.0]])
    l2 = LG.LineString([[0.0, -10.0], [0.0, 20.0]])
    l3 = LG.LineString([[0.0, -10.0], [0.0, 3.0]])
    l4 = LG.LineString([[5.0, -5.0], [5.0, 5.0]])
    # Line can't overlap with itself
    @test GO.overlaps(l1, l1) == LG.overlaps(l1, l1)
    # Line completely within other line doesn't overlap
    @test GO.overlaps(l1, l2) == GO.overlaps(l2, l1) == LG.overlaps(l1, l2)
    # Overlapping lines
    @test GO.overlaps(l1, l3) == GO.overlaps(l3, l1) == LG.overlaps(l1, l3)
    # Lines that don't touch
    @test GO.overlaps(l1, l4) == LG.overlaps(l1, l4)
    # Linear rings that intersect but don't overlap
    r1 = LG.LinearRing([[0.0, 0.0], [0.0, 5.0], [5.0, 5.0], [5.0, 0.0], [0.0, 0.0]])
    r2 = LG.LinearRing([[1.0, 1.0], [1.0, 6.0], [6.0, 6.0], [6.0, 1.0], [1.0, 1.0]])
    @test LG.overlaps(r1, r2) == LG.overlaps(r1, r2)
end

@testset "Polygons/MultiPolygons" begin
    p1 = LG.Polygon([[[0.0, 0.0], [0.0, 5.0], [5.0, 5.0], [5.0, 0.0], [0.0, 0.0]]])
    p2 = LG.Polygon([
        [[10.0, 0.0], [10.0, 20.0], [30.0, 20.0], [30.0, 0.0], [10.0, 0.0]],
        [[15.0, 1.0], [15.0, 11.0], [25.0, 11.0], [25.0, 1.0], [15.0, 1.0]]
    ])
    # Test basic polygons that don't overlap
    @test GO.overlaps(p1, p2) == LG.overlaps(p1, p2)

    p3 = LG.Polygon([[[1.0, 1.0], [1.0, 6.0], [6.0, 6.0], [6.0, 1.0], [1.0, 1.0]]])
    # Test basic polygons that overlap
    @test GO.overlaps(p1, p3) == LG.overlaps(p1, p3)

    p4 = LG.Polygon([[[20.0, 5.0], [20.0, 10.0], [18.0, 10.0], [18.0, 5.0], [20.0, 5.0]]])
    # Test one polygon within the other
    @test GO.overlaps(p2, p4) == GO.overlaps(p4, p2) == LG.overlaps(p2, p4)

    # @test_throws MethodError GO.overlaps(pl1, (1, 1))  # I think these should be false
    # @test_throws MethodError GO.overlaps((1, 1), pl2)

    p5 = LG.Polygon(
        [[
            [-53.57208251953125, 28.287451910503744],
            [-53.33038330078125, 28.29228897739706],
            [-53.34136352890625, 28.430052892335723],
            [-53.57208251953125, 28.287451910503744],
        ]]
    )
    # Test equal polygons
    @test GO.overlaps(p5, p5) == LG.overlaps(p5, p5)

    # Test multipolygons
    m1 = LG.MultiPolygon([
        [[[0.0, 0.0], [0.0, 5.0], [5.0, 5.0], [5.0, 0.0], [0.0, 0.0]]],
        [
            [[10.0, 0.0], [10.0, 20.0], [30.0, 20.0], [30.0, 0.0], [10.0, 0.0]],
            [[15.0, 1.0], [15.0, 11.0], [25.0, 11.0], [25.0, 1.0], [15.0, 1.0]]
        ]
    ])
    # Test polygon that overlaps with multipolygon
    @test GO.overlaps(m1, p3) == LG.overlaps(m1, p3)
    # Test polygon in hole of multipolygon, doesn't overlap
    @test GO.overlaps(m1, p4) == LG.overlaps(m1, p4)
end
