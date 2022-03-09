This folder is related to the scripts to change the hostname for the CPD and CP routes.
You will need to download the folder in your client where an OC client is installed.  
This script has been tested on Redhat as OS client and Openshift on IBM Cloud.


# Prerequisites: 

* OC client installed 
* OC client active connection to your cluster
* Add the different certificate in the tls folder for the cp and cpd if needed. 

# change the cpd route:
    
Donwload this folder, open a console

    ./change_cpd_route.sh

The wizard will start: 

![image](https://user-images.githubusercontent.com/33630653/157493957-b8c67498-0880-4295-9403-75affb9a5a35.png)

* fill the project/namespace 
* fill the new cpd hostname route
* y/n to create and add the certificate.

The script will udpate the configuration and restart the serveral component.
Please be patient !! It will take some time to propagte all the change.

# Change the cp route:

