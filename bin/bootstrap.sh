#!/usr/bin/env bash
# Sample bootstrap script
#set -x

if ! kubectl cluster-info; then
    echo "It looks like your cluster is not running or kubectl is not configured"
    exit 1
fi


secretName="git-ssh-key"

echo "Checking for the secret ${secretName}"

if ! kubectl get secret --namespace "${NAMESPACE}" "${secretName}"; then
    echo "No ${secretName} secret found for accessing git. A secret will be created for you that allows"
    echo "public read only access to the forgeops-init repo. To create your own secret use "
    echo "the following command to generate a secret:"
    echo "ssh-keygen -t rsa -C \"forgeopsrobot@forgrock.com\" -f id_rsa -N ''"
    echo "The id_rsa.pub file should be uploaded to github or stash and set as an API key to your Git configuration"
    echo "Create the Kubernetes secret using the private key:"
    echo "kubectl create secret generic "${secretName}" --from-file=id_rsa"

    kubectl create secret generic "${secretName}" --from-file=id_rsa

fi


CUSTOM_YAML=config/custom.yaml

# If there is a conf/custom.yaml present, then use it, otherwise create a default one:
if [ ! -r "${CUSTOM_YAML}" ]; then
    echo "I can't find custom.yaml values for the helm chart deployment. I will create a sample one for you"

    CUSTOM_YAML=/tmp/custom.yaml
    DOMAIN=.example.com
    REPO="quay.io/forgerock"

    cat > ${CUSTOM_YAML} <<EOF
global:
  domain: ${DOMAIN}
  git:
    repo: "https://stash.forgerock.org/scm/cloud/forgeops-init.git"
    branch: master
  configPath:
    idm:  default/idm/sync-with-ldap-bidirectional
    am:   default/am/empty-import
    ig:   default/ig/basic-sample
  exportPath:
    am: default/am/dev
EOF

fi

CHART=cmp-platform

# If we are running from the forgeops project directory, use the charts in the project.
if [ -r "helm/${CHART}" ]; then
 CHART="helm/${CHART}"
fi

if [ ! -r ${CHART} ]; then
  echo "Can not find local chart, using the forgeops chart repo"
  CHART="forgerock/${CHART}"
fi

echo "Using ${CUSTOM_YAML} values:"

cat "${CUSTOM_YAML}"


echo "Running helm..."


helm install -f "${CUSTOM_YAML}" "${CHART}"

