echo "Change the name of CPD console and Apply the fix"
echo "If new certificate available make sure to add ot the project with the following name external-tls-secret"
echo "The script will create the secrets: ca.crt : tls/cpd/ca.pem ; cert.tls : tls/cpd/cert.pem ; cert.key : tls/cpd/cert.key"

read -p "Get Project name : " project
read -p "new cpd hostname name : " hostname
read -p "Add Certificate yes or no (y-n)": SSL
oc project $project

if [[ $SSL  = "y" ]];
then
oc -n $project create secret generic external-tls-secret --from-file=cert.crt=tls/cpd/cert.pem --from-file=cert.key=tls/cpd/cert.key --from-file=ca.crt=tls/cpd/ca.pem --dry-run=client -o yaml | oc apply -f -
oc patch AutomationUIConfig iaf-system --type='json' -p '[{"op": "add", "path": "/spec/tls/certificateSecret", "value": {"secretName": "external-tls-secret"} }, {"op": "add", "path": "/spec/zenService/zenCustomRoute", "value": {"route_host":"'$hostname'"}}]'
oc delete pod -l app.kubernetes.io/component=ibm-nginx
else
oc patch AutomationUIConfig iaf-system --type='json' -p '[{"op": "add", "path": "/spec/zenService/zenCustomRoute", "value": {"route_host":"'$hostname'"}}]'
fi

echo "Waiting route to change witht the new host $hostname "
oc get route cpd  > route_name.txt
currentfile="$(md5sum route_name.txt | head -n1 | cut -d " " -f1 )"
newfile="$(md5sum route_name.txt | head -n1 | cut -d " " -f1)"
while [[ $currentfile = $newfile ]]
do
     npod="$(oc get route cpd |sed -n '2p'| head -n1 | cut -d " " -f5)"
     echo "check the route name change  $npod"
     sleep 20
     oc get route cpd  > route_name.txt
     newfile="$(md5sum route_name.txt | head -n1 | cut -d " " -f1)"
done
echo "apply fix on the Zen route"

rm -f route_name.txt

oidc_client=zenclient-$project

post_logout_redirect_uris=https://$hostname/auth/doLogout
redirect_uris=https://$hostname/auth/login/oidc/callback
trusted_uri_prefixes=https://$hostname
zenProductNameUrl=https://$hostname/v1/preauth/config

    oc patch client $oidc_client -n $project --type='json' -p="[  \
      {\"op\":\"replace\",\"path\":\"/spec/oidcLibertyClient/post_logout_redirect_uris\",\"value\":[\"$post_logout_redirect_uris\"]}, \
      {\"op\":\"replace\",\"path\":\"/spec/oidcLibertyClient/redirect_uris\",\"value\":[\"$redirect_uris\"]}, \
      {\"op\":\"replace\",\"path\":\"/spec/oidcLibertyClient/trusted_uri_prefixes\",\"value\":[\"$trusted_uri_prefixes\"]}, \
      {\"op\":\"replace\",\"path\":\"/spec/zenProductNameUrl\",\"value\":\"$zenProductNameUrl\"}]"
