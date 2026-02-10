class PhotoSimilarityService
  BAND_COUNT  = 4
  BAND_BITS   = 16
  BAND_MASK   = (1_u64 << BAND_BITS) - 1

  def initialize(
    @entries : Array(PhotoAnalysisEntity),
    @photo_lookup : Hash(String, PhotoEntity),
    @threshold : Int32 = 5,
  )
  end

  def find_groups : Array(Array(PhotoEntity))
    # Parse pHash hex strings → UInt64
    hashes = @entries.map { |e| e.phash.to_u64(16) rescue 0_u64 }

    # LSH: split each 64-bit hash into bands, build candidate pairs
    band_tables = Array(Hash(UInt64, Array(Int32))).new(BAND_COUNT) do
      Hash(UInt64, Array(Int32)).new
    end

    hashes.each_with_index do |h, i|
      BAND_COUNT.times do |b|
        band_val = (h >> (b * BAND_BITS)) & BAND_MASK
        (band_tables[b][band_val] ||= [] of Int32) << i
      end
    end

    # Collect candidate pairs (share at least one band)
    candidates = Set(Tuple(Int32, Int32)).new
    band_tables.each do |table|
      table.each_value do |indices|
        next if indices.size < 2
        (0...indices.size).each do |a|
          (a + 1...indices.size).each do |b|
            i, j = indices[a], indices[b]
            candidates << (i < j ? {i, j} : {j, i})
          end
        end
      end
    end

    # Exact Hamming distance check + Union-Find merge
    parent = Array(Int32).new(@entries.size) { |i| i }
    rank = Array(Int32).new(@entries.size, 0)

    candidates.each do |pair|
      i, j = pair
      dist = hamming_distance(hashes[i], hashes[j])
      if dist <= @threshold
        union(parent, rank, i, j)
      end
    end

    # Extract groups with size > 1, resolve to PhotoEntity
    groups = Hash(Int32, Array(PhotoEntity)).new
    @entries.each_with_index do |entry, i|
      key = "#{entry.post_slug}/#{entry.image_filename}"
      pe = @photo_lookup[key]?
      next unless pe

      root = find(parent, i)
      (groups[root] ||= [] of PhotoEntity) << pe
    end

    groups.values.select { |g| g.size > 1 }
  end

  private def hamming_distance(a : UInt64, b : UInt64) : Int32
    (a ^ b).popcount.to_i
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
