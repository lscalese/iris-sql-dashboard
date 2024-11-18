# Description: This script is executed after the IRIS instance has been started.
# Add your own commands to this file to customize the startup of your IRIS instance.
iris session $ISC_PACKAGE_INSTANCENAME -U USER <<- END
; Do \$SYSTEM.OBJ.LoadDir("/home/irisowner/dev/src/dc/sqlstats/","ck", , 1)
; set system mode as development
Do ##class(%SYSTEM.Version).SystemMode("DEVELOPMENT")
Halt
END

exit 0