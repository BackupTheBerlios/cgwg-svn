#!/usr/bin/env ruby
# This file is part of the calana grid workload generator.
# (c) 2006 Mathias Dalheimer, md@gonium.net
#
# The calana grid workload generator (CGWG) is free software; you can 
# redistribute it and/or modify it under the terms of the GNU General Public 
# License as published by the Free Software Foundation; either version 2 of 
# the License, or any later version.
#
# CGWG is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with CGWG; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA


# Read the CGWG location from the environment, warn otherwise
if (ENV["CGWG_HOME"] == nil)
  puts "WARNING: Environment does not define $CGWG_HOME!"
else
  libpath= File.join(File.expand_path(ENV["CGWG_HOME"]), "lib")
  $:.unshift << libpath
#  puts "Using libraty path #{$:.join(":")}" 
end




require 'yaml'
require 'rubygems'
gem 'builder' #we need xml builder
require 'builder/xmlmarkup'
require 'Helpers'
require 'Models'
require 'Workload'
require 'optparse'
require 'ostruct'

###
## This is the main workload generator file. You should look at the
## ConfigManager class (in lib/Helpers.rb) and the main program below.
#

###
## Commandline parser
#
class Optparser
  CODES = %w[iso-2022-jp shift_jis euc-jp utf8 binary]
  CODE_ALIASES = { "jis" => "iso-2022-jp", "sjis" => "shift_jis" }
  #
  # Return a structure describing the options.
  #
  def self.parse(args)
    # The options specified on the command line will be collected in *options*.
    # We set default values here.
    options = OpenStruct.new
    options.inplace = false
    options.encoding = "utf8"
    options.verbose = false
    opts = OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [options]"
      opts.separator ""
      opts.separator "Specific options:"
      # Mandatory argument.
      opts.on("-u", "--numUsers INT", "the number of users to generate") do |numUsers|
        options.numUsers=numUsers
      end
      opts.on("-j", "--numJobs INT","the number of jobs to generate") do |numJobs|
        options.numJobs=numJobs
      end
      opts.on("-l", "--joblength INT","the mean duration of a job in seconds") do |joblength|
        options.joblength=joblength
      end
      opts.on("-x", "--generate-xml","generate xml workload files") do |xml|
        options.xml=xml
      end
      opts.on("-r", "--numTotalResources INT","the number of resources in the grid") do |numtotalresources|
        options.numTotalResources=numtotalresources
      end
      opts.on("-c", "--numCPUs INT","the number of CPUs for each resource in the grid") do |numcpusperresource|
        options.numCpusPerResource=numcpusperresource
      end
      opts.on("-s", "--serialProb FLOAT", "the probability of a job to be serial, if not given 0 is assumed") do |serialprob|
        options.serialprob=serialprob
      end
      opts.on("-m", "--maxJobSize INT", "maximal job size (usually power of 2), if not given 32 is assumed") do |maxjobsize|
        options.maxjobsize=maxjobsize
      end
      opts.on("-d", "--directory STRING", "the subdirectory in var to put the generated files in") do |subdir|
        options.subDir=subdir
      end
      #            opts.on("-c", "--percentCoallocation FLOAT","the number of jobs to generate") do |percentCoallocation|
      #                options.percentCoallocation = percentCoallocation
      #            end
      # Boolean switch.
      opts.on("-v", "--verbose", "Run verbosely") do |v|
        options.verbose = v
      end
      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
      end
    end
    opts.parse!(args)
    options
  end
end


###
## You may also want to check out the ConfigManager class in lib/Helpers.rb.
#
@@config = ConfigManager.new
options = Optparser.parse(ARGV)

numTotalJobs = options.numJobs.to_i
@@config.numUsers = options.numUsers.to_i
$verbose = options.verbose
joblength=options.joblength.to_i
numTotalSystems = options.numTotalResources.to_i
numCpusPerResource = options.numCpusPerResource.to_i
serialProb = 0
maxJobSize = 32
subDir = options.subDir
#percentCoallocation = options.percentCoallocation.to_f

serialProb = options.serialprob.to_f if options.serialprob.to_f != 0
maxJobSize = options.maxjobsize.to_i if options.maxjobsize.to_i != 0
if numTotalJobs == 0 or @@config.numUsers == 0 or joblength == 0 or numTotalSystems == 0 or subDir == nil
  print "please read usage note (-h)\n"
  exit
end

print "Calana Workload Generator\n"
print "We generate a single-CPU grid workload: Consists of \n"
print "#{numTotalSystems} #{numCpusPerResource}-node machines.\n"
print "We create #{numTotalJobs} jobs.\n"
print "Starting up in directory #{@@config.basePath}\n"

cleanVarDirectory(subDir)

# calculate how many jobs each resource must have
# to add up to numTotalJobs
numJobsPerCluster = ((numTotalJobs) / numTotalSystems).to_i
for i in 1..numTotalSystems # #{numCpusPerResource}-node systems
  cluster = ClusterConfig.new("Cluster1-"+i.to_s, numCpusPerResource, 1, numJobsPerCluster)
  @@config.addCluster(cluster)
end


###
## Read Configuration, start main loop. Here, we generate a workload for
## each cluster as given in the configuration. We merge them all in the
## aggregated workload.
#
aggregatedWorkload = nil
@@config.clusters.each{|clusterConfig|
  #print clusterConfig
  print "### Working on cluster #{clusterConfig.name}\n"
  if aggregatedWorkload == nil
    puts "Clusterconfig: #{clusterConfig} with probability of #{serialProb} for serial jobs, a max size of #{maxJobSize} cpus and an average job length of #{joblength}"
    aggregatedWorkload = genPoissonCluster(clusterConfig, serialProb, maxJobSize, joblength)
  else
    tempWorkload = genPoissonCluster(clusterConfig, serialProb, maxJobSize, joblength)
    tempWorkload.appendWorkloadTo(aggregatedWorkload)
  end
}

aggregatedWorkload=aggregatedWorkload.createSequentialJobWorkload()

###
## Next step: We generate a set of users and connect them to jobs at random.
#
print "Generating users\n"
aggregatedWorkload.generateDoubleGaussUsers()
print "Connecting users with jobs\n"
aggregatedWorkload.linkUsers()

###
## Just to have it on the screen: Put the original workload on the screen.
#
#builder = Builder::XmlMarkup.new(:target=>$stdout, :indent=>2)
#aggregatedWorkload.xmlize(builder)


# Create a new workload connection where we gather all generated workloads
collection=WorkloadCollection.new

# Generate all load level slots from the generated workload. Note that all
# characteristics except for the interarrival time are not changed.
print "Generating scaled workloads\n"
collection.generateEachSlot {|load|
  collection.addExact(load, aggregatedWorkload.scaleLoadLevel(load))
}

###
## If we want to check which slot has what level of load, we can print it.
#collection.printWorkloadOverview()

###
## Put the workload collection on disk for analysis later on...
#
Dir.mkdir(ENV["CGWG_HOME"]+"/var/#{subDir}")
storeFileName=ENV["CGWG_HOME"]+"/var/#{subDir}/"+@@config.outFile+"-wcollection.bin"
store=File.new(storeFileName, "w")
Marshal.dump(collection, store)
store.close

###
## Finally: Put the generated workloads on the disk.
#
if options.xml
  collection.eachWorkload {|w|
    file=ENV["CGWG_HOME"]+"/var/#{subDir}/"+@@config.outFile+"-"+
      w.calculateLoadLevel().to_s + ".xml"
      outFile=File.new(file, "w")
    builder = Builder::XmlMarkup.new(:target=>outFile, :indent=>2)
    # produce output
    print "Generating XML workload file #{file}\n"
    w.xmlize(builder)
    outFile.close
  }
else
  puts "no xml output requested."
end
