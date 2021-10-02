#!/bin/bash
# ==============================================================================
# Pipeline to preprocess training data for intervertebral disc labeling.
#
# Usage: This script should be called via the associated configuration file.
#   sct_run_batch -c preprocess-data.yml
#
# Notes:
#   - This script is designed to mimic the preprocessing steps that were
#     featured in the previous vertebral disc labeling publication.
#     (https://github.com/neuropoly/vertebral-labeling-deep-learning) However,
#     until we receive confirmation from the author (Lucas Rouhier) of the
#     exact steps that were used, this script will be an approximation at best.
#   - This script was built using SCT v5.4 and ivadomed v2.7.4.
#
# Author: Joshua Newton
# ==============================================================================


# BASH SETUP
# ==============================================================================
# Uncomment for full verbose
# set -v

# Immediately exit if error
set -e
source "${SCT_DIR}/python/etc/profile.d/conda.sh"
conda activate venv_sct

# Exit if user presses CTRL+C (Linux) or CMD+C (OSX)
trap "echo Caught Keyboard Interrupt within script. Exiting now.; exit" INT

# Retrieve input params
SUBJECT=$1

# SCRIPT STARTS HERE
# ==============================================================================

cd "${PATH_DATA}/${SUBJECT}/anat/"

CONTRASTS="t1 t2"
for contrast in ${CONTRASTS}; do
  # This is the "base file name" used to prefix each output file
  FILE_IN="${SUBJECT}_${contrast^}w"  # NB: '^' is uppercase (t1 -> T1)

  # Straighten the anatomical images (to match the preprocessing sct_label_vertebrae)
  sct_deepseg_sc -i "${FILE_IN}.nii.gz" -c "${contrast}" -o "${FILE_IN}_seg.nii.gz"
  sct_straighten_spinalcord -i "${FILE_IN}.nii.gz" -s "${FILE_IN}_seg.nii.gz" \
                            -o "${FILE_IN}_straight.nii.gz"

  echo "Renaming intermediate straightening files"  # So T2 doesn't overwrite T1
  mv straight_ref.nii.gz "${FILE_IN}_straight_ref.nii.gz"
  mv warp_curve2straight.nii.gz "${FILE_IN}_warp_curve2straight.nii.gz"
  mv warp_straight2curve.nii.gz "${FILE_IN}_warp_straight2curve.nii.gz"

  # Apply the straightening to the label file, as well
  PATH_DERIVATIVES=$(readlink -f "../../derivatives/labels/${SUBJECT}/anat")
  sct_apply_transfo -i "${PATH_DERIVATIVES}/${FILE_IN}_labels-disc-manual.nii.gz" \
                    -o "${PATH_DERIVATIVES}/${FILE_IN}_straight-labels-disc-manual.nii.gz" \
                    -d "${FILE_IN}_straight.nii.gz" \
                    -w "${FILE_IN}_warp_curve2straight.nii.gz" \
                    -x label

  # Resample the data
  #  - The original study (Rouhier et al., 2019) resampled the training data to
  #    1mm isotropic.
  #  - This could be done in this script using SCT, e.g.:
  #      sct_resample -i "${FILE_IN}_straight.nii.gz" \
  #                   -o "${FILE_IN}_straightr.nii.gz" \
  #                   -mm 1x1x1 -x linear
  #      sct_resample -i "${PATH_DERIVATIVES}/${FILE_IN}_labels-disc-manual_straight.nii.gz" \
  #                   -o "${PATH_DERIVATIVES}/${FILE_IN}_labels-disc-manual_straightr.nii.gz" \
  #                  -mm 1x1x1 -x linear
  #  - However, I've chosen to do resampling using `ivadomed` instead, so that
  #    it will be consistenly applied to both the training and inference data.
  #    This is especially relevant because sct_label_vertebrae works with
  #    0.5mm isotropic by default. So, enforcing 1mm resampling on the ivadomed
  #    level guarantees that the input data will be the right resolution,
  #    regardless of what SCT chooses to do.
done




























## LUCAS" SCRIPT STARTS HERE
## ==============================================================================
## Go to results folder, where most of the outputs will be located
#cd $PATH_DATA_PROCESSED
## Copy source images and segmentations
#mkdir -p data/derivatives/labels
#cd data
#
#mkdir -p $SUBJECT/anat
#cp -r $PATH_DATA/derivatives/labels/$SUBJECT $PATH_DATA_PROCESSED/data/derivatives/labels
#
#cd $PATH_DATA_PROCESSED/data/$SUBJECT/anat/
### Setup file names
#contrast='T1 T2'
#for i in $contrast; do
#	file=${SUBJECT}_${i}w
#	if test -f $PATH_DATA/$SUBJECT/anat/${file}.nii.gz;then
#		c_args=${i/T/t}
#
#		## copy needed file (t1w and T2w other are not needed)
#		cp $PATH_DATA/$SUBJECT/anat/${file}.nii.gz ./
#		## Deepseg to get needed segmentation.
#		sct_deepseg_sc -i ${file}.nii.gz -c ${c_args}  -ofolder $PATH_DATA_PROCESSED/data/derivatives/labels/$SUBJECT/anat/
#
#		## seg file name
#		file_seg=$PATH_DATA_PROCESSED/data/derivatives/labels/$SUBJECT/anat/${SUBJECT}_${i}w_seg.nii.gz
#		label_file=$PATH_DATA_PROCESSED/data/derivatives/labels/$SUBJECT/anat/${SUBJECT}_${i}w_labels-disc-manual.nii.gz
#
#		sct_label_vertebrae -i ${file}.nii.gz -s ${file_seg} -c t2 -discfile ${label_file} -ofolder $PATH_DATA_PROCESSED/data/derivatives/labels/$SUBJECT/anat/
#
#		## Change the name to avoid overwriting files output by sct_label_vertebrae during prediction later.
#		mv $PATH_DATA_PROCESSED/data/derivatives/labels/$SUBJECT/anat/${SUBJECT}_${i}w_seg_labeled_discs.nii.gz $PATH_DATA_PROCESSED/data/derivatives/labels/$SUBJECT/anat/${SUBJECT}_${i}w_projected-gt.nii.gz
#
#		## Chage data type to int 16 for "projected_gt"
#		sct_image -i $PATH_DATA_PROCESSED/data/derivatives/labels/$SUBJECT/anat/${SUBJECT}_${i}w_projected-gt.nii.gz -type int16
#
#	fi
#done
