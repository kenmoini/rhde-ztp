import os, json, time, yaml, requests
import datetime as dt
from flask import Flask, request, jsonify
from flask_cors import CORS, cross_origin

# job-code-app imported functions

##############################
# Setup Flask Variables
flaskPort = os.environ.get("FLASK_RUN_PORT", 9876)
flaskHost = os.environ.get("FLASK_RUN_HOST", "0.0.0.0")
tlsCert = os.environ.get("FLASK_TLS_CERT", "")
tlsKey = os.environ.get("FLASK_TLS_KEY", "")

##############################
# Setup application variables
isoPath = os.environ.get("ISO_PATH", "/opt/isos")
jobCodePath = os.environ.get("JOB_CODE_PATH", "/opt/job-codes")

aapControllerURL = os.environ.get("AAP_CONTROLLER_URL", "https://aap2-controller")
aapControllerToken = os.environ.get("AAP_CONTROLLER_TOKEN", "")

aapGlueJobTemplateID = os.environ.get("AAP_GLUE_JOB_TEMPLATE_ID", "123456")
aapUpdatePXEJobTemplateID = os.environ.get("AAP_UPDATE_PXE_JOB_TEMPLATE_ID", "123456")

aapGlueInventoryID = os.environ.get("AAP_INVENTORY_ID", "123456")
#aapUpdatePXEInventoryID = os.environ.get("AAP_INVENTORY_ID", "123456")

##############################
# creates a Flask application
app = Flask(__name__)
CORS(app) # This will enable CORS for all routes

####################################################################################################
# Health check endpoint
@app.route("/healthz", methods = ['GET'])
def healthz():
    if request.method == 'GET':
        return "ok"

####################################################################################################
# Index endpoint
@app.route("/")
def index():
    return "Horses R Us!"

####################################################################################################
# List ISOs on the file system
# Just needs the /opt/isos directory to be mounted
@app.route("/listISOs", methods = ['GET'])
def listISOsRoute():
    if request.method == 'GET':

        # List files in ISO path
        isoFiles = []
        if os.path.isdir(isoPath):
            isoFiles = os.listdir(isoPath)
            isoFiles = [f for f in isoFiles if f.endswith(".iso")]

        # Return the JSON message
        return json.dumps(isoFiles)

####################################################################################################
# List Job Codes by reading in the YAML files
# Just needs the /opt/job-codes directory to be mounted
@app.route("/listJobCodes", methods = ['GET'])
def listJobCodesRoute():
    if request.method == 'GET':
        # List files in job code path
        jobCodes = {"job_code": [], "boot_protocol": [], "iso_name": [], "ipv4_address": [], "hostname": [], "domain": [], "created": []}
        jobCodeFiles = []
        if os.path.isdir(jobCodePath):
            jobCodeFiles = os.listdir(jobCodePath)
            jobCodeFiles = [f for f in jobCodeFiles if f.endswith(".yaml")]

        ## Read in each file and append to the jobCodes object
        for jobCode in jobCodeFiles:
            jobCodeFile = open(jobCodePath + "/" + jobCode, "r")
            jobCodeData = yaml.load(jobCodeFile, Loader=yaml.FullLoader)
            # Append to the jobCodeID key with the filename without the extension
            jobCodes["job_code"].append(jobCode.replace(".yaml", ""))
            jobCodes["boot_protocol"].append(jobCodeData["config"]["boot_protocol"])
            jobCodes["iso_name"].append(jobCodeData["config"]["iso_name"])
            jobCodes["ipv4_address"].append(jobCodeData["config"]["ipv4_address"])
            jobCodes["hostname"].append(jobCodeData["config"]["hostname"])
            jobCodes["domain"].append(jobCodeData["config"]["domain"])
            # Append the created date by the file creation date
            file_time = dt.datetime.fromtimestamp(os.path.getmtime(__file__))
            jobCodes["created"].append(file_time.strftime("%B %d %Y, %H:%M"))

        ## Return the JSON message
        #print("Job Codes: ")
        #print(json.dumps(jobCodes))
        return json.dumps(jobCodes)

####################################################################################################
# Create a new Job Code
# Just needs the /opt/job-codes directory to be mounted
@app.route("/createJobCode", methods = ['POST'])
def createJobCodeRoute():
    if request.method == 'POST':
        # Get the JSON data from the request
        jobCodeData = request.json

        # Write the data to a new YAML file
        jobCodeFile = open(jobCodePath + "/" + jobCodeData["config"]["job_code"] + ".yaml", "w")
        jobCodeFile.write(yaml.dump(jobCodeData))
        jobCodeFile.close()

        # Return the JSON message
        #print("Created Job Code: ")
        #print(json.dumps(jobCodeData))
        return json.dumps(jobCodeData)

####################################################################################################
# Create a new Job Code Claim
# Just needs the /opt/job-codes directory to be mounted
# Takes in the Job Code ID and MAC Address, creates a new YAML file with the MAC Address, Date, and Job Code ID, filename being the MAC Address
# Reads in the associated Job Code ID data, sends it to Ansible to reconfigure the PXE server
# Returns the Job Code data and the Job Code Claim data
@app.route("/createJobCodeClaim", methods = ['POST'])
def createJobCodeClaimRoute():
    if request.method == 'POST':
        # Get the JSON data from the request
        inputData = request.json

        # Assemble submitted claim data
        macAddressInput = inputData["mac_address"]
        macAddressDash = macAddressInput.replace(":", "-")
        macAddressDashLower = macAddressDash.lower()
        jobCode = inputData["job_code"]
        submittedDate = time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime())
        jobCodeClaimData = {"mac_address": macAddressInput, "job_code": jobCode, "submitted_date": submittedDate}

        # Make sure a Job Code file exists
        if not os.path.exists(jobCodePath + "/" + jobCode + ".yaml"):
            return json.dumps({"error": "Job Code does not exist"})
        
        # Write the data to a new YAML file for the Job Code Claim
        jobCodeClaimFile = open(jobCodePath + "/claims/" + macAddressDashLower + ".yaml", "w")
        jobCodeClaimFile.write(yaml.dump(jobCodeClaimData))
        jobCodeClaimFile.close()

        # Read in the Job Code YAML file
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

        # Kick off the Ansible Job Template that reconfigures the PXE server
        runJobTemplate = requests.post(aapControllerURL + "/api/v2/job_templates/" + aapUpdatePXEJobTemplateID + "/launch/",
                                        headers={"Authorization": "Bearer " + aapControllerToken},
                                        json={"extra_vars": json.dumps({"mac_address": macAddressInput,
                                                           "ipv4_address": jobCodeInfo["ipv4_address"],
                                                           "ipv4_gateway": jobCodeInfo["ipv4_gateway"],
                                                           "ipv4_netmask": jobCodeInfo["ipv4_netmask"],
                                                           "ipv4_dns": jobCodeInfo["ipv4_dns"],
                                                           "ipv4_dns_search": jobCodeInfo["ipv4_dns_search"],
                                                           "hostname": jobCodeInfo["hostname"],
                                                           "domain": jobCodeInfo["domain"],
                                                           "job_code": jobCodeInfo["job_code"]})}, verify=False)

        if runJobTemplate.status_code != 201:
            return json.dumps({"error": "Error launching job in AAP2 Controller"})
        else:
            # Return the JSON message
            return json.dumps({"status": "success", "jobCodeData": jobCodeInfo, "jobCodeClaimData": jobCodeClaimData})

####################################################################################################
# Look up Job Codes, by MAC Address after they were claimed
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
        hostSearch = requests.get(aapControllerURL + "/api/v2/inventories/" + aapGlueInventoryID + "/hosts?name=" + jobCodeInfo["hostname"], headers={"Authorization": "Bearer " + aapControllerToken}, verify=False)
        hostSearchData = hostSearch.json()
        if hostSearchData["count"] == 0:
            # Create the host
            hostCreate = requests.post(aapControllerURL + "/api/v2/inventories/" + aapGlueInventoryID + "/hosts/",
                                       headers={"Authorization": "Bearer " + aapControllerToken},
                                       json={"name": jobCodeInfo["hostname"],
                                             "inventory": aapGlueInventoryID,
                                             "enabled": True,
                                             "variables": json.dumps({"ansible_host": provisionedIPAddress,
                                                           "ansible_user": "root"})}, verify=False)
            # Check the status of the host creation
            if hostCreate.status_code != 201:
                return json.dumps({"error": "Error creating host in AAP2 Controller"})
        
        # Run the job limited to the newly created host
        runJobTemplate = requests.post(aapControllerURL + "/api/v2/job_templates/" + aapGlueJobTemplateID + "/launch/",
                                        headers={"Authorization": "Bearer " + aapControllerToken},
                                        json={"limit": jobCodeInfo["hostname"],
                                              "extra_vars": json.dumps({"provisioned_ip_address": provisionedIPAddress,
                                                           "default_device": default_device,
                                                           "ipv4_address": jobCodeInfo["ipv4_address"],
                                                           "ipv4_gateway": jobCodeInfo["ipv4_gateway"],
                                                           "ipv4_netmask": jobCodeInfo["ipv4_netmask"],
                                                           "ipv4_dns": jobCodeInfo["ipv4_dns"],
                                                           "ipv4_dns_search": jobCodeInfo["ipv4_dns_search"],
                                                           "hostname": jobCodeInfo["hostname"],
                                                           "domain": jobCodeInfo["domain"],
                                                           "job_code": jobCodeInfo["job_code"],
                                                           "submitted_date": submittedDate})}, verify=False)
        # Check the status of the job launch
        if runJobTemplate.status_code != 201:
            return json.dumps({"error": "Error launching job in AAP2 Controller"})
        else:
            return json.dumps({"status": "Job launched successfully"})


##############################
## Start the application when the python script is run
if __name__ == "__main__":
    if tlsCert != "" and tlsKey != "":
        print("Starting Unified API on port " + str(flaskPort) + " and host " + str(flaskHost) + " with TLS cert " + str(tlsCert) + " and TLS key " + str(tlsKey))
        app.run(ssl_context=(str(tlsCert), str(tlsKey)), port=flaskPort, host=flaskHost)
    else:
        print("Starting Unified API on port " + str(flaskPort) + " and host " + str(flaskHost))
        app.run(port=flaskPort, host=flaskHost)