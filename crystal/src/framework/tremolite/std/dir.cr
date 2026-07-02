class Dir
  def self.mkdir_p_dirname(p : String)
    # puts "create dir #{p}, #{File.dirname(p)}"
    Dir.mkdir_p(File.dirname(p))
  end
end
