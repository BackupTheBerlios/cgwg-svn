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

###
## Runs the lublin model for the creation of a cluster workload. We need 
## to set various parameters within the model - unfortunately, there is no 
## config file. We therefore generate an include file where all parameters
## are set. Then, we compile and run the generator.
##
## MD: I don't understand how the load of the generated model correlates 
## with the size of the cluster (@machineConfig["nodes"]), the interarrival parameters
## and the number of jobs (@@config.size). No idea how to scale within
## this model.
#
class Lublin
    ###
    ## The configuration of the model depends on the cluster that should be
    ## generated. Therefore, we need to pass the cluster's configuration to 
    ## the model.
    #
    def initialize(machineConfig)
        @machineConfig = machineConfig
        # Calculate size-dependent values
        size=@@config.size
        uhi = log2(@machineConfig.nodes).to_i
        ulow = log2(@machineConfig.smallestJobSize())
        # UMED should be in [UHI-1.5, UHI-3.5], make this a static setting.
        # This defines the change point in the cdf, see Lublin's code.
        umed = uhi - 2.5
        @clusterConfig = <<-EOC
#define SIZE #{size}          
/* UHI: Needs to be adjusted, depending on the cluster */
#define UHI #{uhi}
#define ULOW #{ulow}
#define UMED #{umed}
        EOC
    end
    ###
    ## Calibration of Lublin's model. The callibration depends on both system 
    ## size and load. The size configuration is handled in the constructor,
    ## here we need to deal with the load level.
    #
    def prepare()
        loadConfig = <<-EOC
/* Values for a different load level */
#define A1 4.2
#define AARR 10.23
#define BARR 0.4871
        EOC
        # Create a new configuration including the load and the number of jobs
        print "configuration... "
        config = <<-EOC
#{@clusterConfig}
#{loadConfig}
        EOC
        sourcePath=@@config.basePath+"/externalmodels/lublin99-clusterworkload"
        configFile=File.new(sourcePath+"/lublin_config.h", "w")
        config.each_line {|line|
            configFile.puts(line)
        }
        configFile.close
        # compile the stuff... Note that there will be a warning about the 
        # redefinition of some preprocessor directives
        print "compilation... "
        compile_cmd="gcc -o "+@@config.runPath+"/m_lublin99 "+
                sourcePath+"/m_lublin99.c"
        compile_msg=`#{compile_cmd}`
    end
    ###
    ## Run the previously compiled binary, fetch the results.
    #
    def run_lublin()
        print "\nRunning Lublin's Generator: "
        # run the model
        print "exec... "
        exec_cmd=@@config.runPath+"/m_lublin99"
        swf = `#{exec_cmd}`
        print "OK.\n"
        return swf
    end
    def getRange()
        return 0.00, 0.10
    end
end

###
## Just a stub that will be replaced by Dan Tsafir's user runtime 
## estimates model. We just add 10% to the runTime.
#
def run_lModelRuntimeEstimates(workload)
    workload.eachJob {|job|
        job.wallTime=(job.runTime*1.10).to_i
    }
end

###
## Helper function: Calculate the binary logarithm.
#
def log2(n)
    return (Math.log(n)/Math.log(2))
end