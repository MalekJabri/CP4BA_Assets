title: 21.0.3 fresh Install


# Install of the CP4BA

This is a note created to present how to install an enterprise deployment of baw authoring 21.0.3 on Roks.
We are using DB2 and TDS.

## Preparation:

### Download the archive that contains all the scripts and check the different version.

* Verify that you have the right version of the cli and product 
    https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/21.0.3?topic=deployment-preparing-client-connect-cluster
    
    
* The library can be found in the following links : 
https://github.com/IBM/cloud-pak/tree/master/repo/case/ibm-cp-automation

    wget https://github.com/IBM/cloud-pak/raw/master/repo/case/ibm-cp-automation/3.2.0/ibm-cp-automation-3.2.0.tgz
    
    tar -xvzf ibm-cp-automation-3.2.0.tgz
    cd ibm-cp-automation/inventory/cp4aOperatorSdk/files/deploy/crs
    tar -xvzf cert-k8s-21.0.3.tar
    
### Apply the differnet password secrets and create the differents databases 

* Apply all the secret related to the different components

      oc apply -f app-secrets.yaml
      oc apply -f ban-secrets.yaml
      oc apply -f bas-secrets.yaml
      oc apply -f ums-secrets.yaml
      oc apply -f wfs-secrets.yaml
      oc apply -f ldap-secrets.yaml
      oc apply -f fncm-secrets.yaml
      oc apply -f Shred_encryption_key.yaml

* Create all the required database 

      Database alias                       = BASTUDIO
      Database alias                       = WKSAE
      Database alias                       = UMSDB
      Database alias                       = DOS
      Database alias                       = AEENGINE
      Database alias                       = TOS
      Database alias                       = GCD
      Database alias                       = ICNBAW
      Database alias                       = BAWCENT
      Database alias                       = AEOS
      Database alias                       = DOCS





# Verify that the database, ldap and nfs server are up and running and reachable.

### Deploy the CP4BA Operator 


1. Install using the catalog.

    * Verify that the cloud pak for business automation is present in the Operatorhub catalog 
    * if not apply the catalog to the /cert-kubernetes/descriptors/op-olm/cp4a_catalogsource.yaml
            
          apply -f /cert-kubernetes/descriptors/op-olm/cp4a_catalogsource.yaml
    
    * Create the PVC for the Operator 
    
            kind: PersistentVolumeClaim
            apiVersion: v1
            metadata:
              name: cp4a-shared-log-pvc
            spec:
              storageClassName: managed-nfs-storage
              accessModes:
                - ReadWriteMany
              resources:
                requests:
                  storage: 100Gi
            ---
            apiVersion: v1
            kind: PersistentVolumeClaim
            metadata:
              name: operator-shared-pvc
            spec:
              storageClassName: managed-nfs-storage
              accessModes:
                - ReadWriteMany
              resources:
                requests:
                  storage: 1Gi
                  
    * Copy the database library in the operator-shared-pvc/jdbc/db2/
    * Get you Entitlement Key from the portal https://myibm.ibm.com/products-services/containerlibrary
    
        ![](./attachments/image-kxpwtwaf.png?raw=true)
    
    * Create the admin.registry 
        
          DOCKER_RES_SECRET_NAME="admin.registrykey"
          DOCKER_REG_SERVER="cp.icr.io"
          DOCKER_REG_USER="cp"                
          DOCKER_REG_KEY="Your KEY"
          oc create secret docker-registry $DOCKER_RES_SECRET_NAME --docker-server=$DOCKER_REG_SERVER --docker-username=$DOCKER_REG_USER --docker-password=$DOCKER_REG_KEY --docker-email=ecmtest@ibm.com
         
    * search  the CP4BA OLM 

        ![](./attachments/image-kxpx3srg.png?raw=true)
        
    * Install it 

        ![](./attachments/image-kxpx5bja.png?raw=true)
        
    * Wait until the installation is done. Be aware that a couple of other operator will be installed as we now include the foundation layer.
    
        ![](./attachments/image-kxpxaswx.png?raw=true)

        ![](./attachments/image-kxpxgrs3.png?raw=true)
        
        
    * Please wait until all the sub operator are up and running : 

        ![](./attachments/image-kxpxis05.png?raw=true)
             
    * Make sure to enable the support of db2 on nfs

          oc get nodes
          oc debug node/ipaddess
          chroot /host
          vi /etc/idmapd.conf
     * insert in the document the following entry 
            
           Domain = slnfsv4.coms
     * Save the document 
     * Execute the following command 
      
           nfsidmap -c
           rpc.idmapd
           exit
           exit
           
    

2. Install using the script.

    * run the following script and follow the wizard. 
    
            ./cp4a-clusteradmin-setup.sh
      The script will create the entitlement key, the different pvc and update the nodes with the db2 domains.
      
      
    $\color{#FF0FFF} Funny  \space \space that \space the \space script \space required \space  less \space  manual \space intervention \space :-)$
      
    * Copy the database library in the operator-shared-pvc/jdbc/db2/
    
## Copy db2 / database driver 

* Copy the database library in the operator-shared-pvc/jdbc/db2/

## Prepare the CR for th Authoring Env


* Run the following script and follow the wizard

      ./cp4a-deployment.sh
    
* Select the option 5A for the auhoring

* the CR will be generated in the following directory 
    
    cert-kubernetes/scripts/generated-cr/ibm_cp4a_cr_final.yaml
    
* Update the document with all the mandatory components.     

* Check the ldap configuration first UMS and IAM don't support the same group filter defined by default for Tivoli.


## Apply the Cr and check the logs 

* Update the CR 
* Verify that you have all the secrets applied correclty 
* the ldap configuration is correct
* the database configuration is correct
* the security groups for the object store are correct
* the tablespace is well defined for the TOS


* After you have updated the cr, apply the cr 
* the first step the system will deploy the foundation component required for the cp4ba
    * That includes
        * Zen
        * Common Licenses
        * IAM
        * BTS
* that will take at least 30 minutes to deploy.
* Check the commmon services projects.
    * sometimes will see some pod failing due to some config map not existing no worries. that pod has started a little to early another job will update the config.
    * Patience patience !!!
    * You can check the status of the foundation following those screens. 
    * On your project, click on installed operators 

    * Click on Cartridge on the IBM Automation Foundation Core 

        ![](./attachments/image-kxq3k9nj.png?raw=true)
        
    * Click on the project 
    
        ![](./attachments/image-kxq3ltzh.png?raw=true)
        
    * Scroll down on the conditions section and verify that the status is true for the following components
    
        ![](./attachments/image-kxq3oi7o.png?raw=true)
        
## Test Foundation 

The CP console is the unified portal for all the cloud paks installed on the platform. You will have also a unified portal per cloud pak available on the project itself.

* Retrieve first the password to connect to the cp console.
* Connect to the common service project and select workloads and secrets
![](./attachments/image-kxq5l0ks.png?raw=true)
* Search for the following secrets: ibm-iam-bindinfo-platform-auth-idp-credentials
* Copy the password 
![](./attachments/image-kxq5jkzk.png?raw=true)
* <b>On the common service project </b> select on the right side networking and then  routes

![](./attachments/image-kxq3u7yd.png?raw=true)
 
* Click on the cp console location (url). 

![](./attachments/image-kxq5mu3a.png?raw=true)

## Diff 20.0.3 to 21.0.3


* secret named for the authoring default is baw-admin-secret to ibm-baw-wfs-server-db-secret

# Troubleshooting

### Remark if you need to delete and apply again a CR, Please delete the following directory 

     rm -rf user-home-pvc/_global_/nginx-conf.d/*
     rm -rf user-home-pvc/_global_/upstream-conf.d/*
     rm -rf ibm-bts-cnpg-cp2103-cp4ba-bts-1/pgdata

### In Case of Issue with the zen service

https://www.ibm.com/docs/en/cloud-paks/1.0?topic=about-known-issues-limitations

I had to delete the zen service manually and please keep an eye on the common service

    oc delete zenservice iaf-zen-cpdservice
    
    
## Issue with the Worplace setup 

Issue with the oidc pointing to the old ums configuration 

![](./attachments/image-kxrip1z8.png?raw=true)

        Start the entrypoint under privilege '1000710000'
        Info: Take command './initAE.sh' as frontend service
        chmod: changing permissions of '/proc/self/fd/1': Permission denied
        chmod: changing permissions of '/proc/self/fd/2': Permission denied
        Logging to /logs/application/AE/icp4adeploy-workspace-aae-ae-db-job-9s6nx/out.log
        2021-12-29 12:10:30,676 WARN For [program:monitoring], AUTO logging used for stdout_logfile without rollover, set maxbytes > 0 to avoid filling up filesystem unintentionally
        2021-12-29 12:10:30,677 INFO Included extra file "/etc/supervisor/ext/filebeat.conf" during parsing
        2021-12-29 12:10:30,677 INFO Included extra file "/etc/supervisor/ext/logging.conf" during parsing
        2021-12-29 12:10:30,677 INFO Included extra file "/etc/supervisor/ext/monitoring.conf" during parsing
        2021-12-29 12:10:30,685 INFO RPC interface 'supervisor' initialized
        2021-12-29 12:10:30,685 CRIT Server 'unix_http_server' running without any HTTP authentication checking
        2021-12-29 12:10:30,686 INFO supervisord started with pid 11
        Dec 29, 2021 12:10:30 PM com.ibm.appEngine.initdb.AppEngineInitDB main
        INFO: Environment variables and values for the App Engine Init DB program  --- AE_DATABASE_TYPE = db2, AE_DATABASE_NAME = WKSAE, AE_DATABASE_HOST = 158.177.226.226, AE_DATABASE_PORT = 50002, AE_DATABASE_ALT_HOST = , AE_DATABASE_ALT_PORT = , AE_DATABASE_ENABLE_SSL = false, AE_DATABASE_SSL_SERVER_CERTIFICATE = /shared/dbtls/truststore/pem/db-ssl-cert.crt, AE_DATABASE_USER = DB2inst2, AE_DATABASE_CURRENT_SCHEMA = DBASB, AE_DATABASE_PWD = ****, ADMIN_USER = ceadmin, AE_DATABASE_ORACLE_URL_WITHOUT_WALLET_LOCATION = , AE_DATABASE_ORACLE_TRUSTSTORE = , AE_DATABASE_ORACLE_TRUSTSTORE_PWD =
        Dec 29, 2021 12:10:30 PM com.ibm.appEngine.initdb.AppEngineInitDB main
        INFO: Connecting to database ...
        Dec 29, 2021 12:10:31 PM com.ibm.appEngine.initdb.AppEngineInitDB main
        INFO: Connected to database: jdbc:db2://158.177.226.226:50002/WKSAE
        Dec 29, 2021 12:10:31 PM com.ibm.appEngine.initdb.AppEngineInitDB checkDBExist
        INFO: Existing table and schema found : DBASB.SB_SYSTEM
        Dec 29, 2021 12:10:31 PM com.ibm.appEngine.initdb.AppEngineInitDB main
        INFO: Database has already been initialized with schema version : 1.0.3
        2021-12-29 12:10:31,689 INFO spawned: 'monitoring' with pid 46
        https://icp4adeploy-workspace-aae-ae-service/ae-workspace/v2/applications is online

          % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                         Dload  Upload   Total   Spent    Left  Speed
          0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     02021-12-29 12:10:31,739 INFO success: monitoring entered RUNNING state, process has stayed up for > than 0 seconds (startsecs)
        [2021-12-29 12:10:32] plugin_load: plugin "logfile" successfully loaded.
        100    92    0     0  100    92      0    438 --:--:-- --:--:-- --:--:--   436100    92    0     0  100    92      0     75  0:00:01  0:00:01 --:--:--    75100   172  100    80  100    92     38     43  0:00:02  0:00:02 --:--:--    82
        parse error: Invalid numeric literal at line 1, column 7
          % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                         Dload  Upload   Total   Spent    Left  Speed
          0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0100   107  100   107    0     0   3242      0 --:--:-- --:--:-- --:--:--  3242
        Begin to import toolkits located at /opt/ibm/applications/toolkits
          Importing /opt/ibm/applications/toolkits/SystemData-TC.zip
              % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                         Dload  Upload   Total   Spent    Left  Speed
          0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0100  9375  100    28  100  9347    595   194k --:--:-- --:--:-- --:--:--  194k

         can't import /opt/ibm/applications/toolkits/SystemData-TC.zip, error: The access token is invalid.
        Error
    
   ![](./attachments/image-kxrimzgp.png?raw=true)
   
   
 NameImageResource limitsPorts
ae-db-initcp.icr.io/cp/cp4a/aae/solution-server-helmjob-db@sha256:45b59d13d6fb98d62219e4a3e8b9e951dee387d4152bcfcc1c671c41a56d56c2cpu: 1, memory: 256Mi



oc patch rolebindings edit -n workflow -p '{"metadata":{"finalizers":[]}}' --type=merge
