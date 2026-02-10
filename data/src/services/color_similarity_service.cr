class ColorSimilarityService
  def initialize(
    @entries : Array(PhotoAnalysisEntity),
    @photo_lookup : Hash(String, PhotoEntity),
    @max_distance : Float64 = 30.0,
  )
  end

  def find_groups : Array(Array(PhotoEntity))
    # Filter to entries that have valid avg_rgb and exist in photo_lookup
    valid = @entries.select { |e| e.avg_rgb.size == 3 }
    return [] of Array(PhotoEntity) if valid.size < 2

    parent = Array(Int32).new(valid.size) { |i| i }
    rank = Array(Int32).new(valid.size, 0)

    # Pairwise Euclidean distance on avg_rgb
    (0...valid.size).each do |i|
      (i + 1...valid.size).each do |j|
        dist = euclidean_distance(valid[i].avg_rgb, valid[j].avg_rgb)
        if dist <= @max_distance
          union(parent, rank, i, j)
        end
      end
    end

    # Extract groups with size > 1, resolve to PhotoEntity
    groups = Hash(Int32, Array(PhotoEntity)).new
    valid.each_with_index do |entry, i|
      key = "#{entry.post_slug}/#{entry.image_filename}"
      pe = @photo_lookup[key]?
      next unless pe

      root = find(parent, i)
      (groups[root] ||= [] of PhotoEntity) << pe
    end

    groups.values.select { |g| g.size > 1 }
  end

  private def euclidean_distance(a : Array(Int32), b : Array(Int32)) : Float64
    sum = 0.0
    a.each_with_index do |v, i|
      diff = v - b[i]
      sum += diff * diff
    end
    Math.sqrt(sum)
  end

  private def find(parent : Array(Int32), i : Int32) : Int32
    while parent[i] != i
      parent[i] = parent[parent[i]]
      i = parent[i]
    end
    i
  end

  private def union(parent : Array(Int32), rank : Array(Int32), a : Int32, b : Int32)
    ra = find(parent, a)
    rb = find(parent, b)
    return if ra == rb
    if rank[ra] < rank[rb]
      parent[ra] = rb
    elsif rank[ra] > rank[rb]
      parent[rb] = ra
    else
      parent[rb] = ra
      rank[ra] += 1
    end
  end
end
