require "log"
require "../data/src/commands/tools/spellcheck"

Log.setup_from_env

env = "full"
slug_filter : String? = nil
verbose = false

ARGV.each do |arg|
  case arg
  when "--dev"
    env = "dev"
  when "--verbose", "-v"
    verbose = true
  when .starts_with?("--slug=")
    slug_filter = arg.split("=", 2).last
  when .starts_with?("--")
    # skip unknown flags
  else
    slug_filter = arg
  end
end

command = Commands::Tools::Spellcheck.new(
  env: env,
  slug_filter: slug_filter,
  verbose: verbose,
)
command.run
