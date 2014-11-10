#!/bin/bash
cd
mkdir grassdata
cd grasssdata
mkdir masloc
cd masloc
mkdir PERMANENT
cd PERMANENT
echo "proj:       99" > DEFAULT_WIND
echo "zone:       0" >> DEFAULT_WIND
echo "north:      1" >> DEFAULT_WIND
echo "south:      0" >> DEFAULT_WIND
echo "east:       1" >> DEFAULT_WIND
echo "west:       0" >> DEFAULT_WIND
echo "cols:       1" >> DEFAULT_WIND
echo "rows:       1" >> DEFAULT_WIND
echo "e-w resol:  1" >> DEFAULT_WIND
echo "n-s resol:  1" >> DEFAULT_WIND
echo "top:        1.000000000000000" >> DEFAULT_WIND
echo "bottom:     0.000000000000000" >> DEFAULT_WIND
echo "cols3:      1" >> DEFAULT_WIND
echo "rows3:      1" >> DEFAULT_WIND
echo "depths:     1" >> DEFAULT_WIND
echo "e-w resol3: 1" >> DEFAULT_WIND
echo "n-s resol3: 1" >> DEFAULT_WIND
echo "t-b resol:  1" >> DEFAULT_WIND
cp DEFAULT_WIND WIND
cd
#WIND and DEFAULT_WIND
echo "GISDBASE: ${HOME}/grassdata" >${HOME}/.grassrc
echo "LOCATION_NAME: masloc" >> ${HOME}/.grassrc
echo "MAPSET: PERMANENT" >> ${HOME}/.grassrc
echo "GRASS_GUI: text" >> ${HOME}/.grassrc
