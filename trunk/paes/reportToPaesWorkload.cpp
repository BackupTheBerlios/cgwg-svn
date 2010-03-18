#include <iostream>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fstream>
#include <sstream>

using namespace std;

void printHelp () {
  cout << "Workload transformer" << endl;
  cout << "--------------------" << endl;
  cout << "Mandatory parameters:" << endl;
  cout << " -i <FILE>: specify input file (report file)" << endl;
  cout << " -o <DIR>: specify output directory" << endl;
  cout << " -n STRING: specify output file name" << endl;
  cout << endl;
  cout << "Optional parameters:" << endl;
  cout << " -h: Show this help" << endl;
}

void abort () {
  printHelp();
}

int main(int argc, char * argv[]) {
  int c;
  char * input_file = 0;
  char * output_dir = 0;
  char * output_filename = 0;

  while((c = getopt (argc, argv, "hi:o:n:")) != -1) {
    switch (c) {
      case 'h':
        printHelp();
        break;
      case 'i':
        input_file = optarg;
        break;
      case 'o':
        output_dir = optarg;
        break;
      case 'n':
        output_filename = optarg;
        break;
      case ':':
      case '?':
      default:
        abort();
    }
  }

  if (input_file == NULL) {
    cerr << "No input file specified - aborting." << endl;
    return(-1);
  } else {
    cout << "Using input file " << input_file << endl;
  }

  if (output_dir == NULL) {
    cerr << "No output dir specified - aborting." << endl;
    return(-1);
  } else {
    struct stat st;
    string o_dir = output_dir;
    o_dir.append("/");
    if (stat(o_dir.c_str(), &st) == 0)
      cout << "Using output dir " << output_dir << endl;
    else
      cout << "Output directory \"" << output_dir << "\" does not exist - aborting." << endl;
  }
  
  if (output_filename == NULL) {
    cerr << "No output file name specified - aborting." << endl;
    return(-1);
  } else {
    cout << "Using output file name " << output_filename << endl;
  }

  string output_file = output_dir;
  output_file.append("/").append(output_filename);

  ifstream input (input_file);
  ofstream output (output_file.c_str());
  output << "# JID SubmitTime RunTime WallTime Size" << endl;

  string line = "";
  while (getline(input, line)) {
    stringstream ss;
    ss << line;
    string elt;
    ss >> elt;

    char first_letter = elt.c_str()[0];
    if (first_letter != ';' and first_letter != '\n' and first_letter != '=' and first_letter != 't') {
      stringstream datum;
      int spalte = 0;
      string jobid, size, submittime, runtime = "";
      while (getline(ss, elt, '|')) {
        if (spalte == 1 or spalte == 3 or spalte == 11 or spalte == 14) {
          datum.flush();
          datum << elt;
          datum >> elt;
          switch (spalte) {
            case 1:
              jobid = elt.erase(0, 4);
              break;
            case 3:
              size = elt;
              break;
            case 11:
              submittime = elt;
              break;
            case 14:
              runtime = elt;
          }
        }
        spalte++;
      }
      if(jobid != "") output << jobid << "\t" << submittime << "\t" << runtime << "\t" << runtime << "\t" << size << endl;
    }
  }
  
  input.close();
  output.close();

  return 1;
  
}
