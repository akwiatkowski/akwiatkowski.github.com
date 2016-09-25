release:
	$(MAKE) coffee
	$(MAKE) create_thumbnails
	$(MAKE) generate_towns

coffee:
	coffee -bc js/*.coffee

coffee_watch:
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
