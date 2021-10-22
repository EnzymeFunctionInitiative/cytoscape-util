#!/home/n-z/noberg/miniconda2/bin/python
#TODO: fix the above

import sys
import os
#lib_dir = os.path.dirname(os.path.realpath(__file__)) + "/../lib"
#sys.path.append(lib_dir)

import util
from cyimage import CyImage



args = util.get_arguments()

cyimage = CyImage(verbose=args.verbose, port=args.port)
is_connected = cyimage.wait_for_init()

if not is_connected:
    print("Failed to connect to Cytoscape; exceeded number of tries, or other error")
    quit()



cyimage.load_and_style(ssn_path=args.ssn, do_style=True)

cyimage.export_image(image_path=args.image_base)





