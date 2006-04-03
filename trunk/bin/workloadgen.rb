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

require 'yaml'
require 'rubygems'
require_gem 'builder' #we need xml builder
require 'lib/Models'
require 'lib/Workload'
require 'lib/Helpers'

###
## This is the main workload generator file. You should look at the
## ConfigManager class (in lib/Helpers.rb) and the main program below.
#

###
## Script startup
#
print "Calana Workload Generator\n"

###
## You may also want to check out the ConfigManager class in lib/Helpers.rb.
#
@@config = ConfigManager.new
@@config.numUsers = 10

clusterA=ClusterConfig.new("ClusterA", 128, 2, 1000)
clusterB=ClusterConfig.new("ClusterB", 64, 1, 1000)
coallocationCluster=ClusterConfig.new("Coallocation", 128, 2, 1000)
@@config.addCluster(clusterA)
@@config.addCluster(clusterB)
print "Starting up in directory #{@@config.basePath}\n"

###
## Read Configuration, start main loop. Here, we generate a workload for
## each cluster as given in the configuration. We merge them all in the
## aggregated workload.
#
aggregatedWorkload = nil
@@config.clusters.each{|clusterConfig|
    print clusterConfig
    print "### Working on cluster #{clusterConfig.name}\n"
    if aggregatedWorkload == nil
        aggregatedWorkload = genLublinCluster(clusterConfig)
    else
        tempWorkload = genLublinCluster(clusterConfig)
        tempWorkload.mergeWorkloadTo(aggregatedWorkload)
    end
}

###
## Add runtime estimates for backfilling
#
aggregatedWorkload = addUserRuntimeEstimates(aggregatedWorkload)

###
## Build a sequential task structure
#
aggregatedWorkload=aggregatedWorkload.createSequentialJobWorkload()


###
## Now, we deal with the creation of some coallocation jobs.
#
coallocationWorkload = genLublinCluster(coallocationCluster)
coallocationWorkload = addUserRuntimeEstimates(coallocationWorkload)
multiJobbedWorkload = coallocationWorkload.createCoallocationJobWorkload()
#print "The modified workload\n"
#builder = Builder::XmlMarkup.new(:target=>$stdout, :indent=>2)
#multiJobbedWorkload.xmlize(builder)
multiJobbedWorkload.mergeWorkloadTo(aggregatedWorkload)

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
## Finally: Put the generated workloads on the disk.
#
collection.eachWorkload {|w|
    filePrefix=@@config.runPath+"/"+@@config.outFile+"-"+
        w.calculateLoadLevel().to_s
    file=filePrefix+".xml"
    outFile=File.new(file, "w")
    builder = Builder::XmlMarkup.new(:target=>outFile, :indent=>2)
# produce output
    print "Generating XML workload file #{file}\n"
    w.xmlize(builder)
    outFile.close
    file=filePrefix+".swf"
    outFile=File.new(file, "w")
    print "Generating SWF workload file #{file}"
    swfDump=w.writeSWFFormat()
    swfDump.each_line{|line|
        outFile.write(line)
    }
    outFile.close
}

