#!/bin/bash

# Grass Configuration is handled in trad_eemt.sh

#Parameter setting
stepsize=0.05
interval=1
starttime=$(date +%s)
day=$7
g.proj -c proj4="+proj=lcc +lat_1=25 +lat_2=60 +lat_0=42.5 +lon_0=-100 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"
#loop head
#input

# Setup temporary config files
export GISBASE=${HOME}/.grassrc_$9

if [ ! -e ${HOME}/grassdata ] ; then
	mkdir ${HOME}/grassdata
fi

if [ ! -e ${HOME}/grassdata/tmp_$9 ] ; then
	mkdir ${HOME}/grassdata/tmp_$9
fi

if [ ! -e ${HOME}/grassdata/tmp_$9/PERMANENT ] ; then 
	mkdir ${HOME}/grassdata/tmp_$9/PERMANENT
fi

if [ ! -e ${HOME}/grassdata/tmp_$9/PERMANENT/DEFAULT_WIND ] ; then 
# Set wind information
	cat > "${HOME}/grassdata/tmp_$9/PERMANENT/DEFAULT_WIND" << __EOF__

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

	cp ${HOME}/grassdata/tmp_$9/PERMANENT/DEFAULT_WIND ${HOME}/grassdata/tmp_$9/PERMANENT/WIND
fi

echo "GISDBASE: ${HOME}/grassdata" >${HOME}/.grassrc_$9
echo "LOCATION_NAME: tmp_$9" >> ${HOME}/.grassrc_$9
echo "MAPSET: PERMANENT" >> ${HOME}/.grassrc_$9
echo "GRASS_GUI: text" >> ${HOME}/.grassrc_$9


g.mremove -f "*"
r.in.gdal input=$1 output=dem_10m
echo "Elapsed time: $(($(date +%s)-$starttime))"
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
shift 1
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
eemt_tif=$9
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

# Use $8 instead $9 because of shift @ Line 79
echo "Cleaning up temporary files...."
rm -rf ${HOME}/grassdata/tmp_$8
rm ${HOME}/.grassrc_$8