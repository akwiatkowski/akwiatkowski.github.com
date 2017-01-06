watch:
	bash watch.sh

watch_coffee:
	coffee -bcw data/assets/js/*.coffee

upload:
	bash release_ovh.sh

run:
	crystal src/odkrywajac_polske.cr

serve:
	cd public && serve
