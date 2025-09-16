#!/bin/bash    
echo Running in $SHELL
echo Building Defenistration_game...

mkdir build

odin build ../game/src/ -out:build/Defenistration_game.exe

echo Finished Building Defenistration_game...

sudo cp -r ../game/content/ build/ 

ZIP_NAME=$(sed -n '1p' build_data.txt | tr -d '[:space:]')

# r = recursive, q = quite
zip -rq ${ZIP_NAME}.zip build

# sudo rm -r build

sleep 2

exit 0


