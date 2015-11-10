@echo off
set PATH=%PATH%;.
set BASE_DIR=%~f0
:CONT
SET RMVD=%BASE_DIR:~-1%
SET BASE_DIR=%BASE_DIR:~0,-1%
if NOT "%RMVD%"=="\" goto CONT
SET UCANACCESS_HOME=%BASE_DIR%
SET LOCAL_HOME_JAVA="%JAVA_HOME%"


if exist "%LOCAL_HOME_JAVA%\bin\java.exe" (
  SET LOCAL_JAVA=%LOCAL_HOME_JAVA%\bin\java.exe
) else (
  SET LOCAL_JAVA=java.exe
)



SET CLASSPATH="%UCANACCESS_HOME%\lib\hsqldb.jar;%UCANACCESS_HOME%\lib\jackcess-2.1.2.jar;%UCANACCESS_HOME%\lib\commons-lang-2.6.jar;%UCANACCESS_HOME%\lib\commons-logging-1.1.1.jar;%UCANACCESS_HOME%\ucanaccess-3.0.2.jar"

"%LOCAL_JAVA%" -classpath %CLASSPATH% net.ucanaccess.console.Main
pause