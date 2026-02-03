require "./lib_geos"

# Crystal wrapper for GEOS geometry operations.
#
# Usage:
#   GEOS.with_context do |ctx|
#     poly1 = ctx.polygon_from_coords([[0,0], [1,0], [1,1], [0,1], [0,0]])
#     poly2 = ctx.polygon_from_coords([[0.5,0.5], [1.5,0.5], [1.5,1.5], [0.5,1.5], [0.5,0.5]])
#     area = ctx.intersection_area(poly1, poly2)
#     ctx.destroy(poly1)
#     ctx.destroy(poly2)
#   end

module GEOS
  VERSION = String.new(LibGEOS.GEOSversion)

  class GEOSError < Exception; end

  # Wrapper for a GEOS geometry pointer with its context
  struct Geometry
    getter ptr : Void*
    getter ctx : Void*

    def initialize(@ctx : Void*, @ptr : Void*)
    end

    def null?
      @ptr.null?
    end
  end

  # Prepared geometry for faster repeated intersection tests
  struct PreparedGeometry
    getter ptr : Void*
    getter ctx : Void*

    def initialize(@ctx : Void*, @ptr : Void*)
    end

    def null?
      @ptr.null?
    end
  end

  # Context manages GEOS state and provides operations
  class Context
    @ctx : Void*
    @wkt_reader : Void*

    def initialize
      @ctx = LibGEOS.GEOS_init_r
      raise GEOSError.new("Failed to initialize GEOS context") if @ctx.null?

      # Silence GEOS warnings/notices (they go to stderr otherwise)
      # Comment these out for debugging
      LibGEOS.GEOSContext_setNoticeHandler_r(@ctx, ->(msg, data) { })
      LibGEOS.GEOSContext_setErrorHandler_r(@ctx, ->(msg, data) { })

      @wkt_reader = LibGEOS.GEOSWKTReader_create_r(@ctx)
      raise GEOSError.new("Failed to create WKT reader") if @wkt_reader.null?
    end

    def finalize
      LibGEOS.GEOSWKTReader_destroy_r(@ctx, @wkt_reader) unless @wkt_reader.null?
      LibGEOS.GEOS_finish_r(@ctx) unless @ctx.null?
    end

    # Create polygon from coordinate array [[lon, lat], ...]
    # Coordinates must form a closed ring (first == last)
    def polygon_from_coords(coords : Array(Array(Float64))) : Geometry?
      return nil if coords.size < 4

      # Build WKT string: POLYGON((lon lat, lon lat, ...))
      wkt = String.build do |s|
        s << "POLYGON(("
        coords.each_with_index do |coord, i|
          s << ", " if i > 0
          s << coord[0] << " " << coord[1]
        end
        s << "))"
      end

      from_wkt(wkt)
    end

    # Create linestring from coordinate array [[lon, lat], ...]
    def linestring_from_coords(coords : Array(Array(Float64))) : Geometry?
      return nil if coords.size < 2

      # Build WKT string: LINESTRING(lon lat, lon lat, ...)
      wkt = String.build do |s|
        s << "LINESTRING("
        coords.each_with_index do |coord, i|
          s << ", " if i > 0
          s << coord[0] << " " << coord[1]
        end
        s << ")"
      end

      from_wkt(wkt)
    end

    # Get geometry type ID
    def geometry_type(geom : Geometry) : Int32
      LibGEOS.GEOSGeomTypeId_r(@ctx, geom.ptr).to_i32
    end

    # Get number of geometries in a collection
    def num_geometries(geom : Geometry) : Int32
      LibGEOS.GEOSGetNumGeometries_r(@ctx, geom.ptr).to_i32
    end

    # Get geometry N from a collection (does not need to be destroyed separately)
    def get_geometry_n(geom : Geometry, n : Int32) : Geometry?
      ptr = LibGEOS.GEOSGetGeometryN_r(@ctx, geom.ptr, n)
      return nil if ptr.null?
      Geometry.new(@ctx, ptr)
    end

    # Extract coordinates from a linestring as [[lon, lat], ...]
    def linestring_coords(geom : Geometry) : Array(Array(Float64))
      result = [] of Array(Float64)

      coord_seq = LibGEOS.GEOSGeom_getCoordSeq_r(@ctx, geom.ptr)
      return result if coord_seq.null?

      size = 0_u32
      return result if LibGEOS.GEOSCoordSeq_getSize_r(@ctx, coord_seq, pointerof(size)) == 0

      size.times do |i|
        x = 0.0_f64
        y = 0.0_f64
        LibGEOS.GEOSCoordSeq_getX_r(@ctx, coord_seq, i, pointerof(x))
        LibGEOS.GEOSCoordSeq_getY_r(@ctx, coord_seq, i, pointerof(y))
        result << [x, y]
      end

      result
    end

    # Extract all coordinates from any geometry type (handles collections)
    # Returns array of linestrings, each linestring is array of [lon, lat]
    def extract_all_linestring_coords(geom : Geometry) : Array(Array(Array(Float64)))
      result = [] of Array(Array(Float64))
      geom_type = geometry_type(geom)

      case geom_type
      when GEOSGeomTypes::LINESTRING, GEOSGeomTypes::LINEARRING
        coords = linestring_coords(geom)
        result << coords unless coords.empty?
      when GEOSGeomTypes::MULTILINESTRING, GEOSGeomTypes::GEOMETRYCOLLECTION
        num = num_geometries(geom)
        num.times do |i|
          sub_geom = get_geometry_n(geom, i)
          next if sub_geom.nil?
          # Recursively extract from sub-geometries
          sub_results = extract_all_linestring_coords(sub_geom.not_nil!)
          result.concat(sub_results)
        end
      when GEOSGeomTypes::POLYGON
        # For polygon intersections, extract the exterior ring
        coords = exterior_coords(geom)
        result << coords unless coords.empty?
      when GEOSGeomTypes::MULTIPOLYGON
        num = num_geometries(geom)
        num.times do |i|
          sub_geom = get_geometry_n(geom, i)
          next if sub_geom.nil?
          coords = exterior_coords(sub_geom.not_nil!)
          result << coords unless coords.empty?
        end
      end

      result
    end

    # Parse WKT string to geometry
    def from_wkt(wkt : String) : Geometry?
      ptr = LibGEOS.GEOSWKTReader_read_r(@ctx, @wkt_reader, wkt.to_unsafe)
      return nil if ptr.null?
      Geometry.new(@ctx, ptr)
    end

    # Destroy a geometry (free memory)
    def destroy(geom : Geometry)
      LibGEOS.GEOSGeom_destroy_r(@ctx, geom.ptr) unless geom.null?
    end

    def destroy(geom : PreparedGeometry)
      LibGEOS.GEOSPreparedGeom_destroy_r(@ctx, geom.ptr) unless geom.null?
    end

    # Check if geometry is empty
    def empty?(geom : Geometry) : Bool
      result = LibGEOS.GEOSisEmpty_r(@ctx, geom.ptr)
      result == 1_i8
    end

    # Check if geometry is valid
    def valid?(geom : Geometry) : Bool
      result = LibGEOS.GEOSisValid_r(@ctx, geom.ptr)
      result == 1_i8
    end

    # Fix invalid geometry using buffer(0) trick
    def make_valid(geom : Geometry) : Geometry?
      buffered = LibGEOS.GEOSBuffer_r(@ctx, geom.ptr, 0.0, 8)
      return nil if buffered.null?
      Geometry.new(@ctx, buffered)
    end

    # Calculate area of geometry
    def area(geom : Geometry) : Float64?
      area_val = 0.0_f64
      result = LibGEOS.GEOSArea_r(@ctx, geom.ptr, pointerof(area_val))
      return nil if result == 0
      area_val
    end

    # Check if two geometries intersect
    def intersects?(g1 : Geometry, g2 : Geometry) : Bool
      result = LibGEOS.GEOSIntersects_r(@ctx, g1.ptr, g2.ptr)
      result == 1_i8
    end

    # Compute intersection of two geometries
    def intersection(g1 : Geometry, g2 : Geometry) : Geometry?
      ptr = LibGEOS.GEOSIntersection_r(@ctx, g1.ptr, g2.ptr)
      return nil if ptr.null?
      Geometry.new(@ctx, ptr)
    end

    # Compute intersection area directly (convenience method)
    def intersection_area(g1 : Geometry, g2 : Geometry) : Float64
      inter = intersection(g1, g2)
      return 0.0 if inter.nil?

      result = area(inter.not_nil!)
      destroy(inter.not_nil!)

      result || 0.0
    end

    # Create prepared geometry for faster repeated intersection tests
    def prepare(geom : Geometry) : PreparedGeometry?
      ptr = LibGEOS.GEOSPrepare_r(@ctx, geom.ptr)
      return nil if ptr.null?
      PreparedGeometry.new(@ctx, ptr)
    end

    # Fast intersection test using prepared geometry
    def prepared_intersects?(prepared : PreparedGeometry, other : Geometry) : Bool
      result = LibGEOS.GEOSPreparedIntersects_r(@ctx, prepared.ptr, other.ptr)
      result == 1_i8
    end

    # Get a point guaranteed to be inside the polygon (representative point)
    def point_on_surface(geom : Geometry) : {Float64, Float64}?
      point_ptr = LibGEOS.GEOSPointOnSurface_r(@ctx, geom.ptr)
      return nil if point_ptr.null?

      x = 0.0_f64
      y = 0.0_f64
      x_ok = LibGEOS.GEOSGeomGetX_r(@ctx, point_ptr, pointerof(x))
      y_ok = LibGEOS.GEOSGeomGetY_r(@ctx, point_ptr, pointerof(y))

      LibGEOS.GEOSGeom_destroy_r(@ctx, point_ptr)

      return nil if x_ok == 0 || y_ok == 0
      {x, y} # Returns {lon, lat}
    end

    # Extract exterior ring coordinates from polygon as [[lon, lat], ...]
    def exterior_coords(geom : Geometry) : Array(Array(Float64))
      result = [] of Array(Float64)

      ring = LibGEOS.GEOSGetExteriorRing_r(@ctx, geom.ptr)
      return result if ring.null?

      coord_seq = LibGEOS.GEOSGeom_getCoordSeq_r(@ctx, ring)
      return result if coord_seq.null?

      size = 0_u32
      return result if LibGEOS.GEOSCoordSeq_getSize_r(@ctx, coord_seq, pointerof(size)) == 0

      size.times do |i|
        x = 0.0_f64
        y = 0.0_f64
        LibGEOS.GEOSCoordSeq_getX_r(@ctx, coord_seq, i, pointerof(x))
        LibGEOS.GEOSCoordSeq_getY_r(@ctx, coord_seq, i, pointerof(y))
        result << [x, y]
      end

      result
    end
  end

  # Convenience method to use GEOS with automatic cleanup
  def self.with_context(&)
    ctx = Context.new
    begin
      yield ctx
    ensure
      ctx.finalize
    end
  end
end
