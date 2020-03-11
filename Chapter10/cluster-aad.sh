#Set variables to be used later.
EXISTINGAKSNAME="handsonaks"
NEWAKSNAME="handsonaks-aad"
RGNAME="rg-handsonaks"
LOCATION="westus2"
TENANTID=$(az account show --query tenantId -o tsv)

# Get SP from existing cluster and create new password
RBACSP=$(az aks show -n $EXISTINGAKSNAME -g $RGNAME --query servicePrincipalProfile.clientId -o tsv)
RBACSPPASSWD=$(openssl rand -base64 32)
az ad sp credential reset --name $RBACSP --password $RBACSPPASSWD --append

# Create the Azure AD application
serverApplicationId=$(az ad app create \
    --display-name "${NEWAKSNAME}Server" \
    --identifier-uris "https://${NEWAKSNAME}Server" \
    --query appId -o tsv)

# Update the application group memebership claims
az ad app update --id $serverApplicationId --set groupMembershipClaims=All

# Create a service principal for the Azure AD application
az ad sp create --id $serverApplicationId

# Get the service principal secret
serverApplicationSecret=$(az ad sp credential reset \
    --name $serverApplicationId \
    --credential-description "AKSPassword" \
    --query password -o tsv)

az ad app permission add \
    --id $serverApplicationId \
    --api 00000003-0000-0000-c000-000000000000 \
    --api-permissions e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope \
    06da0dbc-49e2-44d2-8312-53f166ab848a=Scope \
    7ab1d382-f21e-4acd-a863-ba3e13f7da61=Role
az ad app permission grant --id $serverApplicationId \
    --api 00000003-0000-0000-c000-000000000000
#if running in cloud shell, you need to grand admin consent manually
echo "#######################################################################################################"
echo "#  Please browse to https://portal.azure.com/#blade/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/CallAnAPI/appId/$serverApplicationId/isMSAApp/ and grant admin consen#"
echo "#  It take can take a minute for the consent button to become availalbe. If the button is not available, please wait and try the URL above again.                           "
echo "#  Hit enter once you have granted admin consent."
echo "#######################################################################################################"
read RANDOM

#if not running in cloud shell, you can use az cli to grand the admin consent.
#az ad app permission admin-consent --id  $serverApplicationId


clientApplicationId=$(az ad app create \
    --display-name "${NEWAKSNAME}Client" \
    --native-app \
    --reply-urls "https://${NEWAKSNAME}Client" \
    --query appId -o tsv)

az ad sp create --id $clientApplicationId
oAuthPermissionId=$(az ad app show --id $serverApplicationId \
    --query "oauth2Permissions[0].id" -o tsv)
az ad app permission add --id $clientApplicationId \
    --api $serverApplicationId --api-permissions \
    $oAuthPermissionId=Scope
az ad app permission grant --id $clientApplicationId \
    --api $serverApplicationId

az aks create \
    --resource-group $RGNAME \
    --name $NEWAKSNAME \
    --location $LOCATION \
    --node-count 1 \
    --node-vm-size Standard_D1_v2 \
    --generate-ssh-keys \
    --aad-server-app-id $serverApplicationId \
    --aad-server-app-secret $serverApplicationSecret \
    --aad-client-app-id $clientApplicationId \
    --aad-tenant-id $TENANTID \
    --service-principal $RBACSP \
    --client-secret $RBACSPPASSWD

az aks get-credentials --resource-group $RGNAME --name $NEWAKSNAME --admin

