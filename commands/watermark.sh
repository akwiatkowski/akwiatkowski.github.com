#!/bin/bash
# Resize photos to 3200x2400 and add watermark overlay.
# Run from inside a photo directory (e.g. ~/Photos/2024-07-18-wycieczka/).
# Requires: imagemagick 7+ (magick), watermark PNG.

path=~/Temp/zdjecia_processed
process_type=watermark_small
current_directory=$(basename "$PWD")
watermark=~/projects/scripts/attachments/watermark.png

full_path="${path}/${process_type}/${current_directory}"

echo "$full_path"

mkdir -p "${full_path}"

find . -iname '*.jpg' | while read -r file; do
  output="${full_path}/${file}"

  if [ -f "${output}" ]; then
    echo "File ${output} exists."
  else
    mkdir -p "$(dirname "${output}")"
    echo -n "Converting ${file} -> ${output}: "
    magick "$file" -resize 3200x2400 miff:- | magick composite -quality 80 -dissolve 50% -gravity south "$watermark" miff:- "$output"
    echo done
  fi
done
