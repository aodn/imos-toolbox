
JAVA_HOME=/usr/lib/jvm/java-6-sun
WRAPPER_HOME=..

CFLAGS=-I$(JAVA_HOME)/include \
			 -I$(JAVA_HOME)/include/linux \
			 -I/usr/include/glib-2.0 \
			 -I/usr/lib/glib-2.0/include

LDFLAGS=-lmdbsql

default:
	javah -classpath $(WRAPPER_HOME)/bin \
		-o mdbsql_wrapper.h \
		org.imos.ddb.MDBSQLDDB
	gcc -shared -o libmdbsql_wrapper.so $(CFLAGS) $(LDFLAGS) mdbsql_wrapper.c

clean:
	rm -f mdbsql_wrapper.h
	rm -f libmdbsql_wrapper.so
	rm -f $(WRAPPER_HOME)/bin/libmdbsql_wrapper.so
	
install:
	cp libmdbsql_wrapper.so $(WRAPPER_HOME)/bin
