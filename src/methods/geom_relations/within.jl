# # Within

export within

#=
## What is within?

The within function checks if one geometry is inside another geometry.

To provide an example, consider these two lines:
```@example cshape
using GeometryOps
using GeometryOps.GeometryBasics
using Makie
using CairoMakie

l1 = GI.LineString([(0.0, 0.0), (1.0, 0.0), (0.0, 0.1)])
l2 = GI.LineString([(0.25, 0.0), (0.75, 0.0)])
f, a, p = lines(GI.getpoint(l1), color = :blue)
scatter!(GI.getpoint(l1), color = :blue)
lines!(GI.getpoint(l2), color = :orange)
scatter!(GI.getpoint(l2), color = :orange)
```
We can see that all of the points and edges of l2 are within l1, so l2 is
within l1, but l1 is not within l2
```@example cshape
within(l1, l2)  # returns false
within(l2, l1)  # returns true
```

## Implementation

This is the GeoInterface-compatible implementation.

First, we implement a wrapper method that dispatches to the correct
implementation based on the geometry trait.

The methodology for each geometry pairing is a little different. For a point,
other points can only be inside of it if they are the same point. Nothing other
than a point can be within a point. For line string and linear rings, a point is
within if it is on a vertex or a line. For a line/ring inside of another
line/ring, we need all vertices and edges to be within the other line/ring's
edges. Polygons cannot be within a line/ring. Then for polygons, we need
lines/rings to be either on the edges (but with at least one point within the
polygon) or within the polygon, but not in any holes. Then for polygons within
polygons, they must be inside of the interior, including edges, but again not in
any holes.

The code for the specific implementations is in the geom_geom_processors file,
which has generalized code for the within and disjoint functions with a keyword
argument `process`, which is specified to be the `within_process` for the below
functions. 
=#

"""
    within(geom1, geom2)::Bool

Return `true` if the first geometry is completely within the second geometry.
The interiors of both geometries must intersect and the interior and boundary of
the primary geometry (geom1) must not intersect the exterior of the secondary
geometry (geom2).

Furthermore, `within` returns the exact opposite result of `contains`.

## Examples
```jldoctest setup=:(using GeometryOps, GeometryBasics)
import GeometryOps as GO, GeoInterface as GI

line = GI.LineString([(1, 1), (1, 2), (1, 3), (1, 4)])
point = (1, 2)
GO.within(point, line)

# output
true
```
"""
within(g1, g2) = within(trait(g1), g1, trait(g2), g2)
within(::GI.FeatureTrait, g1, ::Any, g2) = within(GI.geometry(g1), g2)
within(::Any, g1, t2::GI.FeatureTrait, g2) = within(g1, GI.geometry(g2))

"""
For any non-specified pair, g1 cannot be within g2 as g2 is of a higher
dimension than g1. Return false.
"""
within(::GI.AbstractGeometryTrait, g1, ::GI.AbstractGeometryTrait, g2) = false

# Points within geometries
"""
    within(::GI.PointTrait, g1, ::GI.PointTrait, g2)::Bool

If a point is within another point, then those points must be equal. If they are
not equal, then they are not within and return false.
"""
within(
    ::GI.PointTrait, g1,
    ::GI.PointTrait, g2,
) = equals(g1, g2)


"""
    within(::GI.PointTrait, g1, ::GI.LineStringTrait, g2)::Bool

A point is within a line string if it is on a vertex or an edge of that
linestring, excluding the start and end vertex if the linestring is not closed.
Return true if those conditions are met, else false.
"""
within(
    ::GI.PointTrait, g1,
    ::GI.LineStringTrait, g2,
) = _point_curve_process(
    g1, g2;
    in_allow = true, on_allow = false, out_allow = false,
    repeated_last_coord = false,
)

"""
    within(::GI.PointTrait, g1, ::GI.LinearRingTrait, g2)::Bool

A point is within a linear ring if it is on a vertex or an edge of that
linear ring. Return true if those conditions are met, else false.
"""
within(
    ::GI.PointTrait, g1,
    ::GI.LinearRingTrait, g2,
) = _point_curve_process(
    g1, g2;
    in_allow = true, on_allow = false, out_allow = false,
    repeated_last_coord = true,
)

"""
    within(::GI.PointTrait, g1, ::GI.PolygonTrait, g2)::Bool

A point is within a polygon if it is inside of that polygon, excluding edges,
vertices, and holes. Return true if those conditions are met, else false.
"""
within(
    ::GI.PointTrait, g1,
    ::GI.PolygonTrait, g2,
) = _point_polygon_process(
    g1, g2;
    in_allow = true, on_allow = false, out_allow = false,
)

# Lines within geometries
"""
    within(::GI.LineStringTrait, g1, ::GI.LineStringTrait, g2)::Bool

A line string is within another linestring if the vertices and edges of the
first linestring are within the second linestring, including the first and last
vertex. Return true if those conditions are met, else false.
"""
within(
    ::GI.LineStringTrait, g1,
    ::GI.LineStringTrait, g2,
) = _line_curve_process(
    g1, g2;
    over_allow = true, cross_allow = true, on_allow = true, out_allow = false,
    in_require = true, on_require = false, out_require = false,
    closed_line = false,
    closed_curve = false,
)

"""
    within(::GI.LineStringTrait, g1, ::GI.LinearRingTrait, g2)::Bool

A line string is within a linear ring if the vertices and edges of the
linestring are within the linear ring. Return true if those conditions are met,
else false.
"""
within(
    ::GI.LineStringTrait, g1,
    ::GI.LinearRingTrait, g2,
) = _line_curve_process(
    g1, g2;
    over_allow = true, cross_allow = true, on_allow = true, out_allow = false,
    in_require = true, on_require = false, out_require = false,
    closed_line = false,
    closed_curve = true,
)

"""
    within(::GI.LineStringTrait, g1, ::GI.PolygonTrait, g2)::Bool

A line string is within a polygon if the vertices and edges of the
linestring are within the polygon. Points of the linestring can be on the
polygon edges, but at least one point must be in the polygon interior. The
linestring also cannot cross through a hole. Return true if those conditions are
met, else false.
"""
within(
    ::GI.LineStringTrait, g1,
    ::GI.PolygonTrait, g2,
) = _line_polygon_process(
    g1, g2;
    in_allow =  true, on_allow = true, out_allow = false,
    in_require = true, on_require = false, out_require = false,
    closed_line = false,
)

# Rings within geometries
"""
    within(::GI.LinearRingTrait, g1, ::GI.LineStringTrait, g2)::Bool

A linear ring is within a linestring if the vertices and edges of the
linear ring are within the edges/vertices of the linear ring. Return true if
those conditions are met, else false.
"""
within(
    ::GI.LinearRingTrait, g1,
    ::GI.LineStringTrait, g2,
) = _line_curve_process(
    g1, g2;
    over_allow = true, cross_allow = true, on_allow = true, out_allow = false,
    in_require = true, on_require = false, out_require = false,
    closed_line = true,
    closed_curve = false,
)

"""
    within(::GI.LinearRingTrait, g1, ::GI.LinearRingTrait, g2)::Bool

A linear ring is within another linear ring if the vertices and edges of the
first linear ring are within the edges/vertices of the second linear ring.
Return true if those conditions are met, else false.
"""
within(
    ::GI.LinearRingTrait, g1,
    ::GI.LinearRingTrait, g2,
) = _line_curve_process(
    g1, g2;
    over_allow = true, cross_allow = true, on_allow = true, out_allow = false,
    in_require = true, on_require = false, out_require = false,
    closed_line = true,
    closed_curve = true,
)

"""
    within(::GI.LinearRingTrait, g1, ::GI.PolygonTrait, g2)::Bool

A linear ring is within a polygon if the vertices and edges of the linear ring
are within the polygon. Points of the linestring can be on the polygon edges,
but at least one point must be in the polygon interior. The linear ring also
cannot cross through a hole. Return true if those conditions are met, else
false.
"""
within(
    ::GI.LinearRingTrait, g1,
    ::GI.PolygonTrait, g2,
) = _line_polygon_process(
    g1, g2;
    in_allow =  true, on_allow = true, out_allow = false,
    in_require = true, on_require = false, out_require = false,
    closed_line = true,
)

# Polygons within polygons
"""
    within(::GI.PolygonTrait, g1, ::GI.PolygonTrait, g2)::Bool

A polygon is within another polygon if the interior of the first polygon is
inside of the second, including edges, and does not intersect with any holes of
the second polygon. If these conditions are met, return true, else false.
"""
within(
    ::GI.PolygonTrait, g1,
    ::GI.PolygonTrait, g2,
) = _polygon_polygon_process(
    g1, g2;
    in_allow =  true, on_allow = true, out_allow = false,
    in_require = true, on_require = false, out_require = false,
)

# function within(
#     ::GI.PolygonTrait, g1,
#     ::GI.PolygonTrait, g2;
# )
#     ext1 = GI.getexterior(g1)
#     e1_in_e2, _, e1_out_e2 = _line_filled_curve_interactions(
#         ext1, GI.getexterior(g2);
#         closed_line = true,
#     )
#     e1_out_e2 && return false

#     for h2 in GI.gethole(g2)
#         if e1_in_e2  # h2 could be outside of e1, but inside of e2
#             h2_in_e1, h2_on_e1, _ = _line_filled_curve_interactions(
#                 h2, ext1;
#                 closed_line = true,
#             )
#             # h2 is inside of e1 and cannot be excluded by a hole since it touches the boundary
#             h2_on_e1 && h2_in_e1 && return false
#             if !h2_in_e1  # is h2 disjoint from e1, or is e1 within h2?
#                 c1_val = point_filled_curve_orientation(centroid(ext1), h2)
#                 c1_val == point_in && return false  # e1 is within h2
#                 break  # e1 is disjoint from h2
#             end
#         end
#         # h2 is within e1, but is it within a hole of g1?
#         h2_in_e1 = true
#         for h1 in GI.gethole(g1)
#             _, h2_on_h1, h2_out_h1 = _line_filled_curve_interactions(
#                 h2, h1;
#                 closed_line = true,
#             )
#             # h2 is outside of h1 and cannot be excluded by another hole since it touches the boundary
#             h2_on_h1 && h2_out_h1 && return false
#             if !h2_out_h1  #h2 is within bounds of h1, so not in e1
#                 h2_in_e1 = false
#                 break
#             end
#         end
#         h2_in_e1 && return false
#     end
#     return true
# end

# Geometries within multipolygons
"""
    within(::GI.AbstractTrait, g1, ::GI.MultiPolygonTrait, g2)::Bool

A geometry is within a multipolygon if it is within one of the polygons that
make up the multipolygon. Return true if these conditions are met, else false.
"""
function within(::GI.AbstractGeometryTrait, g1, ::GI.MultiPolygonTrait, g2)
    for poly in GI.getpolygon(g2)
        if within(g1, poly)
            return true
        end
    end
    return false
end

"""
    within(::GI.MultiPolygonTrait, g1, ::GI.MultiPolygonTrait, g2)::Bool

A multipolygon is within a multipolygon if every polygon in the first
multipolygon is within one of the polygons in the second multipolygon. Return
true if these conditions are met, else false.
"""
function within(::GI.MultiPolygonTrait, g1, ::GI.MultiPolygonTrait, g2)
    for poly1 in GI.getpolygon(g1)
        poly1_within = false
        for poly2 in GI.getpolygon(g2)
            if within(poly1, poly2)
                poly1_within = true
                break
            end
        end
        !poly1_within && return false
    end
    return true
end