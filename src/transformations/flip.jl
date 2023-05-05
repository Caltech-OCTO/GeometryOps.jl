"""
    flip(obj)

Swap all of the x and y coordinates in obj, otherwise
keeping the original structure (but not necessarily the
original type).
"""
function flip(geom) 
    if GI.is3d(geom)
        return apply(PointTrait, geom) do point
            (GI.y(p), GI.x(p), GI.z(p))
        end
    else
        return apply(PointTrait, geom) do point
            (GI.y(p), GI.x(p))
        end
    end
end