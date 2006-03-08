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





###############################################################################
###
## Helper classes and methods below.
#

###
## Here we control how a cluster workload is created - adjust to your
## own needs.
## Generates a workload using Lublin's model. Configuration is taken from
## the given cluster configuration. The model is executed, data is parsed,
## and runtime estimates are added.
#
def genLublinCluster(clusterConfig)
    # Create a new workload to start with.
    # This could also be replaced by reading a workload file.
    print "Generating workload for cluster config: \n#{clusterConfig}"
    lublin=Lublin.new(clusterConfig)
    lublin.prepare()
    # Read data in Workload class, add runtime estimates and users
    swf = lublin.run_lublin()
    workload=Workload.new(clusterConfig)
    print "Parsing workload\n"
    workload.parseSWF(swf)
    print "Adding runtime estimates\n"
    run_lModelRuntimeEstimates(workload)
    return workload
end

###
## Encapsulate the configuration of a cluster.
#
class ClusterConfig
    attr_accessor :name, :nodes, :smallestJobSize, :size
    ###
    ## Provides all data a cluster needs to have:
    ## - a name
    ## - the number of nodes available in the system (max. job size)
    ## - the smallest possible job size
    ## - the size of the workload (the number of jobs to generate)
    #
    def initialize(name, nodes, smallestJobSize, size)
        @name = name
        @nodes = nodes.to_i
        @smallestJobSize = smallestJobSize.to_i
        @size = size
    end
    def to_s
        retval = "Cluster ID: #{@name}\n"
        retval += " - number of nodes: #{@nodes}\n"
        retval += " - smallest job size: #{@smallestJobSize}\n"
    end
    def mergeTo(other)
        other.nodes += @nodes
        if (@smallestJobSize < other.smallestJobSize)
            other.smallestJobSize = @smallestJobSize
        end
    end
end

