NAME=$1
PROVIDER=$2
REGION=$3
OWNER=$4
PROJECT=$5

FILE_PATH=deployed_infra/${NAME}.yaml

cp crossplane_compositions/order/order-claim-port.yaml $FILE_PATH
yq --inplace ".metadata.name = \"${NAME}\"" $FILE_PATH
yq --inplace ".spec.resourceConfig.providerConfigName = \"${PROVIDER}\"" $FILE_PATH
yq --inplace ".spec.resourceConfig.region = \"${REGION}\"" $FILE_PATH
yq --inplace ".spec.resourceConfig.tags.ownerName = \"${OWNER}\"" $FILE_PATH
yq --inplace ".spec.resourceConfig.tags.projectName = \"${PROJECT}\"" $FILE_PATH
