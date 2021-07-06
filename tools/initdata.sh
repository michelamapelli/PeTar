#!/bin/bash
until [[ `echo x$1` == 'x' ]]
do
    case $1 in
	-h) shift;
	    echo 'PeTar initial data file generator, convert a data file to petar input'
	    echo 'Usage: petar.init [options] [input data filename]';
	    echo '   The first 7 columns in the data file should be mass, position[3], velocity[3]. Each line contain the data of one particle.';
	    echo '   If N binary exists, they should locate at the first 2*N lines. Two components must be next to each others.'
	    echo 'Options:';
	    echo '  -f: output file (petar input data) name (default: intput file name + ".input")';
	    echo '  -i: skip the first given number of rows in the input data file (default: 0)';
	    echo '  -s: add stellar evolution columns:  base | bse | no (default: no)';
	    echo '  -m: the mass scaling factor from the input data unit to [Msun], used for stellar evolution (BSE based): mass[input unit]*m_scale=mass[Msun] (default: 1.0)';
	    echo '  -r: the radius scaling factor from the input data unit to [pc] (default: 1.0)';
	    echo '  -v: the velocity scaling factor from the input data unit to [pc/myr]. If the string "kms2pcmyr" is given, convert velocity unit from [km/s] to [pc/myr] (default: 1.0)';
	    echo '  -u: calculate the velocity scaling factor based on -m and -r, then convert the data unit to (Msun, pc, pc/myr). The input data should use the Henon unit (total mass=1, G=1)';
	    echo '  -c: add position and velocity offsets to all particles [in Input unit]. The units will be transferred based on the scaling options (-r,-v,-u). Values are separated by "," (0,0,0,0,0,0)';
	    echo '  -t: add an external potential column and the center-of-the-mass offsets in header. This is required when the external potential (e.g. Galpy) is switched on (--with-external in configure)'
	    echo '  -R: the initial stellar radius for "-s base" mode (default: 0.0)';
	    echo "PS: 1) When stellar evolution (e.g. BSE) is used, be careful for the scaling factor. It is recommended to use the unit set [Msun, pc, pc/myr] for the input data. If velocities use the unit of km/s, use '-v kms2pcmyr' to convert the unit to pc/myr."
	    echo "    2) If the input data are in the Henon unit, given '-m' and '-r', the option '-u' can calculate the correct velocity scaling factor."
	    echo '    3) A petar-style input file generated by this tool can also be used as a data file, in order to change scaling factors or stellar evolution columns.'
	    echo "       In this case, '-i 1' should be used together to remove the header line. The data in the BINARY format cannot be read."
	    echo "    4) Be careful, this tool does not work for a petar snapshot from the middle of a simulation, where binary positions may already be changed (not locate at the begining)."
	    echo "    5) If an external potential (e.g. Galpy) is used,  the option '-c' defines the center-of-the-mass position and velocity in the galactic coordinate system."
	    exit;;
	-f) shift; fout=$1; shift;;
	-i) shift; igline=$1; shift;;
	-s) shift; seflag=$1; shift;;
	-m) shift; mscale=$1; convert=1; shift;;
	-r) shift; rscale=$1; convert=1; shift;;
	-v) shift; vscale=$1; convert=1; shift;;
	-u) convert=2; shift;;
	-R) shift; radius=$1; shift;;
	-c) shift; cm=$1; shift;;
	-t) extflag='yes'; shift;;
	*) fname=$1;shift;;
    esac
done

if [ ! -e $fname ] | [ -z $fname ] ; then
    echo 'Error, file name not provided' 
    exit
fi
[ -z $fout ] && fout=$fname.input
[ -z $igline ] && igline=0
[ -z $seflag ] && seflag='no'
[ -z $extflag ] && extflag='no'
[ -z $rscale ] && rscale=1.0
[ -z $mscale ] && mscale=1.0
[ -z $vscale ] && vscale=1.0
[ -z $radius ] && radius=0.0
[ -z $convert ] && convert=0
[ -z $cm ] && cm='none'

echo 'Transfer "'$fname'" to PeTar input data file "'$fout'"'
echo 'Skip rows: '$igline
echo 'Add stellar evolution columns: '$seflag

n=`wc -l $fname|cut -d' ' -f1`
n=`expr $n - $igline`

cm_array=''
if [[ $cm != 'none' ]]; then
    cm_array=(`echo $cm|sed 's/,/ /g'`)
    echo 'cm offset: pos: '${cm_array[0]}' '${cm_array[1]}' '${cm_array[2]}' vel: '${cm_array[3]}' '${cm_array[4]}' '${cm_array[5]}
#    awk -v ig=$igline -v x=${cm_array[0]} -v y=${cm_array[1]} -v z=${cm_array[2]} -v vx=${cm_array[3]} -v vy=${cm_array[4]} -v vz=${cm_array[5]} '{OFMT="%.15g"; if(NR>ig) print $1,$2+x,$3+y,$4+z,$5+vx,$6+vy,$7+vz}' $fname > $fname.off__
#else
#    awk -v ig=$igline '{if(NR>ig) print $1,$2,$3,$4,$5,$6,$7}' $fname >$fname.off__
fi

# first, scale data
if [ $convert == 2 ]; then
    G=0.00449830997959438
    echo 'Convert Henon unit to Astronomical unit: distance scale: '$rscale';  mass scale: '$mscale';  velocity scale: sqrt(G*ms/rs);  G='$G
    awk -v ig=$igline -v rs=$rscale -v G=$G -v ms=$mscale 'BEGIN{vs=sqrt(G*ms/rs)} {OFMT="%.15g"; if (NR>ig) print $1*ms,$2*rs,$3*rs,$4*rs,$5*vs,$6*vs,$7*vs}' $fname>$fout.scale__
    if [[ x$cm_array != x ]]; then
	cm_array_scale=(`echo ${cm_array[@]} | awk -v rs=$rscale -v G=$G -v ms=$mscale 'BEGIN{vs=sqrt(G*ms/rs)} {OFMT="%.15g"; print $1*rs,$2*rs,$3*rs,$4*vs,$5*vs,$6*vs}'`)
	cm_array=(${cm_array_scale[@]})
	echo 'cm offset (scaled): pos: '${cm_array[0]}' '${cm_array[1]}' '${cm_array[2]}' vel: '${cm_array[3]}' '${cm_array[4]}' '${cm_array[5]}
    fi
    mscale=1.0 # use for scaling from Petar unit to stellar evolution unit, since now two units are same, set mscale to 1.0
elif [ $convert == 1 ]; then
    [ $vscale == 'kms2pcmyr' ] && vscale=1.022712165045695
    echo 'Unit convert: distance scale: '$rscale';  mass scale: '$mscale';  velocity scale: '$vscale
    awk -v ig=$igline -v rs=$rscale -v vs=$vscale -v ms=$mscale '{OFMT="%.15g"; if (NR>ig) print $1*ms,$2*rs,$3*rs,$4*rs,$5*vs,$6*vs,$7*vs}' $fname >$fout.scale__
    mscale=1.0 # use for scaling from Petar unit to stellar evolution unit, since now two units are same, set mscale to 1.0
    if [[ x$cm_array != x ]]; then
	cm_array_scale=(`echo ${cm_array[@]} | awk -v rs=$rscale -v vs=$vscale '{OFMT="%.15g"; print $1*rs,$2*rs,$3*rs,$4*vs,$5*vs,$6*vs}'`)
	cm_array=(${cm_array_scale[@]})
	echo 'cm offset (scaled): pos: '${cm_array[0]}' '${cm_array[1]}' '${cm_array[2]}' vel: '${cm_array[3]}' '${cm_array[4]}' '${cm_array[5]}
    fi
else
    awk -v ig=$igline '{if(NR>ig) print $LINE}' $fname >$fout.scale__
fi
#rm -f $fname.off__

#         m,  r,        v,        bdata
base_col='$1, $2,$3,$4, $5,$6,$7, 0,' 
#         rs, id,    mbk, stat, rin, rout, acc_s, pot_t, pot_s, 
soft_col='0,  NR-ig, 0,   0,    0,   0,    0,0,0, 0,     0,'
if [[ $extflag == 'yes' ]]; then
    echo 'Add the external potential column (pot_ext)'
    soft_col=$soft_col' 0,' # pot_ext
    # header
    if [[ x$cm_array != x ]]; then
	echo '0 '$n' 0 '${cm_array[@]} >$fout
    else
	echo '0 '$n' 0 0.0 0.0 0.0 0.0 0.0 0.0' >$fout
    fi
else
    #header
    echo '0 '$n' 0' >$fout
fi
soft_col=$soft_col' 0' # nb

if [[ $seflag != 'no' ]]; then
    #       radius,  dm, t_record, t_interrupt
    se_col=$radius', 0,  0,        0,' 

    if [[ $seflag == 'base' ]]; then
	echo "Interrupt mode: base'
	echo 'Stellar radius (0): " $radius
	awk '{OFMT="%.15g"; print '"$base_col$se_col$soft_col"'}' $fout.scale__ >>$fout
    elif [[ "$seflag" == *"bse"* ]]; then
	#       type, m0,  m,     rad, mc,  rc,  spin, epoch, time, lum
	bse_col='1, $1*ms, $1*ms, 0.0, 0.0, 0.0, 0.0,  0.0,   0.0,  0.0,'

	echo 'Interrupt mode: '$seflag
	echo 'mass scale from PeTar unit (PT) to Msun (m[Msun] = m[PT]*mscale): ' $mscale
	awk -v ms=$mscale  '{OFMT="%.15g"; print '"$base_col$se_col$bse_col$soft_col"'}' $fout.scale__ >>$fout
    else
	echo 'Error: unknown option for stellar evolution: '$seflag
    fi
else
    awk '{OFMT="%.15g"; print '"$base_col$soft_col"'}' $fout.scale__ >>$fout
fi
rm -f $fout.scale__
