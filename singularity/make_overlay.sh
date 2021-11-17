singularity exec py4cytoscape.sif bash -c " \
mkdir -p overlay_tmp/upper overlay_tmp/work && \
dd if=/dev/zero of=$FILE count=$COUNT bs=$BS && \
mkfs.ext3 -d overlay_tmp $FILE && \
rm -rf overlay_tmp \
"


