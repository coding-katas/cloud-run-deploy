E2E_RUN=cloud-run-deploy
ROOT_DIR=$(git rev-parse --show-toplevel)
E2E_RUN_DIR=~/${E2E_RUN}
CD_CONFIG_DIR=${E2E_RUN_DIR}/clouddeploy-config
TF_DIR=${E2E_RUN_DIR}/terraform-config
GCLOUD_CONFIG=clouddeploy

APP_CONFIG_DIR=${E2E_RUN_DIR}/app-config

export PROJECT_ID=$(gcloud config get-value core/project)
export REGION=us-central1

BACKEND=${PROJECT_ID}-${E2E_RUN}-tf

manage_apis() {
    # Enables any APIs that we need prior to Terraform being run

    echo "Enabling GCP APIs, please wait, this may take several minutes..."
    echo "Storage API"...
    gcloud services enable storage.googleapis.com
    echo "Compute API"...
    gcloud services enable compute.googleapis.com
    echo "Artifact Registry API"...
    gcloud services enable artifactregistry.googleapis.com
}

manage_configs() {
    # Sets any SDK configs and ensures they'll persist across
    # Cloud Shell sessions

    echo "Creating persistent Cloud Shell configuration"
    SHELL_RC=${HOME}/.$(basename ${SHELL})rc
    echo export CLOUDSDK_CONFIG=${HOME}/.gcloud >> ${SHELL_RC}

    if [[ $(gcloud config configurations list --quiet --filter "name=${GCLOUD_CONFIG}") ]]; then
      echo "Config ${GCLOUD_CONFIG} already exists, skipping config creation"
    else
      gcloud config configurations create ${GCLOUD_CONFIG}
      echo "Created config ${GCLOUD_CONFIG}"
    fi

    gcloud config set project ${PROJECT_ID}
    gcloud config set compute/region ${REGION}
    gcloud config set deploy/region ${REGION}
    gcloud config set run/platform managed
    gcloud config set run/region ${REGION}
}

run_terraform() {
    # Terraform workflows

    cd ${TF_DIR}

    sed "s/bucket=.*/bucket=\"$BACKEND\"/g" main.template > main.tf
    gsutil mb gs://${BACKEND} || true

    terraform init
    terraform plan -out=terraform.tfplan -var="project_id=${PROJECT_ID}" -var="region=${REGION}"
    terraform apply -auto-approve terraform.tfplan
}

configure_git() {
  # Ensures some base level git client config is present

  git config user.name "Cloud Deploy"
  git config user.email "noreply@google.com"
}

e2e_apps() {
    # Any sample application install and configuration for the E2E walkthrough.

    echo "Configuring walkthrough applications"

    cd ${CD_CONFIG_DIR}
    for template in $(ls *.template); do
        envsubst < ${template} > ${template%.*}
    done

    cd ${APP_CONFIG_DIR}
    for template in $(ls *.template); do
        envsubst < ${template} > ${template%.*}
    done

    git tag -a v1 -m "version 1 release"
}

manage_apis
manage_configs
run_terraform
configure_git
e2e_apps
