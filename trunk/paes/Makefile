CC=g++
CFLAGS=-c -Wall -I. -std=gnu++98 -pedantic -fPIC
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

.cpp.o:
	$(CC) $(CFLAGS) $< -o $@

clean:
	rm -f $(OBJECTS) $(EXECUTABLE)

