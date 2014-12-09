#!/bin/bash

# Grass Configuration is handled in trad_eemt.sh

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
