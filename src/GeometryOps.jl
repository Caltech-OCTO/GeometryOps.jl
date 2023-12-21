# # GeometryOps.jl

module GeometryOps

using GeoInterface
using GeometryBasics
import Proj
using LinearAlgebra
import ExactPredicates

using GeoInterface.Extents: Extents

const GI = GeoInterface
const GB = GeometryBasics

const TuplePoint = Tuple{Float64,Float64}
const Edge = Tuple{TuplePoint,TuplePoint}

include("primitives.jl")
include("utils.jl")

include("methods/geom_relations/bools.jl")
include("methods/signed_distance.jl")
include("methods/signed_area.jl")
include("methods/centroid.jl")
include("methods/geom_relations/intersects.jl")
include("methods/geom_relations/contains.jl")
include("methods/geom_relations/covers.jl")
include("methods/geom_relations/coveredby.jl")
include("methods/geom_relations/crosses.jl")
include("methods/geom_relations/disjoint.jl")
include("methods/geom_relations/overlaps.jl")
include("methods/geom_relations/within.jl")
include("methods/polygonize.jl")
include("methods/barycentric.jl")
include("methods/geom_relations/equals.jl")
include("methods/geom_relations/geom_geom_processors.jl")
include("methods/orientation.jl")
include("methods/geom_relations/touches.jl")
include("transformations/flip.jl")
include("transformations/simplify.jl")
include("transformations/reproject.jl")
include("transformations/tuples.jl")

end
