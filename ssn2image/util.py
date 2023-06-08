
import argparse

def get_arguments():
    parser = argparse.ArgumentParser(description="Arguments for ssn2image.py")
    parser.add_argument("--ssn", required=False, help="Full path to input SSN")
    parser.add_argument("--image-base", required=False, help="Full path to output image base; _sm and _lg suffixes will be added")
    parser.add_argument("--port", default=8888, help="Port to connect to Cytoscape (optional)")
    parser.add_argument("--zoom", default=100, help="Image export zoom")
    parser.add_argument("--host", default="127.0.0.1", help="IP address of Cytoscape host")
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--quit", action="store_true")
    parser.add_argument("--style", action="store_true")

    args = parser.parse_args()

    if not args.quit and (args.ssn is None or args.image_base is None):
        parser.error("--ssn and --image-base are required args.")
    
    return args

