#!/bin/bash

# Grass Configuration is handled in trad_eemt.sh

#Parameter setting
stepsize=0.05
interval=1
starttime=$(date +%s)
#loop head
#input

FILENAME="${9}_${RANDOM}"
# Setup temporary config files
export GISRC=${HOME}/.grassrc_${FILENAME}

if [ ! -e ${HOME}/grassdata ] ; then
	mkdir ${HOME}/grassdata
fi

if [ ! -e ${HOME}/grassdata/tmp_${FILENAME} ] ; then
	mkdir ${HOME}/grassdata/tmp_${FILENAME}
fi

if [ ! -e ${HOME}/grassdata/tmp_${FILENAME}/PERMANENT ] ; then 
	mkdir ${HOME}/grassdata/tmp_${FILENAME}/PERMANENT
fi

if [ ! -e ${HOME}/grassdata/tmp_${FILENAME}/PERMANENT/DEFAULT_WIND ] ; then 
# Set wind information
	cat > "${HOME}/grassdata/tmp_${FILENAME}/PERMANENT/DEFAULT_WIND" << __EOF__

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

	cp ${HOME}/grassdata/tmp_${FILENAME}/PERMANENT/DEFAULT_WIND ${HOME}/grassdata/tmp_${FILENAME}/PERMANENT/WIND
fi

echo "GISDBASE: ${HOME}/grassdata" >${HOME}/.grassrc_${FILENAME}
echo "LOCATION_NAME: tmp_${FILENAME}" >> ${HOME}/.grassrc_${FILENAME}
echo "MAPSET: PERMANENT" >> ${HOME}/.grassrc_${FILENAME}
echo "GRASS_GUI: text" >> ${HOME}/.grassrc_${FILENAME}

g.proj -c proj4="+proj=lcc +lat_1=25 +lat_2=60 +lat_0=42.5 +lon_0=-100 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"
g.mremove -f "*"

r.in.gdal input=$1 output=dem_10m
echo "Elapsed time: $(($(date +%s)-$starttime))"

#set region
g.region -s rast=dem_10m

shift 1

r.in.gdal input=$1 output=tmin band=$8
r.in.gdal input=$2 output=tmax band=$8
r.in.gdal input=$3 output=twi
r.in.gdal input=$4 output=prcp band=$8
r.in.gdal input=$5 output=dem_1km
r.in.gdal input=$6 output=total_sun
r.in.gdal input=$7 output=flat_total_sun
r.in.gdal input=${10} output=hours_sun
r.in.gdal input=${11} output=aspect
r.in.gdal input=${12} output=slope

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
r.mapcalc "NPP_trad = 3000*(1+exp(1.315-0.119*(tmax_loc+tmin_loc)/2)^-1)"
r.mapcalc "N = sin(slope)*cos(aspect*0.0174532925)"
r.mapcalc "NPP_topo = 0.39*dem_10m+346*N-187"
r.mapcalc "E_bio = NPP_trad*h_bio"
r.mapcalc "f_tmin_loc=6.108*exp((17.27*tmin_loc)/(tmin_loc+273.3))"
r.mapcalc "f_tmax_loc=6.108*exp((17.27*tmax_loc)/(tmax_loc+273.3))"
r.mapcalc "vp_s=(f_tmax_loc+f_tmin_loc)/2"
r.mapcalc "PET=(2.1*((hours_sun/12)^2)*vp_s/((tmax_loc+tmin_loc)/2))"
r.mapcalc "E_ppt=monthly_prcp - PET"
r.mapcalc "EEMT_trad = E_ppt+E_bio"
r.mapcalc "EEMT_topo = F*c_w*DT*NPP_topo*h_bio+NPP_topo*h_bio"
#output
r.out.gdal -c createopt="TFW=YES,COMPRESS=LZW" input=EEMT_trad output="trad_${eemt}.tif"
r.out.gdal -c createopt="TFW=YES,COMPRESS=LZW" input=EEMT_topo output="topo_${eemt}.tif"
echo "Elapsed time: $(($(date +%s)-$starttime))"
echo "Elapsed time: $(($(date +%s)-$starttime))"
g.mremove -f "*"

# Use $8 instead $9 because of shift @ Line 79
echo "Cleaning up temporary files...."
rm -rf ${HOME}/grassdata/tmp_${FILENAME}
rm ${HOME}/.grassrc_${FILENAME}
