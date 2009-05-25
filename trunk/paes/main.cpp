#include <iostream>
#include <unistd.h>
#include <vector>
#include <sstream>
#include <stdio.h>
#include <math.h>
#include <sys/stat.h>
#include <sys/types.h> /* various type definitions, like pid_t           */
#include <signal.h>    /* signal name macros, and the signal() prototype */

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

// Global variables
util::ReportWriter::Ptr iterationReporter;
util::ReportWriter::Ptr absReporter;
util::ReportWriter::Ptr relReporter;
scheduler::ScheduleArchive::Ptr archive;

void printHelp() {
  std::cout << "PAES Scheduler" << std::endl;
  std::cout << "Mandatory commandline parameters:" << std::endl;
  std::cout << " -i <FILE>: Specify input file" << std::endl;
  std::cout << " -o <DIR>: Specify output directory" << std::endl;
  std::cout << " -v: Verbose output" << std::endl;
}

void saveResults() {
  absReporter->addReportLine(archive->getAbsLogLines());
  relReporter->addReportLine(archive->getRelLogLines());
  absReporter->writeReport();
  relReporter->writeReport();
  iterationReporter->writeReport();
}

/* signal handler */
void catch_int(int sig_num) {
  /* re-set the signal handler again to catch_int, for next time */
  signal(sig_num, catch_int);
  /* and print the message */
  std::cout << "Caught signal ";
  switch (sig_num) {
	case SIGINT:
	  std::cout << "SIGINT - shutting down." << std::endl;
	  break;
	case SIGSEGV:
	  std::cout << "SIGSEGV - shutting down." << std::endl;
	  break;
	default:
	  std::cout << "UNKNOWN: " << sig_num << std::endl;
	  break;
  }
  saveResults();
  exit(-2);
}

/* Registers our routine as signal handler */
void register_inthandlers() {
  signal(SIGINT, catch_int);
  signal(SIGSEGV, catch_int);
}

int main (int argc, char** argv) {
  // Parse the commandline parameters using getopt
  bool verbose=false;
  char *inputfile = NULL;
  char *outputdir = NULL;
  int c;

  register_inthandlers();

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
		outputdir = optarg;
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

  if (outputdir == NULL) {
	std::cerr << "No output directory specified - aborting." << std::endl;
	exit(-1);
  } else {
	// Test if the directory exists.
	struct stat st;
	if(stat(outputdir,&st) == 0)
	  std::cout << "Writing results to " << outputdir << std::endl;
	else {
	  std::cout << "Output directory \"" << outputdir << "\" not existent - aborting." << std::endl;
	  exit(-2);
	}
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
  archive = scheduler::ScheduleArchive::Ptr (new scheduler::ScheduleArchive(config::ARCHIVE_SIZE, workload->size()));

  // 1. generate initial random solution c and add it to the archive
  scheduler::Schedule::Ptr current(new scheduler::Schedule(workload, resources));
  std::cout << "# Generating Random schedule " << std::endl;
  current->randomSchedule();
  current->update(); 
  resources->sanityCheck();
  archive->archiveSchedule(current);

  // prepare reporting
  unsigned long archivedSolutions=0;
  unsigned long report_interval = config::MAX_ITERATION / 3;
  std::cout << "Will dump intermediate report every "<<report_interval << " iterations." << std::endl;
  std::ostringstream iteration_oss;
  iteration_oss << outputdir << "/runtime-report.txt";
  iterationReporter = util::ReportWriter::Ptr(new util::ReportWriter(iteration_oss.str()));
  iterationReporter->addHeaderLine("Reporting runtime information below");
  iterationReporter->addReportLine("it\tacc\tsize\tdistance");

  absReporter=util::ReportWriter::Ptr(new util::ReportWriter(std::string(outputdir)+"/absolute-results.txt"));
  std::string headerLine("experiment from input file ");
  absReporter->addHeaderLine(headerLine + inputfile);
  std::string resourceInfo(resources->str());
  absReporter->addHeaderLine(resourceInfo);
  std::ostringstream oss1;
  oss1 << "Workload file: " << inputfile;
  absReporter->addHeaderLine(oss1.str());
  std::ostringstream oss2;
  oss2 << "Workload size: " << workload->size();
  absReporter->addHeaderLine(oss2.str());

  relReporter=util::ReportWriter::Ptr (new util::ReportWriter(std::string(outputdir)+"/relative-results.txt"));
  relReporter->addHeaderLine(headerLine + inputfile);
  relReporter->addHeaderLine(resourceInfo);
  relReporter->addHeaderLine(oss1.str());
  relReporter->addHeaderLine(oss2.str());


  // Main loop
  double prev_distance=0.0;
  for( unsigned long iteration = 0; iteration < config::MAX_ITERATION; iteration += 1) {
	// 2. mutate c to produce m and evaluate m
	scheduler::Schedule::Ptr mutation(new scheduler::Schedule(*current));
	mutation->mutate();
	if(verbose) {
	  std::cout << "# schedule: " << current->str() << std::endl;
	  std::cout << "Total QT: "  << current->getTotalQueueTime() << ", price: " << current->getTotalPrice() << std::endl;
	  std::cout << "# mutation: " << mutation->str() << std::endl;
	  std::cout << "Total QT: "  << mutation->getTotalQueueTime() << ", price: " << mutation->getTotalPrice() << std::endl;
	}
	int compare=mutation->compare(current);
	// First, compare the current solution to the mutation.
	if (compare == scheduler::Schedule::IS_DOMINATED) {
	  if (verbose)
		std::cout << "(1) Current schedule dominates the mutation - discarding mutation." << std::endl;
	  ;;
	} else if (compare == scheduler::Schedule::DOMINATES) {
	  if (verbose)
		std::cout << "(2) Mutation dominates current schedule - replacing current + adding to archive." << std::endl;
	  current = mutation;
	  if (archive->archiveSchedule(mutation)) {
		archive->updateAllLocations();
		archivedSolutions++;
	  }
	} else if (compare == scheduler::Schedule::NO_DOMINATION) {
	  if (verbose)
		std::cout << "(3) No decideable domination - comparing mutation to archive." << std::endl;
	  // if mutation is dominated by any member of the archive - discard it.
	  if (archive->dominates(mutation)) {
		if (verbose)
		  std::cout << "(3a) Archive dominates mutation - discarding mutation." << std::endl;
		;;
	  } else {
		// Unclear if we should add this solution.
		if (verbose)
		  std::cout << "(3b) Running test routine." << std::endl;
		// archive solution
		if (archive->archiveSchedule(mutation)) {
		  archivedSolutions++; 
		  // update grid
		  archive->updateAllLocations();
		}
		// if mutation dominates the archive or is in less crowded grid location than current
		// replace current with mutation.
		if (verbose)
		  std::cout << "(3b) Current population: " << archive->getPopulationStr();
		unsigned long current_population = archive->getPopulationCount(current->getLocation());
		unsigned long mutation_population = archive->getPopulationCount(mutation->getLocation());
		if (archive->isDominated(mutation) || mutation_population < current_population) {
		  if (verbose)
			std::cout << "(3b) Replacing current solution with mutation." << std::endl;
		  current = mutation;
		  archivedSolutions++;
		} 
	  }
	}
	// Create reports.
	if ((iteration % 1000) == 0) {
	  // print some stats.
	  double current_distance=archive->getDistance();
	  std::cout.precision(16);
	  std::cout << "Iteration "<< iteration << ": archived " << archivedSolutions;
	  std::cout << "/1000, archive size " << archive->size() << ", distance: " << current_distance;
	  std::cout << ", delta distance (%): " << (fabs(current_distance - prev_distance)/current_distance) << std::endl;
	  prev_distance=current_distance;

	  std::ostringstream logLine;
	  logLine << iteration << "\t" << archivedSolutions << "\t" << archive->size() << "\t" << archive->getDistance();
	  iterationReporter->addReportLine(logLine.str());
	  archivedSolutions=0;
	}
	if ((iteration % report_interval) == 0) {
	  std::cout << "Generating intermediate reports." << std::endl;
	  std::ostringstream filename_oss;
	  filename_oss << outputdir << "/intermediate-" << iteration << ".txt";
	  util::ReportWriter::Ptr absReporter(new util::ReportWriter(filename_oss.str()));
	  std::string headerLine("intermediate results");
	  absReporter->addHeaderLine(headerLine);
	  std::string resourceInfo(resources->str());
	  absReporter->addHeaderLine(resourceInfo);
	  std::ostringstream oss1;
	  oss1 << "Workload file: " << inputfile;
	  absReporter->addHeaderLine(oss1.str());
	  std::ostringstream oss2;
	  oss2 << "Workload size: " << workload->size();
	  absReporter->addHeaderLine(oss2.str());
	  absReporter->addReportLine(archive->getAbsLogLines());
	  absReporter->writeReport();
	}

  }

  // Finally, save the collected results.

  saveResults();

  return 0;
}

