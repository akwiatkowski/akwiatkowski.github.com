# aliases
all_compile: dev_compile_release dev_compile compile_release compile

# dev env
dev_serve_local:
	cd env/dev/public/local && npx serve -p 5001

dev_serve_release:
	cd env/dev/public/release && npx serve -p 5001

dev_render_release:
	crystal env/dev/src/render_release.cr

# release is executed once to refresh all parts of website
# local means using local version of `tremolite` shard
dev_compile_release:
	crystal build env/dev/src/run_local_full.cr -o env/dev/blog_release --release

dev_run_compiled_release:
	env/dev/blog_release

dev_compile_and_run: dev_clean_compiled dev_compile dev_run_compiled

dev_compile:
	crystal build env/dev/src/run_local.cr -o env/dev/blog --release

dev_compile_fast:
	crystal build env/dev/src/run_local.cr -o env/dev/blog

dev_run_compiled:
	CRYSTAL_LOG_LEVEL=DEBUG CRYSTAL_LOG_SOURCES="*" env/dev/blog

dev_clean_compiled:
	rm env/dev/blog

dev_watch_smart:
	bash env/dev/watch_smart.sh

# full env
serve:
	cd env/full/public && npx serve -p 5001

release: run_compiled_release

release_ovh:
	cd env/full && ./release_ovh.sh

render_release:
	crystal env/full/src/run_local_full.cr

compile_release:
	crystal build env/full/src/run_local_full.cr -o env/full/blog_release --release

run_compiled_release:
	env/full/blog_release

compile:
	crystal build env/full/src/run_local.cr -o env/full/blog --release

run_compiled:
	CRYSTAL_LOG_LEVEL=DEBUG CRYSTAL_LOG_SOURCES="*" env/full/blog

watch_smart:
	# bash env/full/watch_smart.sh
	bash env/full/watch_smart_mac.sh

watch_coffee:
	coffee -bcw data/assets/js/*.coffee


# old stuff
# watch:
# 	bash watch.sh
#
# watch_dev:
# 	bash watch_dev.sh
#
# watch_compiled:
# 	bash watch_compiled.sh
#
#
# upload:
# 	bash release_ovh.sh
#
# run:
# 	crystal src/odkrywajac_polske.cr
#
# serve:
# 	cd public && serve -p 5001
#
#
# compile:
# 	crystal build src/odkrywajac_polske.cr -o blog --release
