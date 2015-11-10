
UCANACCESS_HOME=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
echo $UCANACCESS_HOME

CLASSPATH="$UCANACCESS_HOME/lib/hsqldb.jar:$UCANACCESS_HOME/lib/jackcess-2.1.2.jar:$UCANACCESS_HOME/lib/commons-lang-2.6.jar:$UCANACCESS_HOME/lib/commons-logging-1.1.1.jar:$UCANACCESS_HOME/ucanaccess-3.0.2.jar"

if [ -d "$JAVA_HOME" -a -x "$JAVA_HOME/bin/java" ]; then
	JAVACMD="$JAVA_HOME/bin/java"
else
	JAVACMD=java
fi

"$JAVACMD" -cp $CLASSPATH net.ucanaccess.console.Main
