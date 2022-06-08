#! /bin/bash

declare LOCATION
declare COMMAND
declare JAVACMD
declare LOCALCLASSPATH
declare LIBDIR

LOCATION=$0
LOCATION=${LOCATION%/*}

if [ -z "$JAVA_HOME" ] ; then
  echo "ERROR: JAVA_HOME environment variable is not set."
  exit
else
  if [ -x "$JAVA_HOME/jre/sh/java" ] ; then
    # IBM's JDK on AIX uses strange locations for the executables
    JAVACMD=$JAVA_HOME/jre/sh/java
  else
    JAVACMD=$JAVA_HOME/bin/java
  fi
fi

if [ ! -x "$JAVACMD" ] ; then
  echo "Error: JAVA_HOME is not defined correctly."
  echo "  We cannot execute $JAVACMD"
  exit
fi

LOCALCLASSPATH=$JAVA_HOME/lib/tools.jar:$JAVA_HOME/lib/classes.zip

# add in the dependency .jar files from the lib directory
LIBDIR=$LOCATION/lib
LIBS=$LIBDIR/*.jar
for i in $LIBS
do
    # if the directory is empty, then it will return the input string
    # this is stupid, so case for it
    if [ "$i" != "${LIBS}" ] ; then
        LOCALCLASSPATH=$LOCALCLASSPATH:"$i"
    fi
done

# Add in the classpath bean dependencies
LOCALCLASSPATH=$LOCALCLASSPATH":../../mdx"

# Add in the ukf-mda version to use
LOCALCLASSPATH=$LOCALCLASSPATH":../../tools/ukf-mda/ukf-mda-0.9.12-SNAPSHOT.jar"

echo "Classpath: $LOCALCLASSPATH"

"$JAVACMD" '-classpath' "$LOCALCLASSPATH" $JVMOPTS 'net.shibboleth.metadata.cli.SimpleCommandLine' "$@"