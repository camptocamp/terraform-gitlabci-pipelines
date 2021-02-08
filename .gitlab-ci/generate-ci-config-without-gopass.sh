#!/bin/sh

cat << 'EOT'
workflow:
  rules:
    - if: $CI_MERGE_REQUEST_IID
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
    - if: $PARENT_PIPELINE_SOURCE == "schedule"

variables:
  PARENT_PIPELINE_ID: $CI_PIPELINE_ID
  ROOT_PIPELINE_SOURCE: $ROOT_PIPELINE_SOURCE
  TF_IMAGE_REPOSITORY: camptocamp/terraform
  TF_IMAGE_TAG: 0.13.6

.init-ssh: &init-ssh |
  mkdir -p ~/.ssh
  echo $TERRAFORM_SSH_KEY id_rsa > ~/.ssh/id_rsa
  chmod 0600 ~/.ssh/id_rsa
  ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts
  cp -a ~/.ssh .

setup-ssh:
  stage: build
  image:
    name: camptocamp/summon-gopass
  script:
    - *init-ssh
  artifacts:
    paths:
      - .ssh
EOT

find . -type f -name "*.tf" -print0 | xargs -0 grep -wl -E '^\s+backend\s+"[^"]+"\s+\{' | while read -r dir; do
tf_root=$(dirname "$dir" | sed -e "s/^\.\///g")
workspace=$(echo "$tf_root" | sed -e "s@^\./@@"| tr "/" "_")

cat << EOT

$workspace:
  stage: test
  variables:
    TF_ROOT: "$tf_root"
  trigger:
    include:
      - https://raw.githubusercontent.com/camptocamp/terraform-gitlabci-pipelines/master/.gitlab-ci/terraform-pipeline-without-gopass.yaml
    strategy: depend
EOT
if [ "$PARENT_PIPELINE_SOURCE" != "schedule" ]; then
	cat << EOT
  rules:
    - changes:
        - "$tf_root/**/*"
EOT
fi
done
