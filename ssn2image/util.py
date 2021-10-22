
import argparse

def get_arguments():
    parser = argparse.ArgumentParser(description="Arguments for ssn2image.py")
    parser.add_argument("--ssn", required=True, help="Full path to input SSN")
    parser.add_argument("--image-base", required=True, help="Full path to output image base; _sm and _lg suffixes will be added")
    parser.add_argument("--port", default=8888, help="Port to connect to Cytoscape (optional)")
    parser.add_argument("--verbose", action="store_true")

    args = parser.parse_args()
    
    return args

