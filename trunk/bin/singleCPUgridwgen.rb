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
require 'Models'
require 'Workload'
require 'Helpers'
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
            opts.banner = "Usage: singleCPUgridwgen.rb [options]"
            opts.separator ""
            opts.separator "Specific options:"
            # Mandatory argument.
            opts.on("-u", "--numUsers INT", "the number of users to generate") do |numUsers|
                options.numUsers=numUsers
            end
            opts.on("-j", "--numJobs INT","the number of jobs to generate") do |numJobs|
                options.numJobs=numJobs
            end
            opts.on("-c", "--percentCoallocation FLOAT","the number of jobs to generate") do |percentCoallocation|
                options.percentCoallocation = percentCoallocation
            end
            # Boolean switch.
            opts.on("-v", "--verbose", "Run verbosely") do |v|
                options.verbose = v
            end
            opts.on("-s", "--steady", "Do not use a natural job distribution, but create steadily incoming jobs") do |v|
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
$steady = options.steady
percentCoallocation = options.percentCoallocation.to_f

if numTotalJobs == 0 or @@config.numUsers == 0 or percentCoallocation == nil
    print "please read usage note (-h)\n"
    exit
end

numTotalSystems = 50
# First, take the number of coallocationJobs off...
coallocationJobs = numTotalJobs * percentCoallocation
# Then, calculate how many jobs each resource must have
# to add up to numTotalJobs
numJobsPerCluster = ((numTotalJobs - coallocationJobs) / numTotalSystems).to_i

###
## Script startup
#
print "Calana Workload Generator\n"
print "We generate a single-CPU grid workload: Consists of \n"
print "#{numTotalSystems} single-node machines.\n"
print "We create #{numTotalJobs} jobs.\n"
print "We generate #{percentCoallocation*100} % coallocationjobs:\n"
print "CoallocationJobs: #{coallocationJobs}, numJobsPerCluster (rounded): #{numJobsPerCluster}\n"

cleanVarDirectory()

for i in 1..numTotalSystems # single-node systems
    cluster = ClusterConfig.new("Cluster1-"+i.to_s, 1, 1, numJobsPerCluster)
    @@config.addCluster(cluster)
end

if coallocationJobs > 0
    coallocationCluster=ClusterConfig.new("Coallocation", 2, 2, coallocationJobs)
end
print "Starting up in directory #{@@config.basePath}\n"

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
		aggregatedWorkload = genLublinCluster(clusterConfig)
    else
        tempWorkload = genLublinCluster(clusterConfig)
        tempWorkload.mergeWorkloadTo(aggregatedWorkload)
    end
}

aggregatedWorkload=aggregatedWorkload.createSequentialJobWorkload()

if (coallocationJobs > 0)
    coallocationWorkload = genLublinCluster(coallocationCluster)
    multiJobbedWorkload = coallocationWorkload.createCoallocationJobWorkload()
    #print "The modified workload\n"
    #builder = Builder::XmlMarkup.new(:target=>$stdout, :indent=>2)
    #multiJobbedWorkload.xmlize(builder)
    multiJobbedWorkload.mergeWorkloadTo(aggregatedWorkload)
end    

print "Fixing job sizes -> Setting jobsize to 1\n"
aggregatedWorkload.eachJob{|job|
    job.numberAllocatedProcessors = 1
}

###
## Next step: We generate a set of users and connect them to jobs at random.
#
print "Generating users\n"
aggregatedWorkload.generateRandomUsers()
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
storeFileName=@@config.runPath+"/"+@@config.outFile+"-wcollection.bin"
store=File.new(storeFileName, "w")
Marshal.dump(collection, store)
store.close

###
## Finally: Put the generated workloads on the disk.
#
collection.eachWorkload {|w|
    file=@@config.runPath+"/"+@@config.outFile+"-"+
        w.calculateLoadLevel().to_s + ".xml"
    outFile=File.new(file, "w")
    builder = Builder::XmlMarkup.new(:target=>outFile, :indent=>2)
# produce output
    print "Generating XML workload file #{file}\n"
    w.xmlize(builder)
    outFile.close
}

