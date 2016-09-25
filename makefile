compile_js:
	coffee -bcw js/*.coffee

create_thumbnails:
	ruby _tools/prepare_index_smalls.rb

generate_towns:
	crystal _tools/create_towns_yaml.cr

update_gems:
	bundle update

reset:
	jekyll clean
	jekyll build
