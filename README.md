# cytoscape-util

1. Build images

    mkdir sif-builds

    sudo singularity build sif-builds/py4cytoscape.sif cytoscape-util/singularity/py4cytoscape.def

    sudo singularity build sif-builds/cytoscape.sif cytoscape-util/singularity/cytoscape.def

2. Run cytoscape image, by starting it as a background process on a cluster node

    a. Create batch script with the following in it:

        temp_dir=/path/to/unique/temp/dir
        singularity run --bind $temp_dir:/opt/CytoscapeConfigHome /path/to/cytoscape.sif PORT_NUM
        rm -rf $temp_dir

        Memory usage formula is as follows:

            if edges > 5700000:
                ram = 150GB
            else if edges > 2500000:
                ram = 100GB
            else if edges > 975000:
                ram = 60GB
            else if edges > 500000:
                ram = 40GB
            else if edges > 100000:
                ram = 20GB
            else
                ram = 10GB

        Reserve a node with that amount of RAM.

        temp_dir is required because Cytoscape needs to write temp/cache files to a directory (i.e. the
        karaf stuff).

    b. Create a new batch script with the following in it:

        singularity run /path/to/py4cytoscape.sif /path/to/ssn.xgmml /path/to/output_image.png PORT_NUM

        PORT_NUM must match the PORT_NUM in step a.

        This should be submitted to the same node that the first script is running on.  Memory requirement is minimal.

    c. The py4cytoscape process exports an image then shuts cytoscape down, communicating through the API.
    
3. Eventually use batch_proc to have a server that generates jobs in batches.

