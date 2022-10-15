reInteger='^[0-9]+$'
red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`
expirationTime="200m"

################### Wait that pod is running ###########

WaitUntilPodRun(){
POD=$1
shift; shift;
podName="$($POD | awk 'NR==2' | awk '{ print $1 }')"
echo " Wait the status for the pod :$podName to run ${reset}"
while true; do

     statusPod="$($POD | awk 'NR==2' | awk '{ print $3 }')"
     CurrentNb="$($POD | awk 'NR==2' | awk '{ print $2 }' | grep -oP "\d{1}" |  awk 'NR==1')"
     TargetNB="$($POD |  awk 'NR==2' | awk '{ print $2 }' | grep -oP "\d{1}" |  awk 'NR==2')"
     if [[ $CurrentNb = $TargetNB ]] && [[ "$statusPod" == "Running" ]]; then break; fi
     echo "${red} Current Status : $statusPod for  $CurrentNb/$TargetNB ${reset}"
     sleep 2
done
 echo "${green} the pod $podName is $statusPod with $CurrentNb/$TargetNB ${reset}"
}


################### Clean File ##########################

CleanFile()
{
    startBlock=$1
    stopBlock=$2
    temFileClean=$3
    ouputFileClean=$4
    shift; shift;
     # init the tempfile
    cp $ouputFileClean $temFileClean
    rm -f $ouputFileClean
    removeField=false
    while IFS= read -r line
     do
        if [[ "$line" == "$startBlock"* ]] ;then
        removeField=true;
        fi
        if [ ! -z "$stopBlock" ] && [[ "$line" == "$stopBlock"* ]]; then
        removeField=false;
        fi
        if [[  $removeField = false ]]; then
        echo "$line" >> $ouputFileClean
        fi
     done < "$temFileClean"
     rm -f $temFileClean
}


echo "List all the ICP4A project "
oc get ICP4ACluster --all-namespaces | awk 'NR>1' | awk '{ print $1 }'

######## Collect information ##############

read -p "Get Project name : " project
if [ -z "$project" ]; then
	echo "error: project can't be empty"; exit 1
else	
	rm -rf ./$project
fi

depName="$(oc get ICP4ACluster -n $project | awk 'NR>1' | awk '{ print $1 }')"
echo "Deployement name ${red}${depName}${reset}"
############# Common-Services ###################

read -p "Common service name (by default ibm-common-services) : " commonService
if [ -z "$commonService" ]; then
	commonService=ibm-common-services	
fi

echo "The common service that will be use is ${red}$commonService${reset}"

##############   Expiration Time #######################

echo "Please provide the time in minutes, the minimum is 60 minutes"
read -p "Expiration time (60) : " expirationTime
if [ -z "$expirationTime" ]; then expirationTime=60; fi
if ! [[ $expirationTime =~ $reInteger ]] ; then
   echo "error: Expiration time not a number"; exit 1
fi
read -p "Token refresh (60): " refreshToken
if [ -z "$refreshToken" ]; then refreshToken=60; fi 
if ! [[ $refreshToken =~ $reInteger ]] ; then
   echo "error: Refresh token is not a number"; exit 1
fi

################ Update IAM configuration ################### 

read -p "Update the IAM authentication (default n : other value y/n) : " iamUpdate 
if [ -z "$iamUpdate" ]; then iamUpdate=n; fi

#######################  Update or View mode ###############

read -p "Update or view (u/v) (default is view): " update

if [[ "$update"  == "u"  ]] ; then
	echo "${red} The script will update the current configuration and restart the required pod ${reset}"
else
	echo "${green} The script will present the configuration, no modification will be applied ${reset}"
fi


##################### Calcul Section ######################


ExpirationTimeInHour=$(($expirationTime/60))
RefreshTokenInHour=$(($refreshToken/60))
ExpirationTimeInSecond=$(($expirationTime*60))
RefreshTokenInSecond=$(($refreshToken*60))

if [[ "$ExpirationTimeInHour" -lt 1 ||  "$RefreshTokenInHour" -lt 1 ]] 
then 
    RefreshTokenInHour=2
    ExpirationTimeInHour=1
    echo "The minimum is not reached setup auto to 60";
fi

###############################################################
########################## ZEN ################################
###############################################################


echo "---- ZEN UPDATE ---"

curenZenExp="$(oc get configmap product-configmap -o jsonpath=\"{.data.TOKEN_EXPIRY_TIME}\")"
curenZenTokExp="$(oc get configmap product-configmap -o jsonpath=\"{.data.TOKEN_REFRESH_PERIOD}\")"


if [ "${curenZenExp}" == '""' ]; then curenZenExp= ; fi
if [ "${curenZenTokExp}" == '""' ]; then curenZenTokExp= ; fi

mkdir -p ./$project/zen
oc project $project
oc get configmap product-configmap -o  yaml > ./$project/zen/product-config.yaml 


input="./$project/zen/product-config.yaml"
output="./$project/zen/product-config-extended.yaml"
temp="./$project/zen/product-config-extended-t.yaml"


echo "Update Zen with the new parameter(old value/new value)" 
echo " TOKEN_EXPIRY_TIME:$curenZenExp/$ExpirationTimeInSecond TOKEN_REFRESH_PERIOD:$curenZenTokExp/${RefreshTokenInHour}h "

if [[ "$curenZenExp" == '"'$ExpirationTimeInSecond'"' ]] && [[ "$curenZenTokExp" == '"'${RefreshTokenInHour}'h"'   ]] ; then 

	echo "The Zen configuration is the same not modifcation applied"

else 

	while IFS= read -r line
	do
	      SUB='data:'
	      if [[ "$line" == "$SUB"*  ]]; then
	        echo "$line" >> $output
	        if [ -z "$curenZenExp" ]; then
	           echo "TOKEN_EXPIRY_TIME does not exist and add it "
	           echo '  TOKEN_EXPIRY_TIME: "'$ExpirationTimeInSecond'"' >> $output
	        fi
	        if [ -z "$curenZenTokExp" ]; then
	           echo "TOKEN_REFRESH_PERIOD does not exist and add it "
	           echo '  TOKEN_REFRESH_PERIOD: "'$RefreshTokenInHour'h"' >> $output
	        fi
	      else
	        if [ ! -z "$curenZenExp"  ] && [[ "$line" == "  TOKEN_EXPIRY_TIME:"*  ]]; then
	           echo "TOKEN_EXPIRY_TIME does exist and modify it "
	           echo '  TOKEN_EXPIRY_TIME: "'$ExpirationTimeInSecond'"' >> $output
	         elif [ ! -z "$curenZenTokExp" ] && [[  "$line" == "  TOKEN_REFRESH_PERIOD:"* ]]; then
	           echo "TOKEN_REFRESH_PERIOD does exist and modify it "
	           echo '  TOKEN_REFRESH_PERIOD: "'$RefreshTokenInHour'h"' >> $output
	        else
	         echo "$line" >> $output
	         fi
	      fi
	done < "$input"
	
	SUBp='  managedFields:'
	SUBn='  name:'
	CleanFile "$SUBp" "$SUBn" $temp $output
	CleanFile "$SUBp" "$SUBn" $temp $input
	CleanFile "  ownerReferences:" "" $temp $output
	CleanFile "  ownerReferences:" "" $temp $output


	## apply zen modiciation 
	if [[ "$update"  == "u"  ]] ; then 
	 diff $input $output
         read -p "please press enter to apply or any caractere to skip: " skipTst
	 if [ -z "$skipTst" ]; then 
	 oc apply -f $output --overwrite=true
	 oc delete pod -l component=usermgmt
	 WaitUntilPodRun "oc get pod -l component=usermgmt"
         fi
	else 
	 echo "${green} View the ZEN Configuration ${reset}"
	 diff $input $output
	 echo "-----------------------------------------" 	
	fi
	read -p "please press enter to continue" toto
fi

#############################################################
########################## IAM ##############################
#############################################################

if [[ "$iamUpdate" == "y" ]] ; then

echo "---- IAM UPDATE --- "
mkdir -p ./$project/iam

oc -n kube-system get configmap platform-auth-idp -o yaml > ./$project/iam/platform-auth-idp.yaml

currentIAMExp="$(oc -n kube-system get configmap platform-auth-idp -o jsonpath=\"{.data.SESSION_TIMEOUT}\")"
currentIAMTokExp="$(oc -n kube-system get configmap platform-auth-idp -o jsonpath=\"{.data.IDTOKEN_LIFETIME}\")"

if [ "${currentIAMExp}" == '""' ]; then currentIAMExp= ; fi
if [ "${currentIAMTokExp}" == '""' ]; then currentIAMTokExp= ; fi

echo " IAM current configuration currentIAMExp:$currentIAMExp currentIAMTokExp:$currentIAMTokExp"

input="./$project/iam/platform-auth-idp.yaml"
output="./$project/iam/platform-auth-idp-extended.yaml"
temp="./$project/iam/platform-auth-idp-extended-t.yaml"

	while IFS= read -r line
	do
     	SUB='data:'
      	if [[ "$line" == "$SUB"*  ]]; then
        	echo "$line" >> $output
        	if [ -z "$currentIAMExp" ]; then
           	echo "SESSION_TIMEOUT does not exist and add it "
           	echo '  SESSION_TIMEOUT: "'$ExpirationTimeInHour'h"' >> $output
        	fi
        	if [ -z "$currentIAMTokExp" ]; then
           	echo "IDTOKEN_LIFETIME does not exist and add it "
           	echo '  IDTOKEN_LIFETIME: "'$RefreshTokenInHour'h"' >> $output
        	fi
      else
        	if [ ! -z "$currentIAMExp"  ] && [[ "$line" == "  SESSION_TIMEOUT:"*  ]]; then
           	echo "SESSION_TIMEOUT does exist and modify it "
           	echo '  SESSION_TIMEOUT: "'$RefreshTokenInHour'h"' >> $output
         	elif [ ! -z "$currentIAMTokExp" ] && [[  "$line" == "  IDTOKEN_LIFETIME:"* ]]; then
           	echo "IDTOKEN_LIFETIME does exist and modify it "
           	echo '  IDTOKEN_LIFETIME: "'$RefreshTokenInHour'h"' >> $output
        	else
         	echo "$line" >> $output
        	 fi
	fi
	done < "$input"

	SUBp='  managedFields:'
	SUBn='  name: platform-auth-idp'
	CleanFile "$SUBp" "$SUBn" $temp $output
        CleanFile "$SUBp" "$SUBn" $temp $input
	## Apply IAM Modication 

	if [[ "$update"  == "u"  ]] ; then
                diff $input $output
                read -p "please press enter to apply or any caractere to skip: " skipTst
                if [ -z "$skipTst" ]; then
		echo "${red} We adapt the IAM configuration${reset}"
	 	oc apply -f $output --overwrite=true
	 	echo "${red}Delete the auth-idp pod${reset}"	
	 	oc -n $commonService delete pod -l component=auth-idp
                WaitUntilPodRun "oc -n $commonService get pod -l component=auth-idp"
                fi
	else
	 	echo "${green} View the IAM Configuration ${reset}"
	 	diff $input $output
		echo "-----------------------------------------"
	fi
      read -p "please press enter to continue" toto
else 
	echo '--- IAM SKIPPED --- '
fi

####################################################
####################### Liberty ##############################
##############################################################
############### BAN, CPE, GraphQL, CMIS, #####################
##############################################################

IsComponentDeployed(){
        key=$1
        shift; shift;
        result=$(oc get pod -l app=$depName-$key-deploy)
        if [  -z "$result"  ] ; then
                echo "no resources found for $key";
                return 1;
        else
                echo "$key found"
                return 0;
        fi
}

UpdateCustomLTPAxml()
{
   
   key=$1
   shift; shift;
   echo "-- update the component $key" 
   # Having shifted twice, the rest is now comments ...
   pod="$( oc get pod -l app=$depName-$key-deploy | awk 'NR==2' | awk '{ print $1 }')"
   echo "the current pod is ${green} $pod ${reset}"
   if [[ ! -z "$pod" ]]; then
   	mkdir -p ./$project/$key	
   	echo "Update the Custom-xml file for $key for the project $project"
   	echo "check the following pod : $pod"
   	oc rsync $pod:/opt/ibm/wlp/usr/servers/defaultServer/configDropins/overrides/ibm_custom-ltpa.xml ./$project/$key/
   	cp ./$project/$key/ibm_custom-ltpa.xml ./$project/$key/z_custom-ltpa.xml
   	echo `sed -i "s/expiration=\"[[:alnum:]]*\"/expiration=\"$expirationTime\"/g" ./$project/$key/z_custom-ltpa.xml`
   else 
      echo "pod not found for the component: $key"
   fi
  
   if [[ "$update"  == "u"  ]] ; then
          echo "${red} We adapt the $key configuration${reset}"
         diff ./$project/$key/z_custom-ltpa.xml ./$project/$key/ibm_custom-ltpa.xml

         read -p "please press enter to apply or any caractere to skip: " skipTst
	if [ -z "$skipTst" ]; then 
         echo `oc -n $project get pod | grep $key`
          oc cp ./$project/$key/z_custom-ltpa.xml  $pod:/opt/ibm/wlp/usr/servers/defaultServer/configDropins/overrides/
	  oc delete pod -l app=$depName-$key-deploy
          WaitUntilPodRun "oc get pod -l app=$depName-$key-deploy"
	fi
    else
          echo "${green} View the $key Configuration ${reset}"
          #cat ./$project/$key/z_custom-ltpa.xml
          diff ./$project/$key/z_custom-ltpa.xml ./$project/$key/ibm_custom-ltpa.xml
	  echo "-----------------------------------------"
   fi
   read -p "please press enter to continue" toto
}

if IsComponentDeployed cpe ; then UpdateCustomLTPAxml cpe ; fi
if IsComponentDeployed navigator ; then UpdateCustomLTPAxml navigator ; fi
if IsComponentDeployed graphql ; then UpdateCustomLTPAxml graphql ; fi
if IsComponentDeployed cmis ; then UpdateCustomLTPAxml cmis ; fi

##############################################################
####################### Liberty ##############################
##############################################################
################# BAW, JMS, PFS ##############################
##############################################################

mkdir -p ./$project/cr
mkdir -p ./$project/secrets/
mkdir -p ./$project/baw
mkdir -p ./$project/jms
mkdir -p ./$project/pfs


inputCR="./$project/cr/cr.yaml"
tempCR="./$project/cr/cr-temp.yaml"
outputCR="./$project/cr/cr-updated.yaml"
cleanCR="./$project/cr/cr-clean.yaml"
bawxml="./$project/baw/zz_custom.xml"
jmsxml="./$project/jms/zz_custom.xml"
pfsxml="./$project/pfs/zz_custom.xml"


deployment="$(oc get icp4acluster | head -2 | tail -1 | head -n1 | cut -d " " -f1)"
echo "deploy is ${green}${deployment} ${reset}"
oc get icp4acluster $deployment -o yaml >> $inputCR
cp $inputCR $outputCR


#####################  Clean CR file ########################


insertElementinCRAfter()
{
        tokenSearch=$1
        replaceValue=$2
        shift; shift;
        while IFS= read -r line
        do
          if [[ "$line" == "$tokenSearch" ]] ; then
            echo "$line" >> "$tempCR"
            echo "$replaceValue" >> "$tempCR"
        else
             echo "$line" >> "$tempCR"
        fi
        done < "$outputCR"
        cp $tempCR $outputCR
        rm -f $tempCR
}

removeXMLSectionFromCR()
{
        tokenSearch=$1
        shift; shift;
        rm -f "$tempCR"
        removeSection=false
        while IFS= read -r line
        do
          if [[ "$line" == "$tokenSearch"* ]] ; then
            echo "$line" >> "$tempCR"
            removeSection=true
        else
             if [[ "$removeSection" == "true" ]]; then
                if [[ "$line" == *"</server>"* ]] ; then removeSection=false ; fi
             else
                echo "$line" >> "$tempCR"
             fi

        fi
        done < "$outputCR"
        echo "closing field $removeSection"
	cp $tempCR $outputCR
        rm -f $tempCR
}

insertXMLSectionFromFile()
{
        tokenSearch=$1
        fileInput=$2
        shift; shift;
        rm -f "$tempCR"
        removeSection=false
        while IFS= read -r line
        do
          if [[ "$line" == "$tokenSearch"* ]] ; then
            echo "$line" >> "$tempCR"
                while IFS2= read -r lines
                do
                echo "     $lines" >> "$tempCR"
                done < "$fileInput"
          else
             echo "$line" >> "$tempCR"
        fi
        done < "$outputCR"
        cp $tempCR $outputCR
        rm -f $tempCR
}

ReplaceCRValue()
{
        tokenSearch=$1
        replacedValue=$2
	shift; shift;
        rm -f "$tempCR"
	echo "Clean CR Null value pfs"
        while IFS= read -r line
        do
          if [[ "$line" == "$tokenSearch" ]] ; then
            echo "$replacedValue" >> "$tempCR"
            echo "${red} Null has been Found${reset}" 
          else
             echo "$line" >> "$tempCR"
        fi
        done < "$outputCR"
        cp $tempCR $outputCR
        rm -f $tempCR
}

removeField=false
SUB='status:'
SUB1='  annotations:'
SUB2='  labels:'
SUB3='  managedFields:'
SUB4='  name:'
SUB5="  resourceVersion:"
SUB6="spec:"

echo "${green}Start Clean CR${reset}"


CleanFile "$SUB1" "$SUB2" $tempCR $outputCR
CleanFile "$SUB3" "$SUB4" $tempCR $outputCR
CleanFile "$SUB5" "$SUB6" $tempCR $outputCR
CleanFile "$SUB" "" $tempCR $outputCR

cp $outputCR $cleanCR

echo "${green}Download and Cleaning cr done${reset}"

deplPattern="{.spec.shared_configuration.sc_deployment_patterns}"
pattern="$(oc get icp4acluster $deployment -o jsonpath=$deplPattern)"
deplPattern="{.spec.shared_configuration.sc_optional_components}"
subpattern="$(oc get icp4acluster $deployment -o jsonpath=$deplPattern)"
echo "subpattern : $subpattern"

CreateXMLCR(){
        component=$1
        shift; shift;
        xmlCustom=
        secretCustom=
        updateCR=false
        #retrieve current config depending of component
        echo "Retrieve the timout configuration for ${red}$component${reset}"
        if [ "$component" == "baw" ]; then
                if [[ "$subpattern" == *"baw_authoring"* ]]; then
                        echo "BAW authoring pattern detected"
                        secretCustom="$(oc get icp4acluster $deployment -o jsonpath=\"{.spec.workflow_authoring_configuration.custom_xml_secret_name}\")"
                        xmlCustom="$(oc get icp4acluster $deployment -o jsonpath=\"{.spec.workflow_authoring_configuration.liberty_custom_xml}\")"
                else
                        echo "BAW Server pattern detected"
                       secretCustom="$(oc get icp4acluster $deployment -o jsonpath=\"{.spec.baw_configuration[0].custom_xml_secret_name}\")"
                       xmlCustom="$(oc get icp4acluster $deployment -o jsonpath=\"{.spec.baw_configuration[0].liberty_custom_xml}\")"
                       bawInstanceName="$(oc get icp4acluster $deployment -o jsonpath=\"{.spec.baw_configuration[0].name}\")"
                fi
        elif [ "$component" == "pfs" ]; then
                secretCustom="$(oc get icp4acluster $deployment -o jsonpath=\"{.spec.pfs_configuration.config_dropins_overrides_secret}\")"
        fi

        # check if we received an empty string
        if [ "${#secretCustom}" == 2 ]; then
        secretCustom=
        fi
        if [ "${#xmlCustom}" == 2 ]; then
         xmlCustom=
        fi

        if [  -z "$secretCustom" ] && [  -z "$xmlCustom" ] && [[ ! "$component" == "pfs"  ]]; then
           echo "For the component baw, there is no custom xml or secret for liberty"
           read -p "Do you want to created as secret or xml inline in the cr ? (secret or cr)  " typeModi
           echo "Modification type ${green}$typeModi${reset}"
           updateCR=true
        elif [ ! -z "$xmlCustom" ]; then
          echo "We are going to update the xml inside the CR "
          typeModi=cr
        else
          echo "We are going to update the secret $secretCustom"
          typeModi=secret
	  updateCR=true
        fi


        # Save current xml configuration

        if [ "$typeModi" == "secret" ]; then
              if [ -z "$secretCustom" ]; then
                # Get current configuration
                xmlCustom="$(oc get secret $secretCustom -o jsonpath={.data.sensitiveCustomConfig} | base64 --decode)"
                echo "$xmlCustom" > "$project/$component/zz_original.xml"
                cp  "$project/$component/zz_original.xml"  "$project/$component/zz_updated.xml"
             else
                secretCustom=$component-mj-custom-liberty
                cp template/custom.xml "$project/$component/zz_updated.xml"
             fi
        else
              if [ ! -z "$xmlCustom" ]; then
                #Remove the " from the Json output
                xmlCustom="${xmlCustom:1}"
                xmlCustom=${xmlCustom::-1}
                echo "$xmlCustom" > "$project/$component/zz_original.xml"
                cp  "$project/$component/zz_original.xml"  "$project/$component/zz_updated.xml"
              else
                echo "add to the CR the required information "
                cp template/custom.xml "$project/$component/zz_updated.xml"
             fi
        fi


        authCache='<authCache'
        invalidationTimeout="invalidationTimeout"
        ltpa="<ltpa"
        while IFS= read -r line
        do
         if [[ "$line" == *"$authCache"* ]]; then
                authCache="Isthere"
         fi
        if [[ "$line" == *"$invalidationTimeout"* ]]; then
                invalidationTimeout="Isthere"
         fi
        if [[ "$line" == *"$ltpa"* ]]; then
                ltpa="Isthere"
         fi
        done < "$project/$component/zz_updated.xml"

        while IFS= read -r line
        do
         if [[ "$line" == "<server>" ]]; then
                echo "$line" >> "$project/$component/zz_updated-t.xml"
                if [[ ! "$authCache" == "Isthere" ]]; then echo "<authCache timeout=\"120m\"/>" >> "$project/$component/zz_updated-t.xml" ; fi
                if [[ ! "$invalidationTimeout" == "Isthere" ]]; then echo "<httpSession   cookieSecure=\"true\"   invalidationTimeout=\"120m\"   invalidateOnUnauthorizedSessionRequestException=\"true\" />" >> "$project/$component/zz_updated-t.xml" ; fi
                if [[ ! "$ltpa" == "Isthere" ]]; then echo "<ltpa expiration=\"120m\" />" >> "$project/$component/zz_updated-t.xml" ; fi

        else
                echo "$line" >> "$project/$component/zz_updated-t.xml"
        fi

        done < "$project/$component/zz_updated.xml"

        cp $project/$component/zz_updated-t.xml $project/$component/zz_updated.xml
        rm -f $project/$component/zz_updated-t.xml

        ## Adapt the xml with the timeout values
        echo `sed -i "s/timeout=\"[[:alnum:]]*\"/timeout=\"$expirationTime\"/g" $project/$component/zz_updated.xml`
        echo `sed -i "s/invalidationTimeout=\"[[:alnum:]]*\"/invalidationTimeout=\"$expirationTime\"/g" $project/$component/zz_updated.xml`
        echo `sed -i "s/expiration=\"[[:alnum:]]*\"/expiration=\"$expirationTime\"/g" $project/$component/zz_updated.xml`

        if [ "$typeModi" == "secret" ] && [[ "$update"  == "u" ]] ; then
                echo "${green} create secret for the component $component${reset} with the name : $secretCustom"
                if [ "$component" == baw ]; then oc create secret generic $secretCustom --from-file=sensitiveCustomConfig=$project/$component/zz_updated.xml; fi
                if [ "$component" == pfs ]; then
                        if [[ -z "$secretCustom" ]];  then
                        secretCustom=$component-mj-custom-liberty
                        updateCR=true
                        else
                        oc delete secret $secretCustom
                        fi
                        oc create secret generic $secretCustom --from-file=zz-custom.xml=$project/$component/zz_updated.xml;
                fi
        elif [[ ! "$update"  == "u" ]]; then
          echo "${green} For the $component: ${reset}"
          cat $project/$component/zz_updated.xml
          echo "-----------------------------------------"
 
        fi
if [ "$component" == pfs ]; then if [[ -z "$secretCustom" ]];  then secretCustom=$component-mj-custom-liberty ;fi;fi
        if [[ "$typeModi" == "cr"  ]]; then
                echo "$component update cr with xml section $xmlCustom"

		 if grep -q " liberty_custom_xml:" "$outputCR"; then 
                	removeXMLSectionFromCR "    liberty_custom_xml:"
                	insertXMLSectionFromFile "    liberty_custom_xml:" $project/$component/zz_updated.xml
                 else
			if [[ "$subpattern" == *"baw_authoring"* ]]; then
                              insertElementinCRAfter "  workflow_authoring_configuration:" "    liberty_custom_xml: |+"
                         else
                              insertElementinCRAfter "  - name: $bawInstanceName" "    liberty_custom_xml: |+"
                         fi
			insertXMLSectionFromFile "    liberty_custom_xml:" $project/$component/zz_updated.xml
		fi
        elif [[ "$updateCR" == "true" ]]; then
        echo "We will update the CR for the component $component" 
	       if [[ "$component" == "baw" ]]; then
                     if grep -q " custom_xml_secret_name:" "$outputCR"; then
                                echo `sed -i "s/ custom_xml_secret_name:/ custom_xml_secret_name:$secretCustom/g" $outputCR`
                     else
                                 if [[ "$subpattern" == *"baw_authoring"* ]]; then
                                        insertElementinCRAfter "  workflow_authoring_configuration:" "    custom_xml_secret_name: $secretCustom"
                                 else
                                        insertElementinCRAfter "  - name: $bawInstanceName" "    custom_xml_secret_name: $secretCustom"
                                 fi

                        fi
                else
                        if grep -q "config_dropins_overrides_secret:" "$outputCR"; then
                                 if ! grep -q "$secretCustom" "$outputCR"; then 
				echo `sed -i "s/ config_dropins_overrides_secret:/ config_dropins_overrides_secret: $secretCustom/g" $outputCR`; fi;
                        else
                                 if grep -q " pfs_configuration:" "$outputCR"; then
                                        ReplaceCRValue "  pfs_configuration: null" "  pfs_configuration:"
					insertElementinCRAfter "  pfs_configuration:" "    config_dropins_overrides_secret: $secretCustom"
                                 else
                                        echo "  pfs_configuration:" >> "$outputCR"
                                        echo "    config_dropins_overrides_secret: $secretCustom" >> "$outputCR"
                                 fi

                        fi
                fi
                echo "Update the CR with the secret name for $component : $secretCustom"
        else
                echo "CR has not be touched but the secret updated"
        fi


}

CreateXMLCR baw
read -p "please press enter to continue" toto
CreateXMLCR pfs
read -p "please press enter to continue" toto


if [[ "$update"  == "u"  ]] ; then
          echo "${red} We apply the new CR${reset}"
          diff  $outputCR $cleanCR
  	  read -p "please press enter to apply or any caractere to skip: " skipTst
	  if [ -z "$skipTst" ]; then	
          	echo `oc -n $project apply -f $outputCR --overwrite=true`
          	echo "The new CR has been applied"
          	oc delete pod -l name=ibm-cp4a-operator
          	WaitUntilPodRun "oc get pod -l name=ibm-cp4a-operator"
	fi
else
          echo "${green} View the new CR has been updated : $outputCR ${reset}"
          diff  $outputCR $cleanCR 
          echo "-----------------------------------------"
fi
read -p "please press enter to continue" toto
