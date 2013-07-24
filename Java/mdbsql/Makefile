
WRAPPER_HOME=..

CFLAGS=-I$(JAVA_HOME)/include \
       -I$(JAVA_HOME)/include/linux \
       `pkg-config --cflags glib-2.0`

LDFLAGS=-lmdb -lmdbsql

default:
	javah -classpath $(WRAPPER_HOME)/bin \
		-o mdbsql_wrapper.h \
		org.imos.ddb.MDBSQLDDB
	gcc -shared -fPIC -o libmdbsql_wrapper.so $(CFLAGS) $(LDFLAGS) mdbsql_wrapper.c

clean:
	rm -f mdbsql_wrapper.h
	rm -f libmdbsql_wrapper.so
	rm -f $(WRAPPER_HOME)/libmdbsql_wrapper.so
	
install:
	cp libmdbsql_wrapper.so $(WRAPPER_HOME)/
