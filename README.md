# cytoscape-util

1. Build images

    mkdir sif-builds

    sudo singularity build sif-builds/py4cytoscape.sif cytoscape-util/singularity/py4cytoscape.def

    sudo singularity build sif-builds/cytoscape.sif cytoscape-util/singularity/cytoscape.def

2. Eventually use batch_proc to have a server that generates jobs in batches.

