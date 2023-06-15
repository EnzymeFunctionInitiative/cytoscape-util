#!python

import sys
import os
#lib_dir = os.path.dirname(os.path.realpath(__file__)) + "/../lib"
#sys.path.append(lib_dir)

import util
from cyimage import CyImage



args = util.get_arguments()

host = '127.0.0.1'
if args.host:
    host = args.host
sandbox_id = '0'
if args.sandbox_id:
    sandbox_id = args.sandbox_id

cyimage = CyImage(verbose=args.verbose, host=host, port=args.port, sandbox_id=sandbox_id)
is_connected = cyimage.wait_for_init()

if not is_connected:
    print("Failed to connect to Cytoscape; exceeded number of tries, or other error")
    sys.exit()

if args.quit_only:
    cyimage.quit()
    sys.exit()

do_style = False
if args.style:
    do_style = True

cyimage.load_and_style(ssn_path=args.ssn, do_style=do_style)

default_zoom = 100
zoom = default_zoom
if args.zoom:
    try:
        zoom = float(args.zoom)
    except:
        zoom = default_zoom

cyimage.export_image(image_path=args.image_base, zoom=zoom)

if not args.dont_quit:
    cyimage.quit()


