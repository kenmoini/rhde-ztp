import os, json, time, yaml, requests
import datetime as dt
from flask import Flask, request, jsonify
from flask_cors import CORS, cross_origin

##############################
# Setup Flask Variables
flaskPort = os.environ.get("FLASK_RUN_PORT", 8765)
flaskHost = os.environ.get("FLASK_RUN_HOST", "0.0.0.0")
tlsCert = os.environ.get("FLASK_TLS_CERT", "")
tlsKey = os.environ.get("FLASK_TLS_KEY", "")

##############################
# Setup application variables
jobCodePath = os.environ.get("JOB_CODE_PATH", "/opt/job-codes")
aapControllerURL = os.environ.get("AAP_CONTROLLER_URL", "https://aap2-controller")
aapControllerToken = os.environ.get("AAP_CONTROLLER_TOKEN", "")
aapJobTemplateID = os.environ.get("AAP_JOB_TEMPLATE_ID", "123456")
aapInventoryID = os.environ.get("AAP_INVENTORY_ID", "123456")

##############################
# creates a Flask application
app = Flask(__name__)
CORS(app) # This will enable CORS for all routes

# Health check endpoint
@app.route("/healthz", methods = ['GET'])
def healthz():
    if request.method == 'GET':
        return "ok"

# Index endpoint
@app.route("/")
def index():
    return "Horses R Us!"

# Look up Job Codes, by MAC Address
@app.route("/api/v1/system-up", methods = ['POST'])
def listClaimedJobCodesRoute():
    if request.method == 'POST':
        macAddress = request.json["mac_address"]
        provisionedIPAddress = request.json["provisioned_ip_address"]
        default_device = request.json["default_device"]
        # Replace all colons with dashes
        macAddressDash = macAddress.replace(":", "-")
        # Lowercase the MAC Address
        macAddressDashLower = macAddressDash.lower()

        # Read in the data and extract the YAML
        jobCodeClaimFile = open(jobCodePath + "/claims/" + macAddressDashLower + ".yaml", "r")
        jobCodeClaimData = yaml.load(jobCodeClaimFile, Loader=yaml.FullLoader)
        jobCodeClaimFile.close()
        jobCode = jobCodeClaimData["job_code"]
        submittedDate = jobCodeClaimData["submitted_date"]

        # Get the Job Code File data
        jobCodeFile = open(jobCodePath + "/" + jobCode + ".yaml", "r")
        jobCodeData = yaml.load(jobCodeFile, Loader=yaml.FullLoader)
        jobCodeFile.close()
        jobCodeInfo = {}
        jobCodeInfo["job_code"] = jobCode
        jobCodeInfo["ipv4_address"] = jobCodeData["config"]["ipv4_address"]
        jobCodeInfo["ipv4_gateway"] = jobCodeData["config"]["ipv4_gateway"]
        jobCodeInfo["ipv4_netmask"] = jobCodeData["config"]["ipv4_netmask"]
        jobCodeInfo["ipv4_dns"] = jobCodeData["config"]["ipv4_dns_server"]
        jobCodeInfo["ipv4_dns_search"] = jobCodeData["config"]["ipv4_dns_search"]
        jobCodeInfo["hostname"] = jobCodeData["config"]["hostname"]
        jobCodeInfo["domain"] = jobCodeData["config"]["domain"]

        # Call AAP2 Controller, check inventory for existing host
        # If host does not exist, create a new host
        hostSearch = requests.get(aapControllerURL + "/api/v2/inventories/" + aapInventoryID + "/hosts?name=" + jobCodeInfo["hostname"], headers={"Authorization": "Bearer " + aapControllerToken}, verify=False)
        hostSearchData = hostSearch.json()
        if hostSearchData["count"] == 0:
            # Create the host
            hostCreate = requests.post(aapControllerURL + "/api/v2/inventories/" + aapInventoryID + "/hosts/",
                                       headers={"Authorization": "Bearer " + aapControllerToken},
                                       json={"name": jobCodeInfo["hostname"],
                                             "inventory": aapInventoryID,
                                             "enabled": True,
                                             "variables": json.dumps({"ansible_host": provisionedIPAddress,
                                                           "ansible_user": "root"})}, verify=False)
            # Check the status of the host creation
            if hostCreate.status_code != 201:
                return json.dumps({"error": "Error creating host in AAP2 Controller"})
        
        # Run the job limited to the newly created host
        runJobTemplate = requests.post(aapControllerURL + "/api/v2/job_templates/" + aapJobTemplateID + "/launch/",
                                        headers={"Authorization": "Bearer " + aapControllerToken},
                                        json={"limit": jobCodeInfo["hostname"],
                                              "extra_vars": {"provisioned_ip_address": provisionedIPAddress,
                                                           "default_device": default_device,
                                                           "ipv4_address": jobCodeInfo["ipv4_address"],
                                                           "ipv4_gateway": jobCodeInfo["ipv4_gateway"],
                                                           "ipv4_netmask": jobCodeInfo["ipv4_netmask"],
                                                           "ipv4_dns": jobCodeInfo["ipv4_dns"],
                                                           "ipv4_dns_search": jobCodeInfo["ipv4_dns_search"],
                                                           "hostname": jobCodeInfo["hostname"],
                                                           "domain": jobCodeInfo["domain"],
                                                           "job_code": jobCodeInfo["job_code"],
                                                           "submitted_date": submittedDate}}, verify=False)
        # Check the status of the job launch
        if runJobTemplate.status_code != 201:
            return json.dumps({"error": "Error launching job in AAP2 Controller"})
        else:
            return json.dumps({"status": "Job launched successfully"})


##############################
## Start the application when the python script is run
if __name__ == "__main__":
    if tlsCert != "" and tlsKey != "":
        print("Starting FDO Ansible Glue API on port " + str(flaskPort) + " and host " + str(flaskHost) + " with TLS cert " + str(tlsCert) + " and TLS key " + str(tlsKey))
        app.run(ssl_context=(str(tlsCert), str(tlsKey)), port=flaskPort, host=flaskHost)
    else:
        print("Starting FDO Ansible Glue API on port " + str(flaskPort) + " and host " + str(flaskHost))
        app.run(port=flaskPort, host=flaskHost)