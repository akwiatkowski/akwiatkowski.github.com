watch:
	bash watch.sh

watch_dev:
	bash watch_dev.sh

watch_compiled:
	bash watch_compiled.sh

watch_coffee:
	coffee -bcw data/assets/js/*.coffee

upload:
	bash release_ovh.sh

run:
	crystal src/odkrywajac_polske.cr

serve:
	cd public && serve -p 5001

compile:
	crystal build src/odkrywajac_polske.cr -o blog --release
