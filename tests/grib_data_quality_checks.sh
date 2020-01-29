#!/bin/sh
# (C) Copyright 2005- ECMWF.
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
#
# In applying this licence, ECMWF does not waive the privileges and immunities granted to it by
# virtue of its status as an intergovernmental organisation nor does it submit to any jurisdiction.
#

. ./include.sh
set -u
# ---------------------------------------------------------
# Tests for data quality checks
# ---------------------------------------------------------
label="grib_data_quality"
tempOut=temp.1.${label}.out
temp2=temp.2.${label}.out
tempErr=temp.${label}.err
tempGrib1=temp.${label}.grib1
tempGrib2=temp.${label}.grib2

sample_g1=$ECCODES_SAMPLES_PATH/GRIB1.tmpl
sample_g2=$ECCODES_SAMPLES_PATH/GRIB2.tmpl

# Start with clean environment
unset ECCODES_GRIB_DATA_QUALITY_CHECKS
unset ECCODES_EXTRA_DEFINITION_PATH


input1=${data_dir}/reduced_gaussian_surface.grib1
input2=${data_dir}/reduced_gaussian_surface.grib2
grib_check_key_equals $input1 paramId 167
grib_check_key_equals $input2 paramId 167

echo "Data quality checks disabled. Create huge values for temperature..."
# --------------------------------------------------------------------------
${tools_dir}/grib_set -s scaleValuesBy=100 $input1 $tempOut
${tools_dir}/grib_set -s scaleValuesBy=100 $input2 $tempOut

echo "Data quality checks enabled. Repacking should fail..."
# -----------------------------------------------------------
export ECCODES_GRIB_DATA_QUALITY_CHECKS=1
set +e
${tools_dir}/grib_copy -r $tempOut /dev/null  2>$tempErr
status=$?
set -e
[ $status -ne 0 ]
grep -q 'more than the allowable limit' $tempErr

echo "Data quality checks enabled but only as a warning. Repacking should pass..."
# --------------------------------------------------------------------------------
export ECCODES_GRIB_DATA_QUALITY_CHECKS=2
${tools_dir}/grib_copy -r $tempOut /dev/null  2>$tempErr
grep -q 'more than the allowable limit' $tempErr


echo "Data quality checks enabled. Scaling should fail..."
# --------------------------------------------------------
export ECCODES_GRIB_DATA_QUALITY_CHECKS=1
set +e
${tools_dir}/grib_set -s scaleValuesBy=100 $input1 $tempOut 2>$tempErr
status=$?
set -e
[ $status -ne 0 ]
grep -q 'GRIB1 simple packing: unable to set values' $tempErr
grep -q 'allowable limit' $tempErr

set +e
${tools_dir}/grib_set -s scaleValuesBy=100 $input2 $tempOut 2>$tempErr
status=$?
set -e
[ $status -ne 0 ]
grep -q 'GRIB2 simple packing: unable to set values' $tempErr
grep -q 'allowable limit' $tempErr


echo "Test limits which are doubles..."
# -------------------------------------
pid=151131 # has limits -3.5 and +3.5
${tools_dir}/grib_set -s paramId=$pid $input1 $tempGrib1
${tools_dir}/grib_set -s paramId=$pid $input2 $tempGrib2
minval1=`${tools_dir}/grib_get -p param_value_min $tempGrib1`
maxval1=`${tools_dir}/grib_get -p param_value_max $tempGrib1`
minval2=`${tools_dir}/grib_get -p param_value_min $tempGrib2`
maxval2=`${tools_dir}/grib_get -p param_value_max $tempGrib2`
[ "$minval1" = "-3.5" ]
[ "$maxval1" = "3.5"  ]
[ "$minval2" = "-3.5" ]
[ "$maxval2" = "3.5"  ]

set +e
${tools_dir}/grib_set -s scaleValuesBy=1.1 $tempGrib1 $tempOut 2>$tempErr
stat1=$?
${tools_dir}/grib_set -s scaleValuesBy=1.1 $tempGrib2 $tempOut 2>$tempErr
stat2=$?
set -e
[ $stat1 -ne 0 ]
[ $stat2 -ne 0 ]


echo "Test close to the limit..."
# ---------------------------------
${tools_dir}/grib_set -s paramId=$pid $sample_g2 $tempGrib2
${tools_dir}/grib_set -s scaleValuesBy=3 $tempGrib2 $tempOut # OK
set +e
${tools_dir}/grib_set -s scaleValuesBy=3.6 $tempGrib2 $tempOut
set -e
[ $status -ne 0 ]

${tools_dir}/grib_set -s edition=1 $tempGrib2 $tempGrib1
${tools_dir}/grib_set -s scaleValuesBy=-3 $tempGrib1 $tempOut # OK
set +e
${tools_dir}/grib_set -s scaleValuesBy=-3.55 $tempGrib1 $tempOut
set -e
[ $status -ne 0 ]



echo "Override the defaults..."
# ------------------------------
tempDir=tempdir.$label
rm -rf $tempDir
mkdir -p $tempDir
# Set a large limit for temperature
cat > $tempDir/param_limits.def <<EOF
 constant default_min_val = -1e9 : long_type, hidden;
 constant default_max_val = +1e9 : long_type, hidden;
 concept param_value_min(default_min_val) {
    0  = { paramId=167; }
 } : long_type, hidden;
 concept param_value_max(default_max_val) {
    40000 = { paramId=167; }
 } : long_type, hidden;
EOF

# Command should succeed
export ECCODES_GRIB_DATA_QUALITY_CHECKS=1
export ECCODES_EXTRA_DEFINITION_PATH=$test_dir/$tempDir
${tools_dir}/grib_set -s scaleValuesBy=100 $input1 $tempOut



# Clean up
rm -rf $tempDir
rm -f $tempOut $tempErr $tempGrib1 $tempGrib2