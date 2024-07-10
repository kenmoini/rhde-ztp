import os, json, time, yaml
import datetime as dt
from flask import Flask, request, jsonify
from flask_cors import CORS, cross_origin

##############################
# Setup Flask Variables
flaskPort = os.environ.get("FLASK_RUN_PORT", 8675)
flaskHost = os.environ.get("FLASK_RUN_HOST", "0.0.0.0")
tlsCert = os.environ.get("FLASK_TLS_CERT", "")
tlsKey = os.environ.get("FLASK_TLS_KEY", "")

##############################
# Setup application variables
isoPath = os.environ.get("ISO_PATH", "/opt/isos")
jobCodePath = os.environ.get("JOB_CODE_PATH", "/opt/job-codes")

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
    return "ISO ISOs!"

# List ISOs on the file system
@app.route("/listISOs", methods = ['GET'])
def listISOsRoute():
    if request.method == 'GET':

        # List files in ISO path
        isoFiles = []
        if os.path.isdir(isoPath):
            isoFiles = os.listdir(isoPath)
            isoFiles = [f for f in isoFiles if f.endswith(".iso")]

        # Return the JSON message
        #print("ISO Files: ")
        #print(json.dumps(isoFiles))
        return json.dumps(isoFiles)

# List Job Codes by reading in the YAML files
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

# Create a new Job Code
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


##############################
## Start the application when the python script is run
if __name__ == "__main__":
    if tlsCert != "" and tlsKey != "":
        print("Starting ISO Lister API on port " + str(flaskPort) + " and host " + str(flaskHost) + " with TLS cert " + str(tlsCert) + " and TLS key " + str(tlsKey))
        app.run(ssl_context=(str(tlsCert), str(tlsKey)), port=flaskPort, host=flaskHost)
    else:
        print("Starting ISO Lister API on port " + str(flaskPort) + " and host " + str(flaskHost))
        app.run(port=flaskPort, host=flaskHost)