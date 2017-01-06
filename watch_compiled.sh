inotifywait -e close_write,moved_to,create -mr data/ |
while read path action file; do
  echo "The file '$file' appeared in directory '$path' via '$action'"
  ./blog
  echo "Done"
done
