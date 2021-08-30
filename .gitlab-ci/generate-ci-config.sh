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
  TF_IMAGE_REPOSITORY: ghcr.io/camptocamp/terraform
  TF_IMAGE_TAG: 1.0.5

.init-gpg: &init-gpg |
  uid=$(bash -c 'gpg --with-colons --import-options import-show --import --quiet <(echo "$GPG_SECRET_KEY")'|grep ^uid:|sed -n 's/.*<\(.*\)>.*/\1/p')
  cp -a ~/.gnupg .

.init-gopass: &init-gopass |
  gopass init "$uid"
  gopass clone "$PASSWORD_STORE_URL" terraform
  cp -a ~/.password-store .
  cp -a ~/.config .
  cp -a ~/.local .

.init-ssh: &init-ssh |
  mkdir -p ~/.ssh
  gopass $SSH_KEY_SECRET_PATH id_rsa > ~/.ssh/id_rsa
  gopass $SSH_KEY_SECRET_PATH id_rsa.pub > ~/.ssh/id_rsa.pub
  chmod 0600 ~/.ssh/id_rsa
  ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts
  cp -a ~/.ssh .

setup-gopass:
  stage: build
  image:
    name: camptocamp/summon-gopass
  script:
    - *init-gpg
    - *init-gopass
    - *init-ssh
  artifacts:
    paths:
      - .gnupg
      - .password-store
      - .config
      - .local
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
      - https://raw.githubusercontent.com/camptocamp/terraform-gitlabci-pipelines/master/.gitlab-ci/terraform-pipeline.yaml
    strategy: depend
EOT
if [ "$PARENT_PIPELINE_SOURCE" != "schedule" ]; then
	cat << EOT
  rules:
    - changes:
        - "$tf_root/*"
EOT
fi
done
