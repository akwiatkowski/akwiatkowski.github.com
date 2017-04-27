inotifywait -e close_write,moved_to,create -mr data/ /home/olek/projects/self/crystal/tremolite/src/ src/ |
while read path action file; do
  if [ ${file: -3} == ".cr" ]
  then
    echo "The file '$file' appeared in directory '$path' via '$action'"

    # --release flag is not suitable here
    crystal src/odkrywajac_polske.cr -o blog
    echo "Compiled"

    ./blog
  else
    echo "The file '$file' appeared in directory '$path' via '$action'"
    ./blog
  fi
  echo "Done"
done
