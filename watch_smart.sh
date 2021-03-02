# refactored while loop because I had problem with files changes during
# blog rendering
while :
do
  inotify_output=`inotifywait -e close_write,moved_to,create -r data/ /home/olek/projects/self/crystal/tremolite/src/ src/ --exclude public/`
  # assing vars
  read -r path action file <<< "$inotify_output"

  echo "file '$file' in '$path' via '$action'"

  if [ ${file: -3} == ".cr" ]
  then
    # --release flag is not suitable here

    rm ./blog
    crystal build src/odkrywajac_polske_local.cr -o blog #--error-trace

    echo "compiled"
  else
    echo "running"
  fi

  CRYSTAL_LOG_LEVEL=DEBUG CRYSTAL_LOG_SOURCES="*" ./blog

  echo "Done"
done
