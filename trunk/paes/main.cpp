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
#include <linearpricing.hpp>


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
  long MAX_ITERATION=10;

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
	scheduler::PricingPlan::Ptr simplePricing(new scheduler::LinearPricing(0.1*(i+1)));
	scheduler::SimpleResource::Ptr resource(new scheduler::SimpleResource(i, oss.str(), simplePricing));
	resources->add(resource);
  }

  // Archive for the schedules.
  scheduler::ScheduleArchive::Ptr archive(new scheduler::ScheduleArchive());

  // 1. generate initial random solution c and add it to the archive
  scheduler::Schedule::Ptr current(new scheduler::Schedule(workload, resources));
  std::cout << "# Generating Random schedule " << std::endl;
  current->randomSchedule();
  current->update(); 
  resources->sanityCheck();
  archive->addSchedule(current);

  for( long iteration = 0; iteration < MAX_ITERATION; iteration += 1) {
	// 2. mutate c to produce m and evaluate m
	scheduler::Schedule::Ptr mutation(new scheduler::Schedule(*current));
	mutation->mutate();
	std::cout << "# schedule: " << current->str() << std::endl;
	std::cout << "Total QT: "  << current->getTotalQueueTime() << ", price: " << current->getTotalPrice() << std::endl;
	std::cout << "# mutation: " << mutation->str() << std::endl;
	std::cout << "Total QT: "  << mutation->getTotalQueueTime() << ", price: " << mutation->getTotalPrice() << std::endl;
	int compare=mutation->compare(current);
	if (compare == scheduler::Schedule::IS_DOMINATED) {
	  std::cout << "Schedule dominates the mutation - discarding mutation." << std::endl;
	} else if (compare == scheduler::Schedule::DOMINATES) {
	  std::cout << "Mutation dominates current schedule - replacing current + adding to archive." << std::endl;
	  current = mutation;
	  archive->addSchedule(mutation);
	} else if (compare == scheduler::Schedule::NO_DOMINATION) {
	  std::cout << "No decideable domination - comparing mutation to archive." << std::endl;
	  // if mutation is dominated by any member of the archive - discard it.
	  if (archive->dominates(mutation))
		std::cout << "Archive dominates mutation - discarding mutation." << std::endl;
	  else 
		std::cout << "Running test routine." << std::endl;
	}
  }


  //
  //  for( unsigned int i = 0; i < 10; i += 1) {
  //	scheduler::Schedule::Ptr scheduleCopy(new scheduler::Schedule(*current));
  //	scheduleCopy->mutate();
  //	//std::cout << "Total QT: " << scheduleCopy->getTotalQueueTime() << ", price: " << scheduleCopy->getTotalPrice() << std::endl;
  //	archive->addSchedule(scheduleCopy);
  //  }
  //

  // dump the archive to disk.
  std::cout << "Archive: " << archive->str() << std::endl;
  util::ReportWriter::Ptr reporter(new util::ReportWriter(outputfile));
  std::string headerLine("experiment from input file ");
  reporter->addHeaderLine(headerLine + inputfile);
  std::string resourceInfo(resources->str());
  reporter->addHeaderLine(resourceInfo);
  reporter->addReportLine(archive->getLogLines());
  reporter->writeReport();

  return 0;
}

