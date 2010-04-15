#include <iostream>
#include <unistd.h>
#include <vector>
#include <sstream>
#include <stdio.h>
#include <math.h>
#include <sys/stat.h>
#include <sys/types.h> /* various type definitions, like pid_t           */
#include <signal.h>    /* signal name macros, and the signal() prototype */
#include <sys/time.h>  /* gettimeofday and friends.						 */

#include <resourcepool.hpp>
#include <common.hpp>
#include <config.hpp>
#include <workload.hpp>
#include <random.hpp>
#include <job.hpp>
#include <simpleresource.hpp>
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
  std::cout << " -s <UINT>: Specify RNG seed value" << std::endl;
  std::cout << " -n <INT>: Set number of iterations (default 10,000,000)" << std::endl;
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
	  std::cout << "SIGSEGV - attempting to save data." << std::endl;
	  break;
	default:
	  std::cout << "UNKNOWN: " << sig_num << std::endl;
	  break;
  }
  saveResults();
  util::RNG& rng=util::RNG::instance();
  std::cout << "RNG seed value was " << rng.get_seed() << std::endl;
  exit(-2);
}

/* Registers our routine as signal handler */
void register_inthandlers() {
  signal(SIGINT, catch_int);
  signal(SIGSEGV, catch_int);
}

long getCurrentMilliseconds() {
  struct timeval tv;
  gettimeofday (&tv, NULL);
  return (((long)tv.tv_sec * 1000) + (tv.tv_usec / 1000));
}

int main (int argc, char** argv) {
  // Parse the commandline parameters using getopt
  bool verbose=false;
  char *inputfile = NULL;
  char *outputdir = NULL;
  char *rng_seed_str = NULL;
  unsigned int max_iterations = 0;
  int c;

  register_inthandlers();

  opterr = 0;
  while ((c = getopt (argc, argv, "hvi:o:s:n:")) != -1)
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
	  case 's':
		rng_seed_str = optarg;
		break;
    case 'n':
    sscanf(optarg, "%u", &max_iterations);
    break;
	  case '?':
		if (optopt == 'i')
		  fprintf (stderr, "Option -%c requires an argument.\n", optopt);
		else if (optopt == 'o')
		  fprintf (stderr, "Option -%c requires an argument.\n", optopt);
		else if (optopt == 's')
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

  if (rng_seed_str == NULL) {
	std::cout << "Using random RNG seed: ";
	util::RNG& rng=util::RNG::instance();
	std::cout << rng.get_seed() << std::endl;
  } else {
	unsigned int seed_value=0;
	std::istringstream convertStream(rng_seed_str);
	if (convertStream>>seed_value) {
	  util::RNG& rng=util::RNG::instance();
	  rng.set_seed(seed_value);
	  std::cout << "RNG seed value set to " << rng.get_seed() << std::endl;
	} else {
	  std::cout << "Cannot convert seed value " << rng_seed_str << " to uint. Abort." << std::endl;
	  exit(-10);
	}
  }

  if (max_iterations == 0) {
    max_iterations = config::MAX_ITERATION;
  }

  std::string configInfo(config::getConfigString());
  std::cout << "Compile-time configuration is: " << std::endl << configInfo << std::endl;

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
  scheduler::ResourcePool::Ptr resources=config::createResourcePool();

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
  unsigned long report_interval = max_iterations / 3;
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
  std::ostringstream oss3;
  oss3 << "Compile-time config: " << configInfo;
  absReporter->addHeaderLine(oss3.str());

  relReporter=util::ReportWriter::Ptr (new util::ReportWriter(std::string(outputdir)+"/relative-results.txt"));
  relReporter->addHeaderLine(headerLine + inputfile);
  relReporter->addHeaderLine(resourceInfo);
  relReporter->addHeaderLine(oss1.str());
  relReporter->addHeaderLine(oss2.str());
  relReporter->addHeaderLine(oss3.str());

  // mark start time.
  long start_time = getCurrentMilliseconds();
  std::cout << "Start time is " << start_time << std::endl;
  
  // Main loop
  double prev_distance=0.0;
  double sum_delta_distance=0.0;
  for( unsigned long iteration = 0; iteration < max_iterations; iteration += 1) {
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
		  archive->updateAllLocations();
		  //archivedSolutions++; 
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
		  //archivedSolutions++;
		} 
	  }
	}
	// Create reports.
	if ((iteration % 1000) == 0) {
	  // print some stats.
	  double current_distance=archive->getDistance();
	  double delta_distance = (fabs(current_distance - prev_distance)/current_distance);
	  std::cout.precision(32);
	  std::cout << "Iteration "<< iteration << ": dominant " << archivedSolutions;
	  std::cout << "/1000, archive size " << archive->size() << ", distance: " << current_distance;
	  std::cout << ", delta distance (%): " <<  delta_distance << std::endl;
	  prev_distance=current_distance;
	  sum_delta_distance+=delta_distance;

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

	/**
	 * Termination criterion: abort if the results do not change any more. This is the 
	 * case if the delta distance is 0.0 for the last 10000 iterations,
	 * we assume that there is no better solution.
	 */
	if ((iteration % 10000) == 0) {
	  // Each 10 evaluation cycles
	  if (sum_delta_distance == 0.0) {
		std::cout << "No delta distance - we're stable. Exiting." << std::endl;
		break;
	  } else {
		sum_delta_distance = 0.0;
	  }
	}
  }

  long end_time = getCurrentMilliseconds();
  std::cout << "Runtime was " << ((end_time - start_time) / 1000) << " seconds." << std::endl;

  // Finally, save the collected results.
  saveResults();

  return 0;
}

