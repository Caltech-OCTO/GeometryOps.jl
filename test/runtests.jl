using GeometryOps
using Test

using GeometryOps.GeoInterface
using GeometryOps.GeometryBasics
using ArchGDAL
using LibGEOS
using Random, Distributions

const GI = GeoInterface
const AG = ArchGDAL
const LG = LibGEOS
const GO = GeometryOps

@testset "GeometryOps.jl" begin
    @testset "Primitives" begin include("primitives.jl") end
    # Methods
    @testset "Barycentric coordinate operations" begin include("methods/barycentric.jl") end
    @testset "Bools" begin include("methods/bools.jl") end
    @testset "Centroid" begin include("methods/centroid.jl") end
    @testset "Disjoint" begin include("methods/disjoint.jl") end
    @testset "Equals" begin include("methods/equals.jl") end
    # @testset "Geom in geom" begin include("methods/geom_in_geom.jl") end
    # @testset "Geom on geom" begin include("methods/geom_on_geom.jl") end
    @testset "Intersect" begin include("methods/intersects.jl") end
    @testset "Signed Area" begin include("methods/signed_area.jl") end
    @testset "Touches" begin include("methods/touches.jl") end
    @testset "Overlaps" begin include("methods/overlaps.jl") end
    @testset "Within" begin include("methods/within.jl") end

    # Transformations
    @testset "Reproject" begin include("transformations/reproject.jl") end
    @testset "Flip" begin include("transformations/flip.jl") end
    @testset "Simplify" begin include("transformations/simplify.jl") end
end
