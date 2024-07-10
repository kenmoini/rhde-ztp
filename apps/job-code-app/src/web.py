import random, string
import streamlit as st
from streamlit_extras.stylable_container import stylable_container
import requests
import subprocess
import pandas as pd
import os
import passlib

backendAPI = os.environ.get("BACKEND_API", "")

jobCodes = []
isoFiles = []
# Get the list of job codes and ISOs from the API
if backendAPI != "":
    # Get the list of ISO files
    isoFiles = requests.get(backendAPI + "/listISOs").json()
    if isoFiles == "":
        isoFiles = ["rhde-old.iso", "rhde.iso", "rhde-next.iso"]

    # Get the list of job codes
    jobCodes = requests.get(backendAPI + "/listJobCodes").json()
    if jobCodes == "":
        jobCodes = {
            "job_code": ["ABC", "DEF", "GHI"],
            "boot_protocol": ["PXE", "PXE", "PXE"],
            "iso_name": ["rhde.iso", "rhde-old.iso", "rhde-next.iso"],
            "ipv4_address": ["192.168.42.10", "192.168.42.20", "192.168.42.30"],
            "hostname": ["edge-1", "edge-2", "edge-3"],
            "domain": ["example.com", "example.com", "example.com"],
            "created": ["July 4th, 2024", "July 10th, 2024", "July 14th, 2024"]
        }
else:
    isoFiles = ["rhde-old.iso", "rhde.iso", "rhde-next.iso"]
    jobCodes = {
        "job_code": ["ABC", "DEF", "GHI"],
        "boot_protocol": ["PXE", "PXE", "PXE"],
        "iso_name": ["rhde.iso", "rhde-old.iso", "rhde-next.iso"],
        "ipv4_address": ["192.168.42.10", "192.168.42.20", "192.168.42.30"],
        "hostname": ["edge-1", "edge-2", "edge-3"],
        "domain": ["example.com", "example.com", "example.com"],
        "created": ["July 4th, 2024", "July 10th, 2024", "July 14th, 2024"]
    }

st.set_page_config(page_title="Job Code Manager", layout="wide")
st.title("Job Code Manager")

tab1, tab2 = st.tabs(["Job Codes", "&plus; New"])

with tab1:
    coll, colr =st.columns(2)
    with coll:
        st.header("Job Codes")
    with colr:
        with stylable_container(
            key="align_refresh-right",
            css_styles="""
                button {
                    float:right;
                }
                """,
        ):
            refresh_button = st.button(label="Refresh", type="secondary")
    df = pd.DataFrame(data=jobCodes)
    st.dataframe(df, hide_index=True, use_container_width=True, on_select="ignore", selection_mode="single-row", column_config={"job_code": "Job Code", "boot_protocol": "Boot Protocol", "iso_name": "Image", "ipv4_address": "IP", "hostname": "Hostname", "domain": "Domain", "created": "Created"})

with tab2:
    st.header("Add Job Code")

    col1, col2 =st.columns(2)
    with col1:
        bootProtocol = st.selectbox(label="Boot Protocol", options=["PXE","Redfish"],index=0) 
        hostname = st.text_input(label="System Hostname", placeholder="edge-system")
    with col2:
        isoFiles = st.selectbox(label="Boot ISO", options=isoFiles,index=0)
        domain = st.text_input(label="System Domain", placeholder="example.com")

    col3, col4, col5 = st.columns(3)
    with col3:
        ipv4_address = st.text_input(label="IPv4 Address", placeholder="192.168.42.10")
    with col4:
        ipv4_netmask = st.text_input(label="IPv4 Netmask", placeholder="255.255.255.0")
    with col5:
        ipv4_gateway = st.text_input(label="IPv4 Gateway", placeholder="192.168.42.1")

    col6, col7 = st.columns(2)
    with col6:
        dns_server = st.text_input(label="DNS Server", placeholder="Comma separated")
        sshPubKey = st.text_input(label="SSH Public Key", placeholder="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDQ")
    with col7:
        dns_search = st.text_input(label="DNS Search", placeholder="Comma separated")
        rootPassword = st.text_input(label="Root Password", type="password", placeholder="")

    submit_button = st.button(label="Create Job Code", type="primary")

# Refresh Job Code List
if refresh_button:
    jobCodes = requests.get(backendAPI + "/listJobCodes").json()

if submit_button:
    with st.spinner("Processing Job Code..."):
        # Create a Random 4 character Job Code ID
        job_code = ''.join(random.choices(string.ascii_uppercase + string.digits, k=4))
        boot_protocol = f"{bootProtocol}"
        iso_name = f"{isoFiles}"
        hostname = f"{hostname}"
        domain = f"{domain}"
        ipv4_address = f"{ipv4_address}"
        ipv4_netmask = f"{ipv4_netmask}"
        ipv4_gateway = f"{ipv4_gateway}"
        dns_server = f"{dns_server}"
        dns_search = f"{dns_search}"
        # split dns_server and dns_search
        ipv4_dns_server = dns_server.split(",")
        ipv4_dns_search = dns_search.split(",")
        ssh_pub_key = f"{sshPubKey}"
        root_password = f"{rootPassword}"
        # hash the password with openssl
        root_password_hash = subprocess.run(["openssl", "passwd", "-6", root_password], stdout=subprocess.PIPE).stdout.decode().strip()
        #root_password_hash = passlib.hash.sha512_crypt.hash(root_password)
        # https://onlinephp.io/password-verify

        job_code_data = {"config":
            {
                "job_code": job_code,
                "boot_protocol": boot_protocol,
                "iso_name": iso_name,
                "hostname": hostname,
                "domain": domain,
                "ipv4_address": ipv4_address,
                "ipv4_netmask": ipv4_netmask,
                "ipv4_gateway": ipv4_gateway,
                "ipv4_dns_server": ipv4_dns_server,
                "ipv4_dns_search": ipv4_dns_search,
                "ssh_pub_key": ssh_pub_key,
                "root_password": root_password_hash
            }
        }
        response = requests.post(backendAPI + "/createJobCode", json=job_code_data)
        container_output = st.empty()
        # print out the job code
        # Make sure the response was successful
        if response.status_code == 200:
            container_output.write("Job Code " + job_code + " Created Successfully!")
            jobCodes = requests.get(backendAPI + "/listJobCodes").json()
        else:
            container_output.write("Error Creating Job Code")
