# # Disjoint

export disjoint
#=
## What is disjoint?

The disjoint function checks if one geometry is outside of another geometry,
without sharing any boundaries or interiors.

To provide an example, consider these two lines:
```@example cshape
using GeometryOps
using GeometryOps.GeometryBasics
using Makie
using CairoMakie

l1 = GI.LineString([(0.0, 0.0), (1.0, 0.0), (0.0, 0.1)])
l2 = GI.LineString([(2.0, 0.0), (2.75, 0.0)])
f, a, p = lines(GI.getpoint(l1), color = :blue)
scatter!(GI.getpoint(l1), color = :blue)
lines!(GI.getpoint(l2), color = :orange)
scatter!(GI.getpoint(l2), color = :orange)
```
We can see that none of the edges or vertices of l1 interact with l2 so they are
disjoint.
```@example cshape
disjoint(l1, l2)  # returns true
```

## Implementation

This is the GeoInterface-compatible implementation.

First, we implement a wrapper method that dispatches to the correct
implementation based on the geometry trait.

For a point, other points are disjoint if they are not equal to the first point.
than a point can be within a point. For all other geometries, we identify that
the first point of the geometry is outside of the geometry and then make sure
that the two geometries do not intersect. If these conditions are met, the two
geometries are disjoint.

The code for the specific implementations is in the geom_geom_processors file,
which has generalized code for the within and disjoint functions with a keyword
argument `process`, which is specified to be the `disjoint_process` for the
below functions. 
=#

"""
    disjoint(geom1, geom2)::Bool

Return `true` if the first geometry is disjoint from the second geometry.
The interiors and boundaries of both geometries must not intersect.

## Examples
```jldoctest setup=:(using GeometryOps, GeometryBasics)
import GeometryOps as GO, GeoInterface as GI

line = GI.LineString([(1, 1), (1, 2), (1, 3), (1, 4)])
point = (2, 2)
GO.disjoint(point, line)

# output
true
```
"""
disjoint(g1, g2)::Bool = disjoint(trait(g1), g1, trait(g2), g2)
disjoint(::FeatureTrait, g1, ::Any, g2)::Bool = disjoint(GI.geometry(g1), g2)
disjoint(::Any, g1, t2::FeatureTrait, g2)::Bool = disjoint(g1, geometry(g2))

# Point disjoint geometries
"""
    disjoint(::GI.PointTrait, g1, ::GI.PointTrait, g2)::Bool

If a point is disjoint from another point, those points must not be equal. If
they are equal then they are not disjoint and return false.
"""
disjoint(
    ::GI.PointTrait, g1,
    ::GI.PointTrait, g2,
) = !equals(g1, g2)

"""
    disjoint(::GI.PointTrait, g1, ::GI.LineStringTrait, g2)::Bool

If a point is disjoint from a linestring then it is not on any of the
linestring's edges or vertices. If these conditions are met, return true, else
false.
"""
disjoint(
    ::GI.PointTrait, g1,
    ::GI.LineStringTrait, g2,
) = _point_curve_process(
    g1, g2;
    in_allow = false, on_allow = false, out_allow = true,
    repeated_last_coord = false,
)

"""    
    disjoint(::GI.PointTrait, g1, ::GI.LinearRingTrait, g2)::Bool

If a point is disjoint from a linear ring then it is not on any of the
ring's edges or vertices. If these conditions are met, return true, else false.
"""
disjoint(
    ::GI.PointTrait, g1,
    ::GI.LinearRingTrait, g2,
) = _point_curve_process(
    g1, g2;
    in_allow = false, on_allow = false, out_allow = true,
    repeated_last_coord = true,
)

"""
    disjoint(::GI.PointTrait, g1, ::GI.PolygonTrait, g2)::Bool

A point is disjoint from a polygon if it is outside of that polygon. This means
it is not on any edges, vertices, or within the interior. The point can be
within a hole. Return true if those conditions are met, else false.
"""
disjoint(
    ::GI.PointTrait, g1,
    ::GI.PolygonTrait, g2,
) = _point_polygon_process(
    g1, g2;
    in_allow = false, on_allow = false, out_allow = true,
)

"""
    disjoint(trait1::GI.AbstractTrait, g1, trait2::GI.PointTrait, g2)::Bool

To check if a geometry is disjoint from a point, switch the order of the
arguments to take advantage of point-geometry disjoint methods.
"""
disjoint(
    trait1::GI.AbstractTrait, g1,
    trait2::GI.PointTrait, g2,
) = disjoint(trait2, g2, trait1, g1)

# Lines disjoint from geometries
"""
    disjoint(::GI.LineStringTrait, g1, ::GI.LineStringTrait, g2)::Bool

Two linestrings are disjoint if they do not share any edges or vertices and if
they do not intersect. If these conditions are met, return true, else false.
"""
disjoint(
    ::GI.LineStringTrait, g1,
    ::GI.LineStringTrait, g2,
) = _line_curve_process(
    g1, g2;
    in_allow = false, on_allow = false, out_allow = true,
    in_require = false, on_require = false, out_require = false,
    closed_line = false,
    closed_curve = false,
)

"""
    disjoint(::GI.LineStringTrait, g1, ::GI.LinearRingTrait, g2)::Bool

A linestring and a linear ring are disjoint if they do not share any edges or
vertices and if they do not intersect. If these conditions are met, return true,
else false.
"""
disjoint(
    ::GI.LineStringTrait, g1,
    ::GI.LinearRingTrait, g2,
) = _line_curve_process(
    g1, g2;
    in_allow = false, on_allow = false, out_allow = true,
    in_require = false, on_require = false, out_require = false,
    closed_line = false,
    closed_curve = true,
)

"""
    disjoint(::GI.LineStringTrait, g1, ::GI.PolygonTrait, g2)::Bool

A linestring and a polygon are disjoint if they do not share any edges or
vertices and if the linestring does not pass through the interior of the
polygon, excluding any holes. If these conditions are met, return true, else
false.
"""
disjoint(
    ::GI.LineStringTrait, g1,
    ::GI.PolygonTrait, g2,
) = _line_polygon_process(
    g1, g2;
    in_allow =  false, on_allow = false, out_allow = true,
    in_require = false, on_require = false, out_require = true,
    closed_line = false,
)

"""
    disjoint(trait1::GI.AbstractTrait, g1, trait2::GI.LineStringTrait, g2)::Bool

To check if a geometry is disjoint from a linestring, switch the order of the
arguments to take advantage of linestring-geometry disjoint methods.
"""
disjoint(
    trait1::GI.AbstractTrait, g1,
    trait2::GI.LineStringTrait, g2,
) = disjoint(trait2, g2, trait1, g1)

# Rings disjoint from geometries
"""
    disjoint(::GI.LinearRingTrait, g1, ::GI.LineStringTrait, g2)::Bool

A linear ring and a linestring are disjoint if they do not share any edges or
vertices and if they do not intersect. If these conditions are met, return true,
else false.
"""
disjoint(
    trait1::GI.LinearRingTrait, g1,
    trait2::GI.LineStringTrait, g2,
) = disjoint(trait2, g2, trait1, g1)

"""
    disjoint(::GI.LinearRingTrait, g1, ::GI.LinearRingTrait, g2)::Bool

Two linear rings are disjoint if they do not share any edges or vertices and if
they do not intersect. If these conditions are met, return true, else false.
"""
disjoint(
    ::GI.LinearRingTrait, g1,
    ::GI.LinearRingTrait, g2,
) = _line_curve_process(
    g1, g2;
    in_allow = false, on_allow = false, out_allow = true,
    in_require = false, on_require = false, out_require = false,
    closed_line = true,
    closed_curve = true,
)

"""
    disjoint(::GI.LinearRingTrait, g1, ::GI.PolygonTrait, g2)::Bool

A linear ring and a polygon are disjoint if they do not share any edges or
vertices and if the linear ring does not pass through the interior of the
polygon, excluding any holes. If these conditions are met, return true, else
false.
"""
disjoint(
    ::GI.LinearRingTrait, g1,
    ::GI.PolygonTrait, g2,
) = _line_polygon_process(
    g1, g2;
    in_allow =  false, on_allow = false, out_allow = true,
    in_require = false, on_require = false, out_require = true,
    closed_line = true,
)

"""
    disjoint(trait1::GI.AbstractTrait, g1, trait2::GI.LinearRingTrait, g2)::Bool

To check if a geometry is disjoint from a linear ring, switch the order of the
arguments to take advantage of linear ring-geometry disjoint methods.
"""
disjoint(
    trait1::GI.AbstractTrait, g1,
    trait2::GI.LinearRingTrait, g2,
) = disjoint(trait2, g2, trait1, g1)

# Polygon disjoint from geometries
"""
    disjoint(::GI.PolygonTrait, g1, ::GI.PolygonTrait, g2)::Bool

Two polygons are disjoint if they do not share any edges or vertices and if
their interiors do not intersect, excluding any holes. If these conditions are
met, return true, else false.
"""
function disjoint(
    ::GI.PolygonTrait, g1,
    ::GI.PolygonTrait, g2;
)
    ext1 = GI.getexterior(g1)
    e1_in_e2, e1_on_e2, e1_out_e2 = _line_filled_curve_interactions(
        ext1, GI.getexterior(g2);
        closed_line = true,
    )
    e1_on_e2 && return false
    !e1_in_e2 && return true

    for h2 in GI.gethole(g2)
        if e1_in_e2  # h2 could be outside of e1, but inside of e2
            h2_in_e1, h2_on_e1, h2_out_e1 = _line_filled_curve_interactions(
                h2, ext1;
                closed_line = true,
            )
            (h2_in_e1 || h2_on_e1) && return false

            if h2_out_e1 
                c1_val = point_filled_curve_orientation(centroid(ext1), h2)
                c1_val == point_in && return true  # e1 is within h2
            end
        end
    end
    return false
end

# Geometries within multipolygons
"""
    disjoint(::GI.AbstractTrait, g1, ::GI.MultiPolygonTrait, g2)::Bool

A geometry is disjoint from a multipolygon if it is disjoint from all of the
polygons that make up the multipolygon. Return true if these conditions are met,
else false.
"""
function disjoint(::GI.AbstractTrait, g1, ::GI.MultiPolygonTrait, g2)
    for poly in GI.getpolygon(g2)
        if !disjoint(g1, poly)
            return false
        end
    end
    return true
end

"""
    disjoint(::GI.MultiPolygonTrait, g1, ::GI.MultiPolygonTrait, g2)::Bool

A multipolygon is disjoint from a multipolygon if every polygon in the first
multipolygon is disjoint from all of the polygons in the second multipolygon.
Return true if these conditions are met, else false.
"""
function disjoint(::GI.MultiPolygonTrait, g1, ::GI.MultiPolygonTrait, g2)
    for poly1 in GI.getpolygon(g1)
        for poly2 in GI.getpolygon(g2)
            if !disjoint(poly1, poly2)
                return false
            end
        end
    end
    return true
end

