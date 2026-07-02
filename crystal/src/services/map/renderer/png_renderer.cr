class Map::Renderer::PngRenderer
  def self.render(result : MapResult, width : Int32 = 1200) : Bytes
    svg = SvgRenderer.render(result)

    # Write SVG to temp file
    tmp_svg = File.tempfile("map", ".svg") do |f|
      f.print(svg)
    end

    tmp_png = File.tempfile("map", ".png")

    begin
      status = Process.run(
        "rsvg-convert",
        ["-w", width.to_s, tmp_svg.path, "-o", tmp_png.path]
      )

      raise "rsvg-convert failed" unless status.success?
      File.read(tmp_png.path).to_slice
    ensure
      tmp_svg.delete
      tmp_png.delete
    end
  end

  def self.available? : Bool
    status = Process.run("which", ["rsvg-convert"])
    status.success?
  rescue
    false
  end
end
