deleteUserManagementPod()
{
   project=$1
   shift; shift;
   # Having shifted twice, the rest is now comments ...
   echo "delete project usermanagement pod for the project $project"
   echo `oc -n $project delete pod -l component=usermgmt`
}


ibmcommonservice=ibm-common-services
echo "This script will help to change the hostname/url of CP console"
echo "It will also propose to update / create the secret from the certificates for the cp route."
echo "for the certificate, ensure that the following file is present : tls/cp/ca.crt, tls/cp/tls.crt, tls/cp/tls.key"

read -p "New cp hostname name : " hostname
read -p "Add Certificate yes or no (y-n)": SSL
oc project $ibmcommonservice

if [[ $SSL  = "y" ]]; then
echo "create secret for the new cp route $hostname"
oc -n ibm-common-services create secret generic custom-tls-secret --from-file=ca.crt=.tls/cp/ca.crt  --from-file=tls.crt=./tls/cp/tls.crt  --from-file=tls.key=./tls/cp/tls.key
cat ./template/cs-onprem-tenant-config.yaml | echo "   custom_host_certificate_secret: custom-tls-secret" >> iam-custom-hostname.yaml
else 
cp ./template/cs-onprem-tenant-config.yaml iam-custom-hostname.yaml
fi

echo "Create config map"
echo `sed -i "s+custom_url+$hostname+g" ./iam-custom-hostname.yaml`
echo "Apply config map"
oc apply -f iam-custom-hostname.yaml -n $ibmcommonservice
echo "Run the job"
oc apply -f ./template/iam-custom-hostname-job.yaml -n $ibmcommonservice 
echo "Restard the relevant pod"
oc -n $ibmcommonservice delete pod -l name=operand-deployment-lifecycle-manager



echo "List all the ICP4A project "
oc get $(oc get crd -o=custom-columns=CR_NAME:.spec.names.singular --no-headers | awk '{printf "%s%s",sep,$0; sep=","}') --ignore-not-found --all-namespaces -o=custom-columns=KIND:.kind,NAME:.metadata.name,NAMESPACE:.metadata.namespace | grep ICP4ACluster |  awk -F " " '{ $1 = "" ; $2 = "" ; print $0 }' |  awk '{gsub(/^[ \t]+/,""); print $0}'

read -p "Update all icp4ba project : " decision

if [[ $decision  = "y" ]]; then
oc get $(oc get crd -o=custom-columns=CR_NAME:.spec.names.singular --no-headers | awk '{printf "%s%s",sep,$0; sep=","}') --ignore-not-found --all-namespaces -o=custom-columns=KIND:.kind,NAME:.metadata.name,NAMESPACE:.metadata.namespace | grep ICP4ACluster |  awk -F " " '{ $1 = "" ; $2 = "" ; print $0 }' |  awk '{gsub(/^[ \t]+/,""); print $0}' | while read -r line ; do
   deleteUserManagementPod $line
   done
else
    read -p "CP4ba project : " selection
    deleteUserManagementPod $selection
fi
rm -f iam-custom-hostname.yaml

