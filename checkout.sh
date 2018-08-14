#/bin/bash
## Usage: ./checkout.sh <project> <branch>
##
## Build a Docker image for the given project and branch and switch Docker Compose
## to the newly built image. For the change to take effect, the command
## `./compose-frontend.sh up -d` must be run.
##
## Options:
##    - project: Name of the project (= compose service). Must be one of:
##        ccd-data-store-api, ccd-definition-store-api, ccd-user-profile-api,
##        ccd-api-gateway or ccd-case-management-web
##    - branch: Existing remote branch for the given project.
##

TAGS_FILE=".tags.env"
WORKSPACE_ROOT=".workspace"
GRADLE_ASSEMBLE_CMD="./gradlew assemble"

project=$1
branch=$2

# Validate mandatory parameters
if [ -z "$project" ]
  then
    echo "Usage: ./checkout.sh <project> <branch>"
    exit 1
fi

if [ -z "$branch" ]
  then
    echo "Usage: ./checkout.sh <project> <branch>"
    exit 1
fi

# Initialise script for given project
case $project in
  ccd-data-store-api)
    repository="git@github.com:hmcts/ccd-data-store-api.git"
    tagEnv="CCD_DATA_STORE_API_TAG"
    buildCommand=$GRADLE_ASSEMBLE_CMD
    ;;
  ccd-definition-store-api)
    repository="git@github.com:hmcts/ccd-definition-store-api.git"
    tagEnv="CCD_DEFINITION_STORE_API_TAG"
    buildCommand=$GRADLE_ASSEMBLE_CMD
    ;;
  ccd-user-profile-api)
    repository="git@github.com:hmcts/ccd-user-profile-api.git"
    tagEnv="CCD_USER_PROFILE_API_TAG"
    buildCommand=$GRADLE_ASSEMBLE_CMD
    ;;
  ccd-api-gateway)
    repository="git@github.com:hmcts/ccd-api-gateway.git"
    tagEnv="CCD_API_GATEWAY_TAG"
    ;;
  ccd-case-management-web)
    repository="git@github.com:hmcts/ccd-case-management-web.git"
    tagEnv="CCD_CASE_MANAGEMENT_WEB_TAG"
    ;;
  *)
    echo "Project must be one of: ccd-data-store-api, ccd-definition-store-api, ccd-user-profile-api, ccd-api-gateway, ccd-case-management-web"
    exit 1 ;;
esac

# When `master` branch, reset tag
if [ $branch == "master" ]
  then
    touch $TAGS_FILE
    sed -i '' "/$tagEnv/d" $TAGS_FILE
    exit 0
fi

# Prepare workspace
workspace="$WORKSPACE_ROOT/$project"

rm -rf $workspace
mkdir -p $workspace

# Checkout project's branch
git clone --branch $branch $repository $workspace

gitHash=$(cd $workspace && git rev-parse HEAD)

# Build project artefacts required by Dockerfile
if [ -n "$buildCommand" ]
  then
    (cd $workspace && eval $buildCommand)
fi

# Build Docker image
(cd $workspace && docker build . -t hmcts/$project:$gitHash)

# Set image tag in `.tags.env` file
touch $TAGS_FILE
sed -i '' "/$tagEnv/d" $TAGS_FILE
echo "export $tagEnv=$gitHash" >> $TAGS_FILE