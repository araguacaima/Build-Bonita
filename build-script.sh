#/bin/bash

set -u
set -e

# Bonita version
BONITA_BPM_VERSION=7.8.2

# Test that Maven exists
if hash mvn 2>/dev/null; then
  MAVEN_VERSION="$(mvn --version 2>&1 | awk -F " " 'NR==1 {print $3}')"
  echo Using Maven version: "$MAVEN_VERSION"
else
  echo Maven not found. Exiting.
  exit 1
fi

# Test if Curl exists
if hash curl 2>/dev/null; then
  CURL_VERSION="$(curl --version 2>&1  | awk -F " " 'NR==1 {print $2}')"
  echo Using curl version: "$CURL_VERSION"
else
  echo curl not found. Exiting.
  exit 1
fi


# Detect version of depencies required to build Bonita components in Maven pom.xml files
detectDependenciesVersions() {
  echo "Detecting dependencies versions"
  local studioPom=`curl -sS -X GET https://raw.githubusercontent.com/bonitasoft/bonita-studio/${BONITA_BPM_VERSION}/pom.xml`

  UID_VERSION=`echo "${studioPom}" | grep ui.designer.version | sed 's@.*>\(.*\)<.*@\1@g'`
  THEME_BUILDER_VERSION=`echo "${studioPom}" | grep theme.builder.version | sed 's@.*>\(.*\)<.*@\1@g'`
  STUDIO_WATCHDOG_VERSION=`echo "${studioPom}" | grep watchdog.version | sed 's@.*>\(.*\)<.*@\1@g'`

  echo "UID_VERSION: ${UID_VERSION}"
  echo "THEME_BUILDER_VERSION: ${THEME_BUILDER_VERSION}"
  echo "STUDIO_WATCHDOG_VERSION: ${STUDIO_WATCHDOG_VERSION}"
}


# List of repositories on https://github.com/bonitasoft that you don't need to build:
#
# angular-strap: automatically downloaded in the build of bonita-web project.
# babel-preset-bonita: automatically downloaded in the build of bonita-ui-designer project.
# bonita-branding: used to be required by Bonita Studio. Deprecated.
# bonita-codesign-windows: use to sign Windows binaries when building using Bonita Continuous Integration.
# bonita-connector-drools: Drools connector is not included in an official release.
# bonita-connector-googlecalendar: deprecated replaced by bonita-connector-googlecalendar-V3.
# bonita-connector-mongodb: not released.
# bonita-connector-sugarcrm: deprecated.
# bonita-connector-talend: deprecated.
# bonita-connectors-assembly: previous solution to build connectors in Bonita Studio 6. Deprecated.
# bonita-connectors-packaging: previous solution to build connectors in Bonita Studio 6. Deprecated.
# bonita-continuous-delivery-doc: Bonita Enterprise Edition Continuous Delivery module documentation.
# bonita-custom-page-seed: a project to start building a custom page. Deprecated in favor of UI Designer page + REST API extension.
# bonita-doc: Bonita documentation.
# bonita-developer-resources: guidelines for contributing to Bonita, contributor license agreement, code style...
# bonita-examples: Bonita usage code examples.
# bonita-gwt-tools: deprecated.
# bonita-ici-doc: Bonita Enterprise Edition AI module documentation.
# bonita-jboss-h2-mbean: JBoss has been replaced by WildFly.
# bonita-js-components: automatically downloaded in the build of projects that require it.
# bonita-migration: migration tool to update a server from a previous Bonita release.
# bonita-migration-plugins: archive repository, code now in bonita-migration repository.
# bonita-page-authorization-rules: documentation project to provide an example for page mapping authorization rule.
# bonita-platform: deprecated, now part of bonita-engine repository.
# bonita-connector-sap: deprecated. Use REST connector instead.
# bonita-simulation: deprecated.
# bonita-tomcat-h2-listener: h2 is now launched in an independent JVM.
# bonita-tomcat-valve: deprecated, was useful for JBoss bundle embedded Tomcat.
# bonita-vacation-management-example: an example for Bonita Enterprise Edition Continuous Delivery module.
# bonita-web-devtools: Bonitasoft internal development tools.
# bonita-widget-contrib: project to start building custom widgets outside UI Designer.
# create-react-app: required for Bonita Subscription Intelligent Continuous Improvement module.
# dojo: Bonitasoft R&D coding dojos.
# jscs-preset-bonita: Bonita JavaScript code guidelines.
# ngUpload: automatically downloaded in the build of bonita-ui-designer project.
# preact-chartjs-2: required for Bonita Subscription Intelligent Continuous Improvement module.
# preact-content-loader: required for Bonita Subscription Intelligent Continuous Improvement module.
# restlet-framework-java: /!\
# sandbox: a sandbox for developers /!\ (private ?)
# swt-repo: legacy repository required by Bonita Studio. Deprecated.
# tomcat-atomikos: experimentation with a different transaction manager on Tomcat. Not part of an official release.
# tomcat-narayana: experimentation with a different transaction manager on Tomcat. Not part of an official release.
# training-presentation-tool: fork of reveal.js with custom look and feel.
# widget-builder: automatically downloaded in the build of bonita-ui-designer project.

# params:
# - Git repository name
# - Branch name (optional)
# - Checkout folder name (optional)
checkout() {
  if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
     echo "Incorrect number of parameters: $@"
     exit 1
  fi

  repository_name="$1"
  
  if [ "$#" -ge 2 ]; then
    branch_name="$2"
  else
    branch_name=$BONITA_BPM_VERSION
  fi
    
  if [ "$#" -eq 3 ]; then
    checkout_folder_name="$3"
  else
    # If no checkout folder path is provided use the repository name as destination folder name
    checkout_folder_name="$repository_name"
  fi
  
  # If we don't already clone the repository do it
  if [ ! -d "$checkout_folder_name/.git" ]; then
    echo Running command: git clone "https://github.com/bonitasoft/$repository_name.git" $checkout_folder_name
    git clone "https://github.com/bonitasoft/$repository_name.git" $checkout_folder_name
  fi
  # Ensure we fetch all the tags and that we are on the appropriate one
  echo Running command: git -C $checkout_folder_name fetch --tags
  git -C $checkout_folder_name fetch --tags
  echo Running command: git -C $checkout_folder_name reset --hard tags/$branch_name
  git -C $checkout_folder_name reset --hard tags/$branch_name
  
  # Move to the repository clone folder (required to run Maven wrapper)
  cd $checkout_folder_name
}

run_maven_with_standard_system_properties() {
  build_command="$build_command -Dbonita.engine.version=$BONITA_BPM_VERSION -Dp2MirrorUrl=http://update-site.bonitasoft.com/p2/7.7"
  echo Running command: $build_command
  eval "$build_command"
  # Go back to script folder (checkout move current dirrectory to project checkout folder.
  cd ..
}

# FIXME: -Puid-version
run_gradle_with_standard_system_properties() {
  build_command="$build_command -Dbonita.engine.version=$BONITA_BPM_VERSION -Dp2MirrorUrl=http://update-site.bonitasoft.com/p2/7.7"
  echo Running command: $build_command
  eval "$build_command"
  # Go back to script folder (checkout move current dirrectory to project checkout folder.
  cd ..
}

build_maven() {
  build_command="mvn --quiet"
}

build_maven_wrapper() {
  # FIXME: remove temporary workaround added for bonita-web
  chmod u+x mvnw
  build_command="./mvnw --quiet"
}

build_gradle_wrapper() {
  chmod u+x gradlew
  build_command="./gradlew"
}

build() {
  build_command="$build_command build"
}

publishToMavenLocal() {
  build_command="$build_command publishToMavenLocal"
}

clean() {
  build_command="$build_command clean"
}

install() {
  build_command="$build_command install"
}

verify() {
  build_command="$build_command verify"
}

maven_test_skip() {
  build_command="$build_command -Dmaven.test.skip=true"
}

skiptest() {
  build_command="$build_command -DskipTests"
}

profile() {
  build_command="$build_command -P$1"
}

# params:
# - Git repository name
# - Branch name (optional)
build_maven_install_maven_test_skip() {
  checkout "$@"
  build_maven
  install
  maven_test_skip
  run_maven_with_standard_system_properties
}

# FIXME: should not be used
# params:
# - Git repository name
# - Branch name (optional)
build_maven_install_skiptest() {
  checkout "$@"
  build_maven
  install
  skiptest
  run_maven_with_standard_system_properties
}

# params:
# - Git repository name
# - Profile name
build_maven_wrapper_verify_maven_test_skip_with_profile()
{
  checkout $1
  build_maven_wrapper
  verify
  maven_test_skip
  profile $2
  run_maven_with_standard_system_properties
}

# params:
# - Git repository name
# - Target directory name
# - Profile name
build_maven_wrapper_install_maven_test_skip_with_target_directory_with_profile()
{
  checkout $1 $BONITA_BPM_VERSION $2
  build_maven_wrapper
  install  
  maven_test_skip
  profile $3
  run_maven_with_standard_system_properties
}

build_gradle_build() {
  checkout "$@"
  build_gradle_wrapper
  publishToMavenLocal
  run_gradle_with_standard_system_properties
}

# 1s detect the versions of dependencies that will be built prior to build the Bonita Components
detectDependenciesVersions


# Note: Checkout folder of bonita-engine project need to be named community.
build_maven_wrapper_install_maven_test_skip_with_target_directory_with_profile bonita-engine community tests,javadoc

build_maven_install_maven_test_skip bonita-userfilters

# Each connectors implementation version is defined in https://github.com/bonitasoft/bonita-studio/blob/$BONITA_BPM_VERSION/bundles/plugins/org.bonitasoft.studio.connectors/pom.xml.
# For the version of bonita-connectors refers to one of the included connector and use the parent project version (parent project should be bonita-connectors).
# You need to find connector git repository tag that provides a given connector implementation version.
build_maven_install_maven_test_skip bonita-connectors 1.0.0

build_maven_install_maven_test_skip bonita-connector-alfresco 2.0.1

build_maven_install_maven_test_skip bonita-connector-cmis 3.0.1

build_maven_install_maven_test_skip bonita-connector-database 1.2.2

build_maven_install_maven_test_skip bonita-connector-email bonita-connector-email-impl-1.0.15

build_maven_install_maven_test_skip bonita-connector-googlecalendar-V3 bonita-connector-google-calendar-v3-1.0.0

build_maven_install_maven_test_skip bonita-connector-ldap bonita-connector-ldap-1.0.1

build_maven_install_maven_test_skip bonita-connector-rest 1.0.5

build_maven_install_maven_test_skip bonita-connector-salesforce 1.1.2

build_maven_install_maven_test_skip bonita-connector-scripting bonita-connector-scripting-20151015

build_maven_install_maven_test_skip bonita-connector-twitter 1.1.0-pomfixed

build_maven_install_maven_test_skip bonita-connector-webservice 1.1.1

# Version is defined in https://github.com/bonitasoft/bonita-studio/blob/$BONITA_BPM_VERSION/pom.xml
build_maven_install_maven_test_skip bonita-theme-builder ${THEME_BUILDER_VERSION}

# Version is defined in https://github.com/bonitasoft/bonita-studio/blob/$BONITA_BPM_VERSION/pom.xml
build_maven_install_maven_test_skip bonita-studio-watchdog studio-watchdog-${STUDIO_WATCHDOG_VERSION}

# bonita-web-pages is build using a specific version of UI Designer.
# Version is defined in https://github.com/bonitasoft/bonita-web-pages/blob/$BONITA_BPM_VERSION/build.gradle
# FIXME: this will be removed in future release as the same version as the one package in the release will be used.
build_maven_install_skiptest bonita-ui-designer 1.8.28

build_gradle_build bonita-web-pages

# This is the version of the UI Designer embedded in Bonita release
# Version is defined in https://github.com/bonitasoft/bonita-studio/blob/$BONITA_BPM_VERSION/pom.xml
build_maven_install_skiptest bonita-ui-designer ${UID_VERSION}

build_maven_install_maven_test_skip bonita-web-extensions

build_maven_install_skiptest bonita-web

build_maven_install_maven_test_skip bonita-portal-js

build_maven_install_maven_test_skip bonita-distrib

# Version is defined in https://github.com/bonitasoft/bonita-studio/blob/$BONITA_BPM_VERSION/pom.xml
build_maven_install_maven_test_skip image-overlay-plugin image-overlay-plugin-1.0.4

build_maven_wrapper_verify_maven_test_skip_with_profile bonita-studio mirrored,generate
