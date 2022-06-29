

# Need local copy for now
#import py4cytoscape as py4

import time
import urllib.error
import requests.exceptions
import os
import os.path
import sys
import datetime
#from requests.exceptions import ConnectionError

# Need local copy of py4cytoscape for now so we can get view_create
lib_dir = os.path.dirname(os.path.realpath(__file__)) + "/../lib"
sys.path.append(lib_dir)
import py4cytoscape as py4


class CyImage:
    def __init__(self, port=8888, verbose=False):
        self.url = 'http://127.0.0.1:' + str(port) + '/v1'
        self.verbose = verbose

    def log_action(self, message):
        if self.verbose:
            dt = datetime.datetime.now()
            print(str(dt) + ": " + message)

    def wait_for_init(self):
        is_connected = False
        tries = 0
        max_tries = 10 # 200 seconds
        while not is_connected and tries < max_tries:
            try:
                self.log_action("cytoscape_ping - Checking if Cytoscape is alive")
                py4.cytoscape_ping(self.url)
                is_connected = True
            except requests.exceptions.ConnectionError as ce:
                # Cy isn't started, or is still starting
                self.log_action("Waiting 20s for Cytoscape to start")
                time.sleep(20)
            except urllib.error.HTTPError as he:
                if he.code >= 500:
                    self.log_action("Waiting 20s for the REST service to start")
                    # Wait for REST service to start up
                    time.sleep(20)
                elif he.code >= 400:
                    self.log_action("An HTTP error occurred")
                    return False
            except requests.exceptions.HTTPError as he:
                self.log_action("Waiting 20s for the REST service to start")
                # Wait for REST service to start up
                time.sleep(20)
            #except Exception as e:
            #    template = "An exception of type {0} occurred" #. Arguments:\n{1!r}"
            #    message = template.format(type(e).__name__) #, ex.args)
            #    print(message)
            #    #print(e)
            tries = tries + 1

        if tries >= max_tries:
            self.log_action("Too many attempts to connect")
            return False
        
        self.log_action("Good to go")
        
        return True


    def load_and_style(self, ssn_path, do_style=False):
        retval = self.load_ssn(ssn_path)
        # As of 11/3/2021 there is a bug in Cytoscape (at least 3.9.0 and previous) that returns false
        # for XGMML files that are large, even though they are successfully loaded in Cytoscape.
        # For now we are not checking this.
        #if not retval:
        #    return False

        retval = self.create_view()
        if not retval:
            return False

        if do_style:
            retval = self.style()
            if not retval:
                return False

        return True


    def export_image(self, image_path, zoom):

        retval = self.layout()
        if not retval:
            return False

        retval = self.export_image_api(image_path, zoom)
        if not retval:
            return False


    # Private
    def layout(self):
        try:
            self.log_action("layout_network Performing layout")
            py4.layout_network(layout_name="force-directed", base_url=self.url)
            self.log_action("Succesfully performed layout")
        except py4.CyError as ce:
            self.log_action("Failed to perform layout: " + repr(ce))
            return False

        try:
            self.log_action("fit_content - Fitting content to window")
            py4.fit_content(base_url=self.url)
            self.log_action("Successfully fit content")
        except py4.CyError as ce:
            self.log_action("Failed to fit content: " + repr(ce))
            return False

        return True


    # Private
    def style(self):
        try:
            self.log_action("Applying default styles")
            #defaults = {"NODE_SHAPE": "ELLIPSE", "NODE_SIZE": 10, 
            node_ids = list(py4.get_table_columns(columns='name', base_url=self.url).index)
            py4.set_node_label_bypass(node_ids, "", base_url=self.url)
            py4.set_node_border_width_default(new_width=0, base_url=self.url)
            py4.set_node_label_default(new_label="", base_url=self.url)
            #py4.clear_node_property_bypass(node_ids, "NODE_LABEL", base_url=self.url)
            py4.set_node_shape_default(new_shape="ELLIPSE", base_url=self.url)
            py4.set_node_size_default(new_size=10, base_url=self.url)
            py4.set_edge_line_width_default(new_width=1, base_url=self.url)
            py4.set_edge_color_default(new_color="#CCCCCC", base_url=self.url)
            py4.set_edge_line_style_default(new_line_style="SOLID", base_url=self.url)
            self.log_action("Done applying default styles")
        except py4.CyError as ce:
            self.log_action("Failed to apply default styles: " + repr(ce))
            return False

        try:
            self.log_action("map_visual_property - Creating node fill color passthrough mapping")
            py4.map_visual_property(visual_prop="node fill color", table_column="node.fillColor", mapping_type="p", base_url=self.url)
            self.log_action("Done creating node fill color mapping")
        except py4.CyError as ce:
            self.log_action("Failed to create node fill color mapping: " + repr(ce))
            return False

        return True


    # Private
    def create_view(self):
        net_id = 0
        try:
            self.log_action("get_network_suid - Getting network SUID")
            net_id = py4.get_network_suid(base_url=self.url)
            self.log_action("Successfully found SUID " + str(net_id))
        except:
            self.log_action("Failed to find network SUID")
            return False

        need_create = False
        try:
            self.log_action("get_network_views - Checking for view")
            views = py4.get_network_views(network=net_id, base_url=self.url)
            if len(views) == 0:
                self.log_action("View is needed")
                need_create = True
            else:
                self.log_action("View already created")
                need_create = False
        except:
            need_create = True

        if need_create:
            try:
                self.log_action("create_view - Creating view view")
                py4.create_view(network=net_id, base_url=self.url)
                self.log_action("Successfully created view")
            except:
                self.log_action("Failed to create view")
            return False
        return True


    # Private
    def load_ssn(self, ssn_path):
        try:
            self.log_action("impoprt_network_from_file - Trying to load network " + ssn_path)
            py4.import_network_from_file(base_url=self.url, file=ssn_path)
            self.log_action("Successfully imported network")
        except py4.CyError as ce:
            self.log_action("Failed to import network from file " + ssn_path + "; does file exist?: " + repr(ce))
            return False
        return True


    # Private
    def export_image_api(self, image_path, the_zoom):
        try:
            self.log_action("toggle_graphics_details")
            if os.path.exists(image_path):
                self.log_action("Removing " + image_path + " first")
                os.remove(image_path)
            py4.toggle_graphics_details(base_url=self.url)
            self.log_action("export_image - Trying to export to " + image_path + " with zoom " + str(the_zoom))
            py4.export_image(filename=image_path, type='PNG', units='pixels', height=1600, width=2000, zoom=the_zoom, base_url=self.url)
            #py4.export_image(filename=image_path, type='PNG', units='pixels', height=1600, width=2000, zoom=20, base_url=self.url)
            self.log_action("Succesfully exported image")
        except py4.CyError as ce:
            self.log_action("Failed to export image to " + image_path + ": " + repr(ce))
            return False
        return True

    def quit(self):
        try:
            self.log_action("command_quit - Quitting Cytoscape")
            py4.command_quit(base_url=self.url)
            self.log_action("Done quitting")
        except py4.CyError as ce:
            self.log_action("Failed to quit: " + repr(ce))
            return False
        return True


