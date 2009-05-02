#include <iostream>
#include <unistd.h>
#include <vector>

#include <common.hpp>
#include <workload.hpp>
#include <job.hpp>
#include <simpleresource.hpp>
#include <resourcepool.hpp>
#include <schedule.hpp>
#include <workload-factory.hpp>
#include <reportwriter.hpp>
#include <schedulearchive.hpp>

void printHelp() {
  std::cout << "PAES Scheduler" << std::endl;
  std::cout << "Mandatory commandline parameters:" << std::endl;
  std::cout << " -i <FILE>: Specify input file" << std::endl;
  std::cout << " -o <FILE>: Specify output file" << std::endl;
}

int main (int argc, char** argv) {
  // Parse the commandline parameters using getopt
  bool verbose=false;
  char *inputfile = NULL;
  char *outputfile = NULL;
  int c;

  opterr = 0;
  while ((c = getopt (argc, argv, "hvi:o:")) != -1)
	switch (c) {
	  case 'h':
		printHelp();
		exit(0);
		break;
	  case 'v':
		verbose = true;
		break;
	  case 'i':
		inputfile = optarg;
		break;
	  case 'o':
		outputfile = optarg;
		break;
	  case '?':
		if (optopt == 'i')
		  fprintf (stderr, "Option -%c requires an argument.\n", optopt);
		else if (optopt == 'o')
		  fprintf (stderr, "Option -%c requires an argument.\n", optopt);
		else if (isprint (optopt))
		  fprintf (stderr, "Unknown option `-%c'.\n", optopt);
		else
		  fprintf (stderr,
			  "Unknown option character `\\x%x'.\n",
			  optopt);
		return 1;
	  default:
		abort ();
	}

  if (inputfile == NULL) {
	std::cerr << "No input file specified - aborting." << std::endl;
	exit(-1);
  } else {
	std::cout << "Using input file " << inputfile << std::endl;
  }

  if (outputfile == NULL) {
	std::cerr << "No output file specified - aborting." << std::endl;
	exit(-1);
  } else {
	std::cout << "Writing results to " << outputfile << std::endl;
  }


  // Load Workload.
  scheduler::FileWorkloadFactory fwFactory(inputfile);
  scheduler::Workload::Ptr workload=fwFactory.parseWorkload();
  if (verbose)
	std::cout << workload->str() << std::endl;
  else {
	std::cout << "Workload contains job ids: "<<std::endl;
	std::vector<scheduler::Job::IDType> jobIDs=workload->getJobIDs();
	std::vector<scheduler::Job::IDType>::iterator it;
	for( it = jobIDs.begin(); it < jobIDs.end(); it++) {
	  std::cout << *it << " ";
	}
	std::cout << std::endl;
  }

  // Build Resources.
  scheduler::ResourcePool::Ptr resources(new scheduler::ResourcePool());
  std::cout << "Creating 3 simple resources." << std::endl;
  for(unsigned int i=0; i<3; i++) {
	std::ostringstream oss;
	oss << "Resource-" << i;
	scheduler::SimpleResource::Ptr resource(new scheduler::SimpleResource(i, oss.str()));
	resources->add(resource);
  }

  // Archive for the schedules.
  scheduler::ScheduleArchive::Ptr archive(new scheduler::ScheduleArchive());

  // Build the schedule
  scheduler::Schedule::Ptr schedule(new scheduler::Schedule(workload, resources));
  std::cout << "Created " << schedule->str() << std::endl;
  std::cout << "# schedule: " << schedule->str() << std::endl;
  std::cout << "Total QT: " << schedule->getTotalQueueTime() << ", price: " << schedule->getTotalPrice() << std::endl;

  std::cout << "# Random schedule " << std::endl;
  schedule->randomSchedule();
  std::cout << "# resources " << resources->str() << std::endl;
  std::cout << "# schedule: " << schedule->str() << std::endl;
  //std::cout << "Total QT: "  <<schedule->getTotalQueueTime() << ", price: " << schedule->getTotalPrice() << std::endl;

  std::cout << "schedule: propagate" << std::endl;
  schedule->propagateJobsToResources();
  std::cout << "# resources " << resources->str() << std::endl;
  std::cout << "# schedule: " << schedule->str() << std::endl;

  std::cout << "# process schedule + make copy" << std::endl;
  schedule->processSchedule(); 
  std::cout << "# resources " << resources->str() << std::endl;
  std::cout << "# schedule: " << schedule->str() << std::endl;
  std::cout << "Total QT: " << schedule->getTotalQueueTime() << ", price: " << schedule->getTotalPrice() << std::endl;
 // resources->sanityCheck();
  
  std::cout << "# make copy" << std::endl;
  scheduler::Schedule::Ptr scheduleCopy(new scheduler::Schedule(*schedule));
  std::cout << "# resources " << resources->str() << std::endl;
  std::cout << "# scheduleCopy: " << scheduleCopy->str() << std::endl;

  std::cout << "# remove all jobs from schedule" << std::endl;
  schedule->removeAllJobs();
  std::cout << "# resources " << resources->str() << std::endl;
  std::cout << "# schedule: " << schedule->str() << std::endl;
  std::cout << "Total QT: " << schedule->getTotalQueueTime() << ", price: " << schedule->getTotalPrice() << std::endl;
  std::cout << "# schedule: " << schedule->str() << std::endl;
  resources->sanityCheck();
  
  std::cout << "--- Copy of schedule" << std::endl;
  std::cout << "# resources " << resources->str() << std::endl;
  std::cout << "# scheduleCopy: " << scheduleCopy->str() << std::endl;
  std::cout << "Total QT: " << scheduleCopy->getTotalQueueTime() << ", price: " << scheduleCopy->getTotalPrice() << std::endl;
  //scheduleCopy->propagateJobsToResources();
  
  std::cout << "scheduleCopy: propagate" << std::endl;
  scheduleCopy->propagateJobsToResources();
  std::cout << "# resources " <<  resources->str() << std::endl;
  std::cout << "# scheduleCopy: " << scheduleCopy->str() << std::endl;

  std::cout << "scheduleCopy: process" << std::endl;
  schedule->processSchedule(); 
  std::cout << "# resources " <<  resources->str() << std::endl;
  std::cout << "# scheduleCopy: " << scheduleCopy->str() << std::endl;
  std::cout << "Total QT: " << scheduleCopy->getTotalQueueTime() << ", price: " << scheduleCopy->getTotalPrice() << std::endl;
  std::cout << "# scheduleCopy: " << scheduleCopy->str() << std::endl;

  std::cout << scheduleCopy->getAllocationTable() << std::endl;
  scheduleCopy->mutate();
  std::cout << scheduleCopy->getAllocationTable() << std::endl;

  std::cout << "Archive: " << archive->str() << std::endl;
  archive->addSchedule(schedule);
  archive->addSchedule(scheduleCopy);
  std::cout << "Archive: " << archive->str() << std::endl;

  std::cout << "Loglines from archive:" << std::endl;
  std::cout << archive->getLogLines() << std::endl;

  //util::ReportWriter::Ptr reporter(new util::ReportWriter("foo.txt"));
  //reporter->addHeaderLine("headerfoo");
  //reporter->addReportLine("line1)");
  //reporter->addReportLine("line2)");
  //reporter->writeReport();
  return 0;
}

