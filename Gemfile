source 'https://rubygems.org'

require 'json'
require 'open-uri'
versions = JSON.parse(open('https://pages.github.com/versions.json').read)
#versions['github-pages'] = '72' # temp fix https://github.com/jekyll/jekyll/issues/4830

gem 'github-pages', versions['github-pages']
