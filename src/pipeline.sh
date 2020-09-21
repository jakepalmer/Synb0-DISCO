#!/bin/bash

# Set path for executable
export PATH=$PATH:/extra
export TMPDIR=/extra/_tmp

# Set up freesurfer
# export FREESURFER_HOME=/extra/freesurfer
# source $FREESURFER_HOME/SetUpFreeSurfer.sh

# Set up FSL
# . /extra/fsl/etc/fslconf/fsl.sh
export PATH=$PATH:/opt/fsl-5.0.10/bin
export FSLDIR=/opt/fsl-5.0.10

# Set up ANTS
# export ANTSPATH=/extra/ANTS/bin/ants/bin/
# export PATH=$PATH:$ANTSPATH:/extra/ANTS/ANTs/Scripts

# Set up pytorch
# source /extra/pytorch/bin/activate

# Check input
if [[ ! -f /extra/INPUTS/b0.nii.gz ]]; then
	echo ERROR: Could not find required input /extra/INPUTS/b0.nii.gz
	exit 
elif [[ ! -f /extra/INPUTS/T1.nii.gz ]]; then
	echo ERROR: Could not find required input /extra/INPUTS/T1.nii.gz
	exit
elif [[ ! -f /extra/INPUTS/acqparams.txt ]]; then
	echo ERROR: Could not find required input /extra/INPUTS/acqparams.txt
	exit
fi

# Prepare input
/extra/data_processing/prepare_input.sh /extra/INPUTS/b0.nii.gz /extra/INPUTS/T1.nii.gz /extra/atlases/mni_icbm152_t1_tal_nlin_asym_09c.nii.gz /extra/atlases/mni_icbm152_t1_tal_nlin_asym_09c_2_5.nii.gz /extra/OUTPUTS

# Run inference
NUM_FOLDS=5
for i in $(seq 1 $NUM_FOLDS);
  do echo Performing inference on FOLD: "$i"
  python3.6 /extra/src/inference.py /extra/OUTPUTS/T1_norm_lin_atlas_2_5.nii.gz /extra/OUTPUTS/b0_d_lin_atlas_2_5.nii.gz /extra/OUTPUTS/b0_u_lin_atlas_2_5_FOLD_"$i".nii.gz /extra/src/train_lin/num_fold_"$i"_total_folds_"$NUM_FOLDS"_seed_1_num_epochs_100_lr_0.0001_betas_\(0.9\,\ 0.999\)_weight_decay_1e-05_num_epoch_*.pth
done

# Take mean
echo Taking ensemble average
fslmerge -t /extra/OUTPUTS/b0_u_lin_atlas_2_5_merged.nii.gz /extra/OUTPUTS/b0_u_lin_atlas_2_5_FOLD_*.nii.gz
fslmaths /extra/OUTPUTS/b0_u_lin_atlas_2_5_merged.nii.gz -Tmean /extra/OUTPUTS/b0_u_lin_atlas_2_5.nii.gz

# Apply inverse xform to undistorted b0
echo Applying inverse xform to undistorted b0
antsApplyTransforms -d 3 -i /extra/OUTPUTS/b0_u_lin_atlas_2_5.nii.gz -r /extra/INPUTS/b0.nii.gz -n BSpline -t [/extra/OUTPUTS/epi_reg_d_ANTS.txt,1] -t [/extra/OUTPUTS/ANTS0GenericAffine.mat,1] -o /extra/OUTPUTS/b0_u.nii.gz

# Smooth image
echo Applying slight smoothing to distorted b0
fslmaths /extra/INPUTS/b0.nii.gz -s 1.15 /extra/OUTPUTS/b0_d_smooth.nii.gz

# Merge results and run through topup
echo Running topup
fslmerge -t /extra/OUTPUTS/b0_all.nii.gz /extra/OUTPUTS/b0_d_smooth.nii.gz /extra/OUTPUTS/b0_u.nii.gz
topup -v --imain=/extra/OUTPUTS/b0_all.nii.gz --datain=/extra/INPUTS/acqparams.txt --config=b02b0.cnf --iout=/extra/OUTPUTS/b0_all_topup.nii.gz --out=/extra/OUTPUTS/topup --subsamp=1,1,1,1,1,1,1,1,1 --miter=10,10,10,10,10,20,20,30,30 --lambda=0.00033,0.000067,0.0000067,0.000001,0.00000033,0.000000033,0.0000000033,0.000000000033,0.00000000000067

# Done
echo FINISHED!!!
