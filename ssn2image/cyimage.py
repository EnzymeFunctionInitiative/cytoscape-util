
import py4cytoscape as py4
import time
import urllib.error
import requests.exceptions
import os
import os.path
#from requests.exceptions import ConnectionError


class CyImage:
    def __init__(self, port=8888, verbose=False):
        self.url = 'http://127.0.0.1:' + str(port) + '/v1'
        self.verbose = verbose

    def wait_for_init(self):
        is_connected = False
        tries = 0
        max_tries = 10 # 200 seconds
        while not is_connected and tries < max_tries:
            try:
                if self.verbose:
                    print("Checking if Cytoscape is alive")
                py4.cytoscape_ping(self.url)
                is_connected = True
            except requests.exceptions.ConnectionError as ce:
                # Cy isn't started, or is still starting
                if self.verbose:
                    print("Waiting 20s for Cytoscape to start")
                time.sleep(20)
            except urllib.error.HTTPError as he:
                if he.code >= 500:
                    if self.verbose:
                        print("Waiting 20s for the REST service to start")
                    # Wait for REST service to start up
                    time.sleep(20)
                elif he.code >= 400:
                    if self.verbose:
                        print("An HTTP error occurred")
                    return False
            except requests.exceptions.HTTPError as he:
                if self.verbose:
                    print("Waiting 20s for the REST service to start")
                # Wait for REST service to start up
                time.sleep(20)
            #except Exception as e:
            #    template = "An exception of type {0} occurred" #. Arguments:\n{1!r}"
            #    message = template.format(type(e).__name__) #, ex.args)
            #    print(message)
            #    #print(e)
            tries = tries + 1

        if tries >= max_tries:
            print("Too many attempts to connect")
            return False
        
        if self.verbose:
            print("Good to go")
        
        return True


    def load_and_style(self, ssn_path, do_style=False):

        retval = self.load_ssn(ssn_path)
        if not retval:
            return False

        retval = self.create_view()
        if not retval:
            return False

        if do_style:
            retval = self.style()
            if not retval:
                return False

        return True


    def export_image(self, image_path):

        retval = self.layout()
        if not retval:
            return False

        retval = self.export_image_api(image_path)
        if not retval:
            return False


    # Private
    def layout(self):
        try:
            if self.verbose:
                print("Performing layout")
            py4.layout_network(layout_name="force-directed", base_url=self.url)
            if self.verbose:
                print("Succesfully performed layout")
        except py4.CyError as ce:
            if self.verbose:
                print("Failed to perform layout")
            return False

        try:
            if self.verbose:
                print("Fitting content to window")
            py4.fit_content(base_url=self.url)
            if self.verbose:
                print("Successfully fit content")
        except py4.CyError as ce:
            if self.verbose:
                print("Failed to fit content")
            return False

        return True


    # Private
    def style(self):
        try:
            if self.verbose:
                print("Applying default styles")
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
            if self.verbose:
                print("Done applying default styles")
        except py4.CyError as ce:
            if self.verbose:
                print("Failed to apply default styles")
            return False

        try:
            if self.verbose:
                print("Creating node fill color passthrough mapping")
            py4.map_visual_property(visual_prop="node fill color", table_column="node.fillColor", mapping_type="p", base_url=self.url)
            if self.verbose:
                print("Done creating node fill color mapping")
        except py4.CyError as ce:
            if self.verbose:
                print("Failed to create node fill color mapping")
            return False

        return True


    # Private
    def create_view(self):
        #try:
        #    if self.verbose:
        #        print("Creating view")
        #    #TODO??????
        #    if self.verbose:
        #        print("Successfully created view")
        #except py4.CyError as ce:
        #    if self.verbose:
        #        print("Failed to create view")
        #    return False
        return True


    # Private
    def load_ssn(self, ssn_path):
        try:
            if self.verbose:
                print("Trying to load network " + ssn_path)
            py4.import_network_from_file(base_url=self.url, file=ssn_path)
            if self.verbose:
                print("Successfully imported network")
        except py4.CyError as ce:
            if self.verbose:
                print("Failed to import network from file " + ssn_path + "; does file exist?")
            return False
        return True


    # Private
    def export_image_api(self, image_path):
        try:
            if self.verbose:
                print("Trying to export to " + image_path)
            if os.path.exists(image_path):
                print("Removing " + image_path + " first")
                os.remove(image_path)
            py4.export_image(filename=image_path, type="PNG", units='pixels', height=1600, width=2000, base_url=self.url)
            if self.verbose:
                print("Succesfully exported image")
        except py4.CyError as ce:
            if self.verbose:
                print("Failed to export image to " + image_path)
            return False
        return True

    def quit(self):
        try:
            if self.verbose:
                print("Quitting")
            py4.command_quit(base_url=self.url)
        except py4.CyError as ce:
            if self.verbose:
                print("Failed to quit")
                return False
        return True


