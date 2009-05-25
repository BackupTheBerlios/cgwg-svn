CC=g++
CFLAGS=-c -Wall -I. -std=gnu++98 -pedantic -fPIC -g
#LDFLAGS=-static
LDFLAGS=
SOURCES=main.cpp workload.cpp workload-factory.cpp job.cpp 
SOURCES+=simpleresource.cpp schedule.cpp random.cpp resourcepool.cpp
SOURCES+=allocation.cpp reportwriter.cpp schedulearchive.cpp
OBJECTS=$(SOURCES:.cpp=.o)
EXECUTABLE=paes-scheduler

all: $(SOURCES) $(EXECUTABLE)
	
$(EXECUTABLE): $(OBJECTS)
	$(CC) $(LDFLAGS) $(OBJECTS) -o $@

# GCC autodepend-fu
.cpp.o:
	$(CC) $(CFLAGS) -MD $< -o $@
	@sed -i 's,\($*\.o\)[ :]*\(.*\),$@ : $$\(wildcard \2\)\n\1 : \2,g' $*.d
	
.PHONY: clean
clean:
	rm -f $(OBJECTS) $(EXECUTABLE) *.d

-include $(SOURCES:.cpp=.d)
