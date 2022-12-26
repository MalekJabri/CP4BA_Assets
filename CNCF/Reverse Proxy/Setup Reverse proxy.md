---
title: Setup Reverse proxy
tags: []
---

# Reverse proxy for CNCF BAW Deployment.


## Setup a reverse proxy 

You will need to keep the suffix and path context the same as for the ingress controller value.

ban-baw-prod.internalurl.local/navigator  --> ban-baw-prod.publichostname.org/navigator

1. Define the hostname suffix using the external endpoint : 
         
         sc_deployment_hostname_suffix: baw-prod.external.com
         
2. For each component defined the hostname as the external endpoint. 
        
        hostname: ae-workspace-baw-prod.external.com
        hostname: baw-bawins1-baw-prod.external.com
        hostname: cmis-baw-prod.external.com
        hostname: fncm-baw-prod.external.com
        hostname: graphql-baw-prod.external.com
        hostname: ban-baw-prod.external.com
        hostname: pfs-baw-prod.external.com
        hostname: rr-baw-prod.external.com
        
        UMS section:
            dedicated_pods: true
            hostname: baw-prod.external.com

3. Add host alias to all the components. 

Add the ingress value as one additional entry including the port.

This is an example for BAW component:

    custom_xml: |
       <server>
            <virtualHost id="default_host">
                <hostAlias>INGRESS_VALUE:443</hostAlias>
                <hostAlias>${clusterip_service_name}:${clusterip_service_port}</hostAlias>
                <hostAlias>${clusterip_service_name}.baw-prod:${clusterip_service_port}</hostAlias>
                <hostAlias>${clusterip_service_name}.baw-prod.svc:${clusterip_service_port}</hostAlias>
                <hostAlias>${clusterip_service_name}.baw-prod.svc.cluster.local:${clusterip_service_port}</hostAlias>
                <hostAlias>${env.POD_NAME}.workflow-bawins1-baw-service-headless:${clusterip_service_port}</hostAlias>
                <hostAlias>${env.POD_NAME}.workflow-bawins1-baw-service-headless.baw-prod.svc:${clusterip_service_port}</hostAlias>
                <hostAlias>${env.POD_NAME}.workflow-bawins1-baw-service-headless.baw-prod.svc.cluster.local:${clusterip_service_port}</hostAlias>
                <hostAlias>${env.POD_IP}:9443</hostAlias>    <hostAlias>${env.POD_NAME}:9443</hostAlias>
            </virtualHost>  
        </server>
    
    
## Options that are not supported on the reverse proxy.

1. You will need to pass the header from the request
    * The redirect for the authentication will fail due to the missing header. The system will try to recreate a header using the internal url. That will fail as the endpoint are not know externally and not registered in the UMS.
          
          CWOAU0073E: An authentication error occurred. Try closing the web browser and authenticating again, or contact the site administrator if the problem persists.
2. Do not overwrite the referer on the header 
    * UMS and BAW (portal / bmprest-ui) can't correctly load some artifact. The internal WAF will block the to present artifact due to security issue.
            
          Cross-Site Request Forgery (CSRF) protection: unacceptable REFERER header: https:\/\/ums-sso-baw-prod.xxxxx\/ums\/login. Expected: host ums-sso-baw-prod.yyyyy and port 443

3. Do not activate the compression
    * Navigator and ACCE does not supported. Some artifacts will not be able to load correctly due to mistake on the path.
