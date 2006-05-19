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
print "We generate a grid workload based on the machine characteristics"
print "as described by Kee et al. (http://vgrads.rice.edu/publications/andrew2)"

###
## You may also want to check out the ConfigManager class in lib/Helpers.rb.
#
@@config = ConfigManager.new
@@config.numUsers = 1000
# We want to have 10000 jobs with the 50 systems defined below.
numJobsPerCluster = 500

for i in 1..50 # single-node systems
    cluster = ClusterConfig.new("Cluster1-"+i.to_s, 1, 1, numJobsPerCluster)
    @@config.addCluster(cluster)
end

#coallocationCluster=ClusterConfig.new("Coallocation", 128, 2, 10)
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

#coallocationWorkload = genLublinCluster(coallocationCluster)
#multiJobbedWorkload = coallocationWorkload.createCoallocationJobWorkload()
#print "The modified workload\n"
#builder = Builder::XmlMarkup.new(:target=>$stdout, :indent=>2)
#multiJobbedWorkload.xmlize(builder)
#multiJobbedWorkload.mergeWorkloadTo(aggregatedWorkload)

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
    file=@@config.runPath+"/"+@@config.outFile+"-"+
        w.calculateLoadLevel().to_s + ".xml"
    outFile=File.new(file, "w")
    builder = Builder::XmlMarkup.new(:target=>outFile, :indent=>2)
# produce output
    print "Generating XML workload file #{file}\n"
    w.xmlize(builder)
    outFile.close
}

