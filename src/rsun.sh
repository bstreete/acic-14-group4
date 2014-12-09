#!/bin/bash
#Configuration
# if [ -d ${HOME}/grassdata ]; then
# rm -rf "${HOME}/grassdata"
# fi
START_DIR=${PWD}
TEMP_DIR='tmp_${RANDOM}_$(date +%s.%N)'
cd ${HOME}
mkdir grassdata
cd grassdata
mkdir $TEMP_DIR
cd $TEMP_DIR
mkdir PERMANENT
cd PERMANENT
echo "proj: 99" > DEFAULT_WIND
echo "zone: 0" >> DEFAULT_WIND
echo "north: 1" >> DEFAULT_WIND
echo "south: 0" >> DEFAULT_WIND
echo "east: 1" >> DEFAULT_WIND
echo "west: 0" >> DEFAULT_WIND
echo "cols: 1" >> DEFAULT_WIND
echo "rows: 1" >> DEFAULT_WIND
echo "e-w resol: 1" >> DEFAULT_WIND
echo "n-s resol: 1" >> DEFAULT_WIND
echo "top: 1.000000000000000" >> DEFAULT_WIND
echo "bottom: 0.000000000000000" >> DEFAULT_WIND
echo "cols3: 1" >> DEFAULT_WIND
echo "rows3: 1" >> DEFAULT_WIND
echo "depths: 1" >> DEFAULT_WIND
echo "e-w resol3: 1" >> DEFAULT_WIND
echo "n-s resol3: 1" >> DEFAULT_WIND
echo "t-b resol: 1" >> DEFAULT_WIND
cp DEFAULT_WIND WIND
#WIND and DEFAULT_WIND
if [ -e ${HOME}/.grassrc ]; then
rm -f ${HOME}/.grassrc
fi
echo "GISDBASE: ${HOME}/grassdata" >${HOME}/.grassrc
echo "LOCATION_NAME: ${TEMP_DIR}" >> ${HOME}/.grassrc
echo "MAPSET: PERMANENT" >> ${HOME}/.grassrc
echo "GRASS_GUI: text" >> ${HOME}/.grassrc

cd $START_DIR

#Parameter setting
stepsize=0.05
interval=1
starttime=$(date +%s)
day=$2
outputts=$3
outputfts=$4
#set up envvar for UAHPC only
export GISBASE=/gsfs1/xdisk/nirav/grass/grass-6.4.4
export PATH="$GISBASE/bin:$GISBASE/scripts:$PATH"
export LD_LIBRARY_PATH="/gsfs1/xdisk/nirav/grass/grass-6.4.4/lib:/gsfs1/xdisk/nirav/grass-6.4.4/ext/lib:/gsfs1/xdisk/nirav/lib"
# export GISBASE="/usr/lib/grass64"
# export PATH="/usr/lib/grass64/bin:/usr/lib/grass64/scripts:$PATH"
# export LD_LIBRARY_PATH="/usr/lib/grass64/lib"
export GRASS_LD_LIBRARY_PATH="$LD_LIBRARY_PATH"
export GISRC="$HOME/.grassrc"
#update project info
g.proj -c proj4="+proj=lcc +lat_1=25 +lat_2=60 +lat_0=42.5 +lon_0=-100 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"
#loop head
#input
g.mremove -f "*"
r.in.gdal input=$1 output=dem_10m
echo "Elapsed time: $(($(date +%s)-$starttime))"
#set region
g.region -s rast=dem_10m
#run model
r.slope.aspect elevation=dem_10m slope=slope aspect=aspect
#r.sun -s elevin=dem_10m aspin=aspect slopein=slope day="1" step="0.05" dist="1" insol_time=hours_sun glob_rad=total_sun
r.mapcalc "zeros = if(dem_10m>0,0,null())"
#r.sun elevin=dem_10m aspin=zeros slopein=zeros day="1" step="0.05" dist="1" glob_rad=flat_total_sun  
#r.mapcalc "S_i=total_sun/flat_total_sun"
echo "Elapsed time: $(($(date +%s)-$starttime))"
#loop over days on temp
r.sun -s elevin=dem_10m aspin=aspect slopein=slope day="${day}" step="${stepsize}" dist="1" insol_time=hours_sun glob_rad=total_sun
echo "Elapsed time: $(($(date +%s)-$starttime))"
r.sun elevin=dem_10m aspin=zeros slopein=zeros day="${day}" step="${stepsize}" dist="1" glob_rad=flat_total_sun
echo "Elapsed time: $(($(date +%s)-$starttime))"
r.out.gdal -c createopt="TFW=YES,COMPRESS=LZW" input=total_sun output=$outputts
r.out.gdal -c createopt="TFW=YES,COMPRESS=LZW" input=flat_total_sun output=$outputfts
