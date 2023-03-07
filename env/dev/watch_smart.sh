# refactored while loop because I had problem with files changes during
# blog rendering
while :
do
  inotify_output=`inotifywait -e close_write,moved_to,create -r data/ /home/olek/projects/self/crystal/tremolite/src/ data/src/ --exclude public/`
  # assing vars
  read -r path action file <<< "$inotify_output"

  echo "file '$file' in '$path' via '$action'"

  if [ ${file: -3} == ".cr" ]
  then
    make dev_clean_compiled
    make dev_compile
    echo "compiled"
  else
    echo "running"
  fi

  make dev_run_compiled
  echo "Done"
done
