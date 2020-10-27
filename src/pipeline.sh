#!/bin/bash

# # Set path for executable
# export PATH=$PATH:/extra

# # Set up freesurfer
# export FREESURFER_HOME=/extra/freesurfer
# source $FREESURFER_HOME/SetUpFreeSurfer.sh

# # Set up FSL
# . /extra/fsl/etc/fslconf/fsl.sh
# export PATH=$PATH:/extra/fsl/bin
# export FSLDIR=/extra/fsl

# # Set up ANTS
# export ANTSPATH=/extra/ANTS/bin/ants/bin/
# export PATH=$PATH:$ANTSPATH:/extra/ANTS/ANTs/Scripts

# # Set up pytorch
# source /extra/pytorch/bin/activate

# Prepare input
/opt/Synb0-DISCO/data_processing/prepare_input.sh /data/$1/b0.nii.gz /data/$1/T1.nii.gz /opt/Synb0-DISCO/atlases/mni_icbm152_t1_tal_nlin_asym_09c.nii.gz /opt/Synb0-DISCO/atlases/mni_icbm152_t1_tal_nlin_asym_09c_2_5.nii.gz /data/$1

# Run inference
NUM_FOLDS=5
for i in $(seq 1 $NUM_FOLDS);
  do echo Performing inference on FOLD: "$i"
  python3.6 /opt/Synb0-DISCO/src/inference.py /opt/Synb0-DISCO/$1/T1_norm_lin_atlas_2_5.nii.gz /opt/Synb0-DISCO/$1/b0_d_lin_atlas_2_5.nii.gz /opt/Synb0-DISCO/$1/b0_u_lin_atlas_2_5_FOLD_"$i".nii.gz /opt/Synb0-DISCO/src/train_lin/num_fold_"$i"_total_folds_"$NUM_FOLDS"_seed_1_num_epochs_100_lr_0.0001_betas_\(0.9\,\ 0.999\)_weight_decay_1e-05_num_epoch_*.pth
done

# Take mean
echo Taking ensemble average
fslmerge -t /data/$1/b0_u_lin_atlas_2_5_merged.nii.gz /data/$1/b0_u_lin_atlas_2_5_FOLD_*.nii.gz
fslmaths /data/$1/b0_u_lin_atlas_2_5_merged.nii.gz -Tmean /data/$1/b0_u_lin_atlas_2_5.nii.gz

# Apply inverse xform to undistorted b0
echo Applying inverse xform to undistorted b0
antsApplyTransforms -d 3 -i /data/$1/b0_u_lin_atlas_2_5.nii.gz -r /data/$1/b0.nii.gz -n BSpline -t [/data/$1/epi_reg_d_ANTS.txt,1] -t [/data/$1/ANTS0GenericAffine.mat,1] -o /data/$1/b0_u.nii.gz

# Smooth image
echo Applying slight smoothing to distorted b0
fslmaths /data/$1/b0.nii.gz -s 1.15 /data/$1/b0_d_smooth.nii.gz

# Merge results and run through topup
echo Running topup
fslmerge -t /data/$1/b0_all.nii.gz /data/$1/b0_d_smooth.nii.gz /data/$1/b0_u.nii.gz
topup -v --imain=/data/$1/b0_all.nii.gz --datain=/data/$1/acqparams.txt --config=b02b0.cnf --iout=/data/$1/b0_all_topup.nii.gz --out=/data/$1/topup --subsamp=1,1,1,1,1,1,1,1,1 --miter=10,10,10,10,10,20,20,30,30 --lambda=0.00033,0.000067,0.0000067,0.000001,0.00000033,0.000000033,0.0000000033,0.000000000033,0.00000000000067

# Done
echo FINISHED!!!
