#!/bin/bash

# Set a temporary configuration file
export GISRC=${HOME}/.grassrc_$2

if [ ! -e ${HOME}/grassdata ] ; then
	mkdir ${HOME}/grassdata
fi

if [ ! -e ${HOME}/grassdata/tmp_$2 ] ; then
	mkdir ${HOME}/grassdata/tmp_$2
fi

if [ ! -e ${HOME}/grassdata/tmp_$2/PERMANENT ] ; then 
	mkdir ${HOME}/grassdata/tmp_$2/PERMANENT
fi

if [ ! -e ${HOME}/grassdata/tmp_$2/PERMANENT/DEFAULT_WIND ] ; then 
# Set wind information
	cat > "${HOME}/grassdata/tmp_$2/PERMANENT/DEFAULT_WIND" << __EOF__

	proj: 99
	zone: 0
	north: 1
	south: 0
	east: 1
	west: 0
	cols: 1
	rows: 1
	e-w resol: 1
	n-s resol: 1
	top: 1.000000000000000
	bottom: 0.000000000000000
	cols3: 1
	rows3: 1
	depths: 1
	e-w resol3: 1
	n-s resol3: 1
	t-b resol: 1
__EOF__

	cp ${HOME}/grassdata/DEFAULT/PERMANENT/DEFAULT_WIND ${HOME}/grassdata/DEFAULT/PERMANENT/WIND
fi
 
echo "GISDBASE: ${HOME}/grassdata" >${HOME}/.grassrc_$2
echo "LOCATION_NAME: tmp_$2" >> ${HOME}/.grassrc_$2
echo "MAPSET: PERMANENT" >> ${HOME}/.grassrc_$2
echo "GRASS_GUI: text" >> ${HOME}/.grassrc_$2

#Parameter setting
stepsize=0.05
interval=1
starttime=$(date +%s)
day=$2
outputts=$3
outputfts=$4

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

echo "Cleaning up temporary files...."
rm -rf ${HOME}/grassdata/temp_$2
rm ${HOME}/.grassrc_$2