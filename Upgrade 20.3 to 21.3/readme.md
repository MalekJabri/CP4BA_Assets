---
title: Upgrade 20.3 to 21.3
tags: []
---

# Upgrade of the CP4BA 20.3 to 21.3

This is a note to explain how to upgrade the from 20.3 to 21.3
This is not meant to replace the official documentation.

## Preparation:

## Backup Database and all the directory 

### Download the archive that contains all the scripts and check the different version.

* Verify that you have the right version of the cli and product 
    https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/21.0.3?topic=deployment-preparing-client-connect-cluster
    
    
* The library can be found in the following links : 
    * https://www.ibm.com/support/pages/node/6576423
    * https://github.com/IBM/cloud-pak/tree/master/repo/case/ibm-cp-automation



            wget https://github.com/IBM/cloud-pak/raw/master/repo/case/ibm-cp-automation-3.2.10.tgz
            tar -xvzf ibm-cp-automation-3.2.10.tgz
            cd ibm-cp-automation/inventory/cp4aOperatorSdk/files/deploy/crs
            tar -xvzf cert-k8s-21.0.3.tar
    
### Check the differnet password secrets and Verify the differents databases 

* Apply all the secret related to the different components

      oc apply -f app-secrets.yaml
      oc apply -f ban-secrets.yaml
      oc apply -f bas-secrets.yaml
      oc apply -f ums-secrets.yaml
      oc apply -f wfs-secrets.yaml
      oc apply -f ldap-secrets.yaml
      oc apply -f fncm-secrets.yaml
      oc apply -f Shred_encryption_key.yaml

* List all the required database make sure that are both aligned

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

### Upgrade the CP4BA Operator 

1. Upgrade the commmon services
    
    - Upgraded Common Service (use workaround: https://www.ibm.com/docs/en/cpfs?topic=issues-operator-installation-hangs-during-upgrade)
    - The quickest way, I just deploy a new emtpy cp4ba to a new project/namespace.

2. Upgrade the Operator by using the script using the catalog.

    * Verify that the cloud pak for business automation is present in the Operatorhub catalog 
    * if not apply the catalog to the /cert-kubernetes/descriptors/op-olm/cp4a_catalogsource.yaml
            
          apply -f /cert-kubernetes/descriptors/op-olm/cp4a_catalogsource.yaml
    
    * if not done, the new database library in the operator-shared-pvc/jdbc/db2/
        * Yes I had to upgrade the database version
        
    * check your Entitlement Key is still active from the portal https://myibm.ibm.com/products-services/containerlibrary
    
        ![](./attachments/image-kxpwtwaf.png?raw=true)
    
    * check the admin.registry is still correct
        
          DOCKER_RES_SECRET_NAME="admin.registrykey"
          DOCKER_REG_SERVER="cp.icr.io"
          DOCKER_REG_USER="cp"                
          DOCKER_REG_KEY="Your KEY"
          oc create secret docker-registry $DOCKER_RES_SECRET_NAME --docker-server=$DOCKER_REG_SERVER --docker-username=$DOCKER_REG_USER --docker-password=$DOCKER_REG_KEY --docker-email=ecmtest@ibm.com
        
    * upgrade the operator using the script 
    
        * This is  will create the operator subscription for CP4A and all the foundation layer       
        
    * Please wait until all the sub operator are up and running : 

        ![](./attachments/image-kxpxis05.png?raw=true)
     
    * if there is an issue, with the foundation operator not working 
        * Can't reach the default service API 
        * You will need to create the different Network policy that are missing temporally as those will be created after the pods started.
                 
              oc apply -f networkpolicies
                        
## Prepare the CR for th Authoring Env


1. Run the following script and follow the wizard

      ./cp4a-deployment.sh
    
2. Select the option 5A for the auhoring

3. the CR will be generated in the following directory 
    
    cert-kubernetes/scripts/generated-cr/ibm_cp4a_cr_final.yaml
    
4. Update the document with all the mandatory components.     

5. Check the ldap configuration first UMS and IAM don't support the same group filter defined by default for Tivoli.


## Apply the Cr and check the logs 

####  1. Before Apply the CR 

 * Verify that you have all the secrets applied correclty 
 * the ldap configuration is correct
 * the database configuration is correct
 * the security groups for the object store are correct
 * the tablespace is well defined for the TOS

####  2. After you have updated the cr, apply the cr 

        oc apply -f baw-authoring-env.yaml --overwrite=true

####  3. wait few minutes, check the Operator logs and verify that it initiate the 21.3 deployement. 
   * Method 1: In the logs stream, you will see reference to either 21.3 or 20.3 package /scripts then if you don't see any 21.3 metion. 
   * Method 2: Checks the Cartridge on the IBM Automation Foundation Core mention a new deployement see step 6

If it's not the case , Just reboot the cp4ba operator

#### 3B if the oidc watcher on the common service is crash looping mode due to OOMKilled.
    
The OIDC Watcher is looping due to Memory limitation (OOMKilled) 
* Edit the common service and increase the cpu and memory size.


####  4A. the first step the system will deploy the foundation component required for the cp4ba
   * That includes
        * Zen
        * Common Licenses
        * IAM
        * BTS
    * Make sure that all the Operator and Subscription are update  and flagged them to Automatic
    * Delete the subscirption that are falling in error 
    * !! Caution if you are using BAI it will start a set of addtional Operator

####  4B. if the cp-console is not reacheable please reboot the following pod on the IBM Common Services OR IAF loop in the operator.   
     
   - Authentication pod :  auth-idp-xxxxxxx
   - Common UI POD  : common-web-ui-xxxxxxx
        
####  5. that will take at least 30 minutes to deploy.
####  6. Check the commmon services projects.
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
        
####  7.After all the foundation layer deployed, the system will upgrade components per components.
####  8.After almost ? hours, the different components should have been updated. 

####  9.You can check the CR to review the deployement status and the endpoints
        
- New way:
    
![](./attachments/image-kydf8wnf.png?raw=true)

![](./attachments/image-kydfc1dm.png?raw=true)


- OLD way:
    
![](./attachments/image-kydfdocr.png?raw=true)

##### 10. Reach specific capabiliteis

if you are facing some issue to reach some end-points, reboot the following pod:

zen-watcher

![](./attachments/image-kydjna83.png?raw=true)

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
* remove ums Section
* avaid as much as possible to delete the icp4deploy
    * Trouble with IAF, ZEn,......

# Troubleshooting

### Foundation not installed correclty 

![](./attachments/image-kycsn9zz.png?raw=true)

    Failed to get API Group-Resources","error":"Get \"https://172.21.0.1:443/api?timeout=32s\"

The issue some mandatory network policies are missing :

    oc apply -f networkpolicies

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
