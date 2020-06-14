@echo off

SET build_command=

setlocal enableextensions enabledelayedexpansion

REM Bonita version
SET BONITA_BPM_VERSION=7.8.2
SET CUSTOM_REPO=https://github.com/araguacaima
SET GIT_ASK_YESNO=false
git config --global core.longpaths true
set SCRIPT_PATH=%~dp0
echo Changing to directory '%~dp0'
CD %~dp0
SET CURRENTDIR=%~dp0

CALL :detectDependenciesVersions

REM Note: Checkout folder of bonita-engine project need to be named community.
rem CALL :build_maven_wrapper_install_maven_test_skip_with_target_directory_with_profile bonita-engine,community,"tests,javadoc"

rem CALL :build_maven_install_maven_test_skip bonita-userfilters

REM Each connectors implementation version is defined in https://github.com/bonitasoft/bonita-studio/blob/%BONITA_BPM_VERSION%/bundles/plugins/org.bonitasoft.studio.connectors/pom.xml.
REM For the version of bonita-connectors refers to one of the included connector and use the parent project version (parent project should be bonita-connectors).
REM You need to find connector git repository tag that provides a given connector implementation version.
rem CALL :build_maven_install_maven_test_skip bonita-connectors,1.0.0

rem CALL :build_maven_install_maven_test_skip bonita-connector-alfresco,2.0.1

rem CALL :build_maven_install_maven_test_skip bonita-connector-cmis,3.0.1

CALL :fix_oracle_driver

CALL :build_maven_install_maven_test_skip bonita-connector-database,1.2.2

rem CALL :build_maven_install_maven_test_skip bonita-connector-email,bonita-connector-email-impl-1.0.15

rem CALL :build_maven_install_maven_test_skip bonita-connector-googlecalendar-V3,bonita-connector-google-calendar-v3-1.0.0

rem CALL :build_maven_install_maven_test_skip bonita-connector-ldap,bonita-connector-ldap-1.0.1

rem CALL :build_maven_install_maven_test_skip bonita-connector-rest,1.0.5

rem CALL :build_maven_install_maven_test_skip bonita-connector-salesforce,1.1.2

rem CALL :build_maven_install_maven_test_skip bonita-connector-scripting,bonita-connector-scripting-20151015

rem CALL :build_maven_install_maven_test_skip bonita-connector-twitter,1.1.0-pomfixed

rem CALL :build_maven_install_maven_test_skip bonita-connector-webservice,1.1.1

REM Version is defined in https://github.com/bonitasoft/bonita-studio/blob/%BONITA_BPM_VERSION%/pom.xml
rem CALL :build_maven_install_maven_test_skip bonita-theme-builder,%THEME_BUILDER_VERSION%

REM Version is defined in https://github.com/bonitasoft/bonita-studio/blob/%BONITA_BPM_VERSION%/pom.xml
rem CALL :build_maven_install_maven_test_skip bonita-studio-watchdog,studio-watchdog-%STUDIO_WATCHDOG_VERSION%

REM bonita-web-pages is build using a specific version of UI Designer.
REM Version is defined in https://github.com/bonitasoft/bonita-web-pages/blob/%BONITA_BPM_VERSION%/build.gradle
REM FIXME: this will be removed in future release as the same version as the one package in the release will be used.
rem CALL :build_maven_install_skiptest bonita-ui-designer,1.8.28

rem CALL :build_gradle_build bonita-web-pages

REM This is the version of the UI Designer embedded in Bonita release
REM Version is defined in https://github.com/bonitasoft/bonita-studio/blob/%BONITA_BPM_VERSION%/pom.xml
rem CALL :build_maven_install_skiptest bonita-ui-designer,%UID_VERSION%

rem CALL :build_maven_install_maven_test_skip bonita-web-extensions

rem CALL :build_maven_install_skiptest bonita-web,%BONITA_BPM_VERSION%,bonita-web,%CUSTOM_REPO%

rem CALL :build_maven_install_maven_test_skip bonita-portal-js

rem CALL :build_maven_install_maven_test_skip bonita-distrib

REM Version is defined in https://github.com/bonitasoft/bonita-studio/blob/%BONITA_BPM_VERSION%/pom.xml
rem CALL :build_maven_install_maven_test_skip image-overlay-plugin,image-overlay-plugin-1.0.4

rem CALL :build_maven_wrapper_verify_maven_test_skip_with_profile bonita-studio,"mirrored,generate"

EXIT /B %ERRORLEVEL%

rem Detect version of depencies required to build Bonita components in Maven pom.xml files
:detectDependenciesVersions
  echo Detecting dependencies versions  
  SET URL=https://raw.githubusercontent.com/bonitasoft/bonita-studio/%BONITA_BPM_VERSION%/pom.xml
  set file_=%~dp0pom.xml
  curl -sS -X GET %URL% -o %file_%
  for /f "tokens=1,2 delims=" %%n in ('findstr /i /c:"<ui.designer.version>" "%file_%"') do (
	for /f "tokens=2 delims=>" %%a in ("%%n") do (
      for /f "tokens=1 delims=<" %%b in ("%%a") do (
        set UID_VERSION=%%b
	  )
    )
  )
  for /f "tokens=1,2 delims=" %%n in ('findstr /i /c:"<theme.builder.version>" "%file_%"') do (
	for /f "tokens=2 delims=>" %%a in ("%%n") do (
      for /f "tokens=1 delims=<" %%b in ("%%a") do (
        set THEME_BUILDER_VERSION=%%b
	  )
    )
  )
  for /f "tokens=1,2 delims=" %%n in ('findstr /i /c:"<watchdog.version>" "%file_%"') do (
	for /f "tokens=2 delims=>" %%a in ("%%n") do (
      for /f "tokens=1 delims=<" %%b in ("%%a") do (
        set STUDIO_WATCHDOG_VERSION=%%b
	  )
    )
  )
  del /f %file_%
  echo UID_VERSION: %UID_VERSION%
  echo THEME_BUILDER_VERSION: %THEME_BUILDER_VERSION%
  echo STUDIO_WATCHDOG_VERSION: %STUDIO_WATCHDOG_VERSION%
EXIT /B 0

REM params:
REM - Git repository name
REM - Branch name (optional)
REM - Checkout folder name (optional)
:checkout
  set argC=0
  for %%x in (%*) do Set /A argC+=1
  
  SET repository_name=%1
  
  if %argC% GEQ 2 (
    SET branch_name=%2
  ) else (
    SET branch_name=tags/%BONITA_BPM_VERSION%
  )
  SET repo=https://github.com/bonitasoft
  if %argC% EQU 3 (
    SET checkout_folder_name=%3
  ) else (
    if %argC% EQU 4 (
      SET checkout_folder_name=%3
      SET repo=%4
    ) else (
      SET checkout_folder_name=%repository_name%
      SET repo=https://github.com/bonitasoft
    )
  )
  git gc > NUL
  REM If we don't already clone the repository do it
  if NOT EXIST %~dp0%checkout_folder_name%\ (
    echo Running command: git clone %repo%/%repository_name%.git %~dp0%checkout_folder_name%
    git clone %repo%/%repository_name%.git %~dp0%checkout_folder_name%
  )

  REM Ensure we fetch all the tags and that we are on the appropriate one
  echo Running command: git -C %~dp0%checkout_folder_name% fetch --tags
  git -C %~dp0%checkout_folder_name% fetch --tags
  echo Running command: git -C %~dp0%checkout_folder_name% checkout /f %branch_name%
  git -C %~dp0%checkout_folder_name% checkout /f %branch_name%
  
  REM Move to the repository clone folder (required to run Maven wrapper)
  echo Changing to directory '%~dp0%checkout_folder_name%'
  cd %~dp0%checkout_folder_name%
  SET CURRENTDIR=%~dp0%checkout_folder_name%
EXIT /B 0

:fix_oracle_driver
  rmdir /q /s %SCRIPT_PATH%bonita-connector-database
  echo Downloading artifacts to be added manually into Maven .m2 repo
  curl -sS -X GET http://www.datanucleus.org/downloads/maven2/oracle/ojdbc6/11.2.0.3/ojdbc6-11.2.0.3.pom -o %SCRIPT_PATH%ojdbc6-11.2.0.3.pom
  curl -sS -X GET http://www.datanucleus.org/downloads/maven2/oracle/ojdbc6/11.2.0.3/ojdbc6-11.2.0.3.jar -o %SCRIPT_PATH%ojdbc6-11.2.0.3.jar 
  echo Downloaded %SCRIPT_PATH%ojdbc6-11.2.0.3.pom
  echo Downloaded %SCRIPT_PATH%ojdbc6-11.2.0.3.jar 
  echo Installing artifact manally into Maven .m2 repo
  echo mvn install:install-file -DgroupId=com.oracle -DartifactId=ojdbc6 -Dversion=11.2.0.3 -Dpackaging=jar -Dfile=%SCRIPT_PATH%ojdbc6-11.2.0.3.jar -DpomFile=%SCRIPT_PATH%ojdbc6-11.2.0.3.pom
  call mvn install:install-file -DgroupId=com.oracle -DartifactId=ojdbc6 -Dversion=11.2.0.3 -Dpackaging=jar -Dfile=%SCRIPT_PATH%ojdbc6-11.2.0.3.jar -DpomFile=%SCRIPT_PATH%ojdbc6-11.2.0.3.pom
  
  SET MAVEN_LOCAL_REPO_SETTINGS_TEMP=temp.dat
  call mvn help:effective-settings > %MAVEN_LOCAL_REPO_SETTINGS_TEMP%
  
  for /f "tokens=1,2 delims=" %%n in ('findstr /i /c:"<localRepository>" "%MAVEN_LOCAL_REPO_SETTINGS_TEMP%"') do (
  	for /f "tokens=2 delims=>" %%a in ("%%n") do (
        for /f "tokens=1 delims=<" %%b in ("%%a") do (
          SET MAVEN_LOCAL_REPO_SETTINGS=%%b
  	    )
      )
    )
    
  del /S /F %MAVEN_LOCAL_REPO_SETTINGS_TEMP%
  for /f "delims=" %%a in ('dir /b/s %MAVEN_LOCAL_REPO_SETTINGS%\com\oracle\ojdbc6\*_remote.repositories') do del /f /q "%%a"
  for /f "delims=" %%a in ('dir /b/s %MAVEN_LOCAL_REPO_SETTINGS%\com\oracle\ojdbc6\*maven-metadata-local.xml') do del /f /q "%%a"
  echo Deleting downloaded artifacts
  del /f %SCRIPT_PATH%ojdbc6-11.2.0.3.jar
  del /f %SCRIPT_PATH%ojdbc6-11.2.0.3.pom
  echo Arfitacts deleted
EXIT /B 0

:run_maven_with_standard_system_properties
  SET build_command=%build_command% -Dbonita.engine.version=%BONITA_BPM_VERSION% -Dp2MirrorUrl=http://update-site.bonitasoft.com/p2/7.7
  echo Running command: %build_command%
  rem echo %build_command% > execute.cmd
  rem call execute.cmd
  call %build_command%
  rem del /f execute.cmd
  REM Go back to script folder (checkout move current dirrectory to project checkout folder.
  cd ..
  echo Changed to directory '%cd%'
EXIT /B 0

:run_gradle_with_standard_system_properties
  SET build_command=%build_command% -Dbonita.engine.version=%BONITA_BPM_VERSION% -Dp2MirrorUrl=http://update-site.bonitasoft.com/p2/7.7
  echo Running command: %build_command%
  %build_command%
  REM Go back to script folder (checkout move current dirrectory to project checkout folder.
  cd ..
  echo Changed to directory '%cd%'
EXIT /B 0

:build_maven
  rem SET build_command="mvn --quiet"
  SET build_command=mvn
EXIT /B 0

:build_maven_wrapper
  rem SET build_command="mvnw --quiet"
  SET build_command=mvnw
EXIT /B 0

:build_gradle_wrapper
  SET build_command=gradlew
EXIT /B 0

:build
  SET build_command=%build_command% build
EXIT /B 0

:publishToMavenLocal
  SET build_command=%build_command% publishToMavenLocal
EXIT /B 0

:clean
  SET build_command=%build_command% clean
EXIT /B 0

:install
  SET build_command=%build_command% install
EXIT /B 0

:verify
  SET build_command=%build_command% verify
EXIT /B 0

:maven_javadocs_skip
  SET build_command=%build_command% -Dmaven.javadoc.skip=true
EXIT /B 0  

:maven_test_skip
  SET build_command=%build_command% -Dmaven.test.skip=true
EXIT /B 0

:skiptest
  SET build_command=%build_command% -DskipTests
EXIT /B 0

:profile
  SET build_command=%build_command% -P%1
EXIT /B 0

REM params:
REM - Git repository name
REM - Branch name (optional)
:build_maven_install_maven_test_skip
  CALL :checkout %*
  CALL :build_maven
  CALL :install
  CALL :maven_test_skip
  CALL :maven_javadocs_skip
  CALL :run_maven_with_standard_system_properties
EXIT /B 0

REM FIXME: should not be used
REM params:
REM - Git repository name
REM - Branch name (optional)
:build_maven_install_skiptest
  CALL :checkout %*
  CALL :build_maven
  CALL :install
  CALL :skiptest
  CALL :maven_javadocs_skip
  CALL :run_maven_with_standard_system_properties
EXIT /B 0

REM params:
REM - Git repository name
REM - Profile name
:build_maven_wrapper_verify_maven_test_skip_with_profile
  CALL :checkout %1
  CALL :build_maven_wrapper
  CALL :verify
  CALL :maven_test_skip
  CALL :maven_javadocs_skip
  CALL :profile %2
  CALL :run_maven_with_standard_system_properties
EXIT /B 0

REM params:
REM - Git repository name
REM - Target directory name
REM - Profile name
:build_maven_wrapper_install_maven_test_skip_with_target_directory_with_profile
  CALL :checkout %1 %BONITA_BPM_VERSION% %2
  CALL :build_maven_wrapper
  CALL :install  
  CALL :maven_test_skip
  CALL :maven_javadocs_skip
  CALL :profile %3
  CALL :run_maven_with_standard_system_properties
EXIT /B 0

:build_gradle_build
  CALL :checkout %*
  CALL :build_gradle_wrapper
  CALL :publishToMavenLocal
  CALL :run_gradle_with_standard_system_properties
EXIT /B 0

:end