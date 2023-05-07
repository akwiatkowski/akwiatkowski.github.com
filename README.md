
# odkrywajac_polske

This is my [non-technical blog](http://odkrywajacpolske.pl) converted from
[Jekyll](https://jekyllrb.com/) to [`tremolite`](https://github.com/akwiatkowski/tremolite).

## Roadmap

1. [ ] Copy [my blog in Jekyll](http://odkrywajacpolske.pl/) features:
  * [x] Index
  * [x] Paginated list
  * [x] Header image resize
  * [x] Summary
  * [x] Pois
  * [x] Remove gallery, link to smugmug, 500px, panoramio dead (ugly google)
  * [x] Plans / TODO
  * [x] Plans / TODO - notes link
  * [x] Plans / TODO - predefined filters (short 4h trip, day 4-8h, long day 6-12h, external 1day, external)
  * [x] Planner
  * [x] Tag pages `/tag/{{name}}`
  * [x] Tags list page `/tags/`
  * [x] Tags post field
  * [x] Land pages `/land/{{name}}`
  * [x] Lands list `/lands/`
  * [x] Lands post field
  * [x] Towns pages `/town/{{name}}`
  * [x] Towns list `/towns`
  * [x] Towns post field
  * [x] Pois post field
  * [x] RSS/Atom


2. [ ] TODO
  * [x] Separate environment for developing new features
  * [ ] Town statistics
  * [x] RSS/Atom by tags
  * [ ] Post summary JSON - partially
  * [ ] About: check this http://kolejnapodroz.pl/blogu/
  * [ ] Clean photo_maps structure
  * [ ] Move navigation related but processable elements to cache, render only at full render to
        make post update renders super fast
  * [ ] Add diff to check what has changed (stream or temp file)
  * [ ] `nogallery` should be removed and also regular full-gallery
  * [ ] Fix duplicated photos: header and regular filename
  * [ ] Gallery rendered - browser like
  * [ ] Move `header_timeline` markdown flag for photo timeline to tags by using `photo_header`
  * [ ] Add `horizontal?` to exif and filter only horizontal photos for gallery header
  * [ ] Cache quantified areas of coords and links used in post. Post which have more
        percentage of similar coords and links are most similar
  * [ ] profiler - which part take time
  * [ ] "test env" - test various feature (processing) on limited version of webpage
  * [ ] graph which lenses I use (limit to few)
  * [ ] generate route map internally, remove strava integration

### Separate full version from minimal dev version

* cache - TODO: separate and move into data
* data
  * assets - static stuff used in all versions
  * drafts - TODO: move outside of full version
  * images - TODO: separate
  * layout - used to create html output for all versions
  * pages - text only pages converted to html
  * posts - TODO: separate
  * routes - TODO: separate
  * src - used for both, move somewhere else
  * towns - move to place with yaml configs
  * *.yml - move as above
* public - TODO: separate, keep in mind to update upload scripts  


## Installation

TODO: Write installation instructions here

## Usage

TODO: Write usage instructions here

## Development

TODO: Write development instructions here

## Contributing

1. Fork it ( https://github.com/akwiatkowski/odkrywajac_polske/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [akwiatkowski](https://github.com/akwiatkowski) Aleksander Kwiatkowski - creator, maintainer
