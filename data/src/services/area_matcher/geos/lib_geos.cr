# GEOS C API bindings for Crystal
#
# This binds to libgeos_c (the stable C API).
# Install GEOS:
#   macOS:        brew install geos
#   Ubuntu/Debian: apt install libgeos-dev
#   Fedora:       dnf install geos-devel
#
# We use the reentrant (_r suffix) API for thread safety.
# All functions take a context handle as first argument.

@[Link("geos_c")]
lib LibGEOS
  # --- Version ---
  fun GEOSversion : LibC::Char*

  # --- Context management (reentrant API) ---
  # Create a context for thread-safe operations
  fun GEOS_init_r : Void*
  fun GEOS_finish_r(ctx : Void*)

  # Error/notice handlers (optional, can be set to silence warnings)
  alias MessageHandler = (LibC::Char*, Void*) ->
  fun GEOSContext_setNoticeHandler_r(ctx : Void*, handler : MessageHandler)
  fun GEOSContext_setErrorHandler_r(ctx : Void*, handler : MessageHandler)

  # --- WKT Reader (parse text to geometry) ---
  fun GEOSWKTReader_create_r(ctx : Void*) : Void*
  fun GEOSWKTReader_destroy_r(ctx : Void*, reader : Void*)
  fun GEOSWKTReader_read_r(ctx : Void*, reader : Void*, wkt : LibC::Char*) : Void*

  # --- WKT Writer (geometry to text, useful for debugging) ---
  fun GEOSWKTWriter_create_r(ctx : Void*) : Void*
  fun GEOSWKTWriter_destroy_r(ctx : Void*, writer : Void*)
  fun GEOSWKTWriter_write_r(ctx : Void*, writer : Void*, geom : Void*) : LibC::Char*
  fun GEOSWKTWriter_setRoundingPrecision_r(ctx : Void*, writer : Void*, precision : LibC::Int)

  # --- Geometry destruction ---
  fun GEOSGeom_destroy_r(ctx : Void*, geom : Void*)
  fun GEOSFree_r(ctx : Void*, ptr : Void*)

  # --- Geometry predicates ---
  # Return values: 1 = true, 0 = false, 2 = exception
  fun GEOSisEmpty_r(ctx : Void*, geom : Void*) : LibC::Char
  fun GEOSisValid_r(ctx : Void*, geom : Void*) : LibC::Char
  fun GEOSIntersects_r(ctx : Void*, g1 : Void*, g2 : Void*) : LibC::Char

  # --- Geometry operations ---
  fun GEOSIntersection_r(ctx : Void*, g1 : Void*, g2 : Void*) : Void*
  fun GEOSBuffer_r(ctx : Void*, geom : Void*, width : Float64, quadsegs : LibC::Int) : Void*

  # --- Measurements ---
  # Returns 1 on success, 0 on exception. Result written to pointer.
  fun GEOSArea_r(ctx : Void*, geom : Void*, area : Float64*) : LibC::Int
  fun GEOSLength_r(ctx : Void*, geom : Void*, length : Float64*) : LibC::Int

  # --- Point extraction ---
  fun GEOSGetInteriorRingN_r(ctx : Void*, geom : Void*, n : LibC::Int) : Void*
  fun GEOSGetExteriorRing_r(ctx : Void*, geom : Void*) : Void*
  fun GEOSGeomGetNumPoints_r(ctx : Void*, geom : Void*) : LibC::Int
  fun GEOSGeomGetPointN_r(ctx : Void*, geom : Void*, n : LibC::Int) : Void*
  fun GEOSGeomGetX_r(ctx : Void*, geom : Void*, x : Float64*) : LibC::Int
  fun GEOSGeomGetY_r(ctx : Void*, geom : Void*, y : Float64*) : LibC::Int

  # --- Geometry info ---
  fun GEOSGeomTypeId_r(ctx : Void*, geom : Void*) : LibC::Int
  fun GEOSGetNumGeometries_r(ctx : Void*, geom : Void*) : LibC::Int
  fun GEOSGetGeometryN_r(ctx : Void*, geom : Void*, n : LibC::Int) : Void*

  # --- Coordinate Sequence access (for extracting polygon coords) ---
  fun GEOSGeom_getCoordSeq_r(ctx : Void*, geom : Void*) : Void*
  fun GEOSCoordSeq_getSize_r(ctx : Void*, seq : Void*, size : LibC::UInt*) : LibC::Int
  fun GEOSCoordSeq_getX_r(ctx : Void*, seq : Void*, idx : LibC::UInt, x : Float64*) : LibC::Int
  fun GEOSCoordSeq_getY_r(ctx : Void*, seq : Void*, idx : LibC::UInt, y : Float64*) : LibC::Int

  # --- Point on surface (representative point inside polygon) ---
  fun GEOSPointOnSurface_r(ctx : Void*, geom : Void*) : Void*

  # --- Centroid ---
  fun GEOSGetCentroid_r(ctx : Void*, geom : Void*) : Void*

  # --- Prepared geometry (faster repeated operations) ---
  fun GEOSPrepare_r(ctx : Void*, geom : Void*) : Void*
  fun GEOSPreparedGeom_destroy_r(ctx : Void*, prepared : Void*)
  fun GEOSPreparedIntersects_r(ctx : Void*, prepared : Void*, other : Void*) : LibC::Char
end

# Geometry type IDs from GEOS
module GEOSGeomTypes
  POINT              = 0
  LINESTRING         = 1
  LINEARRING         = 2
  POLYGON            = 3
  MULTIPOINT         = 4
  MULTILINESTRING    = 5
  MULTIPOLYGON       = 6
  GEOMETRYCOLLECTION = 7
end
