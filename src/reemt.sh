#!/bin/bash
#Configuration
# if [ -d ${HOME}/grassdata ]; then
# rm -rf "${HOME}/grassdata"
# fi
# Save the original directory 
START_DIR=${PWD}
TEMP_DIR='tmp_${RANDOM}_$((date))'
cd ${HOME}
mkdir grassdata
cd /grassdata
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
cd
#WIND and DEFAULT_WIND
if [ -e ${HOME}/.grassrc ]; then
rm -f ${HOME}/.grassrc
fi
echo "GISDBASE: ${HOME}/grassdata" >${HOME}/.grassrc
echo "LOCATION_NAME: ${TEMP_DIR}" >> ${HOME}/.grassrc
echo "MAPSET: PERMANENT" >> ${HOME}/.grassrc
echo "GRASS_GUI: text" >> ${HOME}/.grassrc

# Return to the original directory
cd $START_DIR

#Parameter setting
stepsize=0.5
interval=1
starttime=$(date +%s)
day=$7
#set up envvar for UAHPC only
export GISBASE=/gsfs1/xdisk/nirav/grass/grass-6.4.4
export PATH="$GISBASE/bin:$GISBASE/scripts:$PATH"
export LD_LIBRARY_PATH="$GISBASE/lib:/usr/lib:/gsfs1/xdisk/nirav/lib:$LD_LIBRARY_PATH"
export GRASS_LD_LIBRARY_PATH="$LD_LIBRARY_PATH"
export GISRC=$HOME/.grassrc
#update project info
g.proj -c proj4="+proj=lcc +lat_1=25 +lat_2=60 +lat_0=42.5 +lon_0=-100 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"
#loop head
#input
g.mremove -f "*"
r.in.gdal input=$1 output=dem_10m
echo "Elapsed time: $(($(date +%s)-$starttime))"
shift 1 
r.in.gdal input=$1 output=tmin band=$9
echo "Elapsed time: $(($(date +%s)-$starttime))"
r.in.gdal input=$2 output=tmax band=$9
echo "Elapsed time: $(($(date +%s)-$starttime))"
r.in.gdal input=$3 output=twi
echo "Elapsed time: $(($(date +%s)-$starttime))"
r.in.gdal input=$4 output=prcp band=$9
echo "Elapsed time: $(($(date +%s)-$starttime))"
r.in.gdal input=$5 output=dem_1km
echo "Elapsed time: $(($(date +%s)-$starttime))"
r.in.gdal input=$6 output=total_sun
echo "Elapsed time: $(($(date +%s)-$starttime))"
r.in.gdal input=$7 output=flat_total_sun
echo "Elapsed time: $(($(date +%s)-$starttime))"
#set region
g.region -s rast=dem_10m
#r.sun elevin=dem_10m aspin=zeros slopein=zeros day="1" step="0.05" dist="1" glob_rad=flat_total_sun
#r.mapcalc "S_i=total_sun/flat_total_sun"
r.mapcalc "a_i = twi/((max(twi)+min(twi))/2)"
r.mapcalc "c_w = 4185.5"
#r.mapcalc "NPP=0"
r.mapcalc "h_bio = 22*10^6"
echo "Elapsed time: $(($(date +%s)-$starttime))"
#loop over days on temp
eemt_tif=$8
r.mapcalc "S_i = total_sun/flat_total_sun"
r.mapcalc "tmin_loc = tmin-0.00649*(dem_10m-dem_1km)"
r.mapcalc "tmax_loc = tmax-0.00649*(dem_10m-dem_1km)"
r.mapcalc "tmin_topo = tmin_loc*(S_i-(1/S_i))"
r.mapcalc "tmax_topo = tmax_loc*(S_i-(1/S_i))"
#r.mapcalc "total_sun_joules = total_sun/(3600*hours_sun)"
#r.mapcalc "g_psy=0.001013*(101.3*((293-0.00649*dem_10m)/293)^5.26)/(0.622*2.45)"
#r.mapcalc "m_vp=0.04145*exp(0.06088*(tmax_topo+tmin_topo/2))"
#r.mapcalc "ra=(4.72*(ln(2/0.00137))2)/(1+0.536*5)"
#r.mapcalc "vp_loc=6.11*10(7.5*tmin_topo)/(237.3+tmin_topo)"
#r.mapcalc "f_tmin_topo=0.6108*exp((12.27*tmin_topo)/(tmin_topo+237.3))"
#r.mapcalc "f_tmax_topo=0.6108*exp((12.27*tmax_topo)/(tmax_topo+237.3))"
#r.mapcalc "vp_s_topo=(f_tmax_topo+f_tmin_topo)/2"
#r.mapcalc "p_a=101325*exp(9.80665*0.289644*dem_10m/(8.31447*288.15))/287.35*((tmax_topo+tmin_topo/2)273.125)"
#r.mapcalc "PET=total_sun_joules+p_a*0.001013*(vp_s_topo-vp_loc)/ra))/(2.45*(m_vp+g_psy)"
#r.mapcalc "AET=prcp*(1+PET/prcp(1(PET/prcp)2.63)(1/2.63))"
r.mapcalc "DT = ((tmax_topo+tmin_topo)/2)-273.15"
r.mapcalc "F = a_i*prcp"
r.mapcalc "npp_trad = 3000*(1+exp(1.315-0.119*(tmax_loc+tmin_loc)/2)^-1)"
r.mapcalc "NPP = npp_trad"
r.mapcalc "EEMT = F*c_w*DT+NPP*h_bio"
#output
r.out.gdal -c createopt="TFW=YES,COMPRESS=LZW" input=EEMT output=$eemt_tif
echo "Elapsed time: $(($(date +%s)-$starttime))"
g.mremove -f "*"
