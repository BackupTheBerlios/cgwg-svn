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

require 'lib/Utils'

###
## Contains the description of an atomic job. A coallocation job 
## might just reference its atomic jobs.
#
class AtomicJob
    include DeepClone
    attr_accessor :jobID, :submitTime, :waitTime, :runTime, 
        :numberAllocatedProcessors, :averageCPUTimeUsed, :usedMemory,
        :reqNumProcessors, :wallTime, :reqMemory, :status, :userID, :groupID,
        :appID, :penalty, :queueID, :partitionID, :preceedingJobID, 
        :timeAfterPreceedingJob
    def initialize
        # These are the default values as defined in the SWF definition,
        # see http://www.cs.huji.ac.il/labs/parallel/workload/swf.html
        @jobID = 0
        @submitTime = -1
        @waitTime = -1
        @runTime = -1
        @numberAllocatedProcessors = -1
        @averageCPUTimeUsed = -1
        @usedMemory = -1
        @reqNumProcessors = -1
        @wallTime = -1
        @reqMemory = -1
        @status = -1
        @userID = -1
        @groupID = -1
        @appID = -1
        @penalty = 0
        @queueID = 0
        @partitionID = -1
        @preceedingJobID = -1
        @timeAfterPreceedingJob = -1
    end
    def writeSWFFormat
        retval = "#{@jobID}\t#{@submitTime}\t#{@waitTime}\t#{@runTime}\t"
        retval += "#{@numberAllocatedProcessors}\t#{@averageCPUTimeUsed}\t"
        retval += "#{@usedMemory}\t#{@reqNumProcessors}\t#{@wallTime}\t"
        retval += "#{@reqMemory}\t#{@status}\t#{@userID}\t#{@groupID}\t"
        retval += "#{@appID}\t#{@queueID}\t#{@partitionID}\t"
        retval += "#{@preceedingJobID}\t#{@timeAfterPreceedingJob}\n"
    end
    def writeXMLFormat(builder)
        builder.job("ID" => "#{@jobID}") { |j| 
            j.timing("waittime" => "#{@waitTime.to_i}", 
                    "submittime"=> "#{@submitTime.to_i}") 
            j.size { |s|
                s.actual("cpus"=> "#{@numberAllocatedProcessors}",
                        "memory" => "#{@usedMemory}",
                        "runtime" => "#{@runTime.to_i}",
                        "avgcputime" => "#{@averageCPUTimeUsed.to_i}")
                s.requested("cpus" => "#{@reqNumProcessors}",
                        "memory" => "#{@reqMemory.to_i}",
                        "walltime" => "#{@wallTime.to_i}")
            }
            j.meta { |m|
                m.status("value"=>"#{@status}")
                m.userID("value"=>"#{@userID}")
                m.groupID("value"=>"#{@groupID}")
                m.appID("value"=>"#{@appID}")
                m.penalty("value" => "#{@penalty}")
            }
            j.cluster("partitionID" => "#{@partitionID}",
                    "queueID" => "#{@queueID}")
            j.dependency("preceedingJobID"=>"#{@preceedingJobID}",
                "timeAfterPreceedingJob"=>"#{@timeAfterPreceedingJob.to_i}")
        }
    end 
    def readSWFFormat(line)
        items = line.split()
        @jobID = items[0].to_i
        @submitTime = items[1].to_i
        @waitTime = items[2].to_i
        @runTime = items[3].to_i
        @numberAllocatedProcessors = items[4].to_i
        @averageCPUTimeUsed = items[5].to_i
        @usedMemory = items[6].to_i
        @reqNumProcessors = items[7].to_i
        @wallTime = items[8].to_i
        @reqMemory = items[9].to_i
        @status = items[10].to_i
        @userID = items[11].to_i
        @groupID = items[12].to_i
        @appID = items[13].to_i
        @queueID = items[14].to_i
        @partitionID = items[15].to_i
        @preceedingJobID = items[16].to_i
        @timeAfterPreceedingJob = items[17].to_i
    end
    ###
    ## Splits a job in two parts for coallocation. 
    ## The nodes are divided by two, and all other parameters are
    ## left intact. So one job is split in two concurrent jobs.
    ## The job IDs are the one of the original job. We expect that they
    ## are embedded in a MultiJob.
    ## Returns an array containing the two cloned jobs.
    #
    def splitJob
        job1=self.deep_clone()
        job2=self.deep_clone()
        newNodes=(@numberAllocatedProcessors / 2).to_i
        if newNodes == 0 # we do not want to have null jobs ;-)
            newNodes = 1
        end
        job1.numberAllocatedProcessors=newNodes
        job2.numberAllocatedProcessors=newNodes
        return job1, job2
    end
    def to_s
        writeSWFFormat()
    end
end

###
## Encapsulates a coallocation job. Contains at least two atomic
## jobs. Behaves like a single job for the manipulations in general,
## but maps certain modifications to the contained atomic jobs.
#
class MultiJob
    attr_accessor :jobs, :runTime, :userID
    ###
    ## Creates a multijob. The given bigJob is
    ## split using bigJob.splitJob(), and the two jobs are used
    ## to initialize the instance.
    #
    def initialize(bigJob)
        job1, job2 = bigJob.splitJob()
        @jobs = Array.new
        @primaryJob = job1
        ###
        ## Mapping some values to the primary job. Redefinition for
        ## other values happens below.
        #
        @runTime = @primaryJob.runTime()
        @userID = @primaryJob.userID()
        self.addJob(job1)
        self.addJob(job2)
    end
    ###
    ## add an atomic job to the multijob.
    #
    def addJob(job)
        # We assume we always have the same ID for all subjobs.
        job.jobID=@primaryJob.jobID()
        @jobs.push(job)
    end
    ###
    ## Iterates over each job.
    #
    def eachJob
        @jobs.each {|j| yield j}
    end
    ###
    ## Returns the individual jobs of this multijob in SWF Format.
    #
    def writeSWFFormat
        retval = ""
        self.eachJob {|j|
            retval += j.writeSWFFormat() + "\n"
        }
        return retval
    end
    ###
    ## Returns a <multijob/> tag with the associated atomic jobs inside.
    #
    def writeXMLFormat(builder)
        builder.multijob("ID" => "#{@primaryJob.jobID}") { |mj|
            self.eachJob {|j|
                j.writeXMLFormat(mj)
            }
        }
    end
    
    ###
    ## The following methods are needed to emulate the behaviour
    ## of a single job.
    #
    def numberAllocatedProcessors
        retval=0
        self.eachJob {|j|
            retval+=j.numberAllocatedProcessors
        }
        return retval
    end
    def submitTime=(newSubmitTime)
        self.eachJob {|j|
            j.submitTime = newSubmitTime
        }
    end
    def submitTime
        return @primaryJob.submitTime
    end
    def jobID=(newID)
        self.eachJob {|j|
            j.jobID = newID
        }
    end
    def jobID
        return @primaryJob.jobID()
    end
    def to_s
        writeSWFFormat()
    end
end

###
## Models the users.
#
class User
    attr_accessor :pricePreference, :perfPreference
    def initialize(id)
        @pricePreference = 0.1
        @perfPreference = 0.9
        @id=id
    end
    def writeXMLFormat(builder)
        builder.user("ID"=>"#{@id}") {|u|
            u.pref("key"=>"price", "weight"=>"#{@pricePreference}")
            u.pref("key"=>"finishtime", "weight"=>"#{@perfPreference}")
        }
    end
end

###
## This class defines the workload as a collection of jobs.
#
class Workload
    include DeepClone
    attr_accessor :jobs, :clusterConfig
    def initialize(clusterConfig)
        @clusterConfig=clusterConfig
        @jobs=Array.new
        @users=Array.new
        @swf=nil
    end
    def to_s
        return "Workload"
    end
    def eachJob
        @jobs.each { |p| yield p }
    end
    def parseSWF(swf)
        @swf=swf    
        swf.each {|line|
            if line !~ /^;/         #this is not a comment line
                current=AtomicJob.new
                current.readSWFFormat(line)
                #print "#{current.jobID} = "+current.to_s
                @jobs[current.jobID.to_i]=current
            end
        }
        @jobs.compact!               # remove all nil elements
    end
    def generateRandomUsers()
        count=@@config.numUsers;
        for i in 0..(count-1)
            current=User.new(i)
            pref=rand
            current.pricePreference = pref
            current.perfPreference = 1-pref
            @users.push(current)
        end
    end
    def linkUsers
        @jobs.each{|job|
            size=@users.size()
            thisUserID=(rand*10).to_i
            job.userID=thisUserID
        }
    end
    def scaleLoadLevel(destinationLoad)
        scaledJobs=self.deep_clone()
        currentLoad=self.calculateLoadLevel()
        scalingFactor=destinationLoad/currentLoad;
        scaledJobs.eachJob{|j|
            j.submitTime = j.submitTime / scalingFactor;
        }
        #print "Scaled new workload to load = #{scaledJobs.calculateLoadLevel}\n"
        return scaledJobs;
    end
    ###
    ## Adds the given workload to this instance. Basically, we need to
    ## iterate over both workloads, and put them in the right sequence. 
    #
    def mergeWorkloadTo(aWorkload)
        aWorkload.addJobs(self.jobs)
        aWorkload.sort!
        @clusterConfig.mergeTo(aWorkload.clusterConfig)
    end
    # Add an array of jobs to the workload.
    def addJobs(additionalJobs)
        @jobs = @jobs | additionalJobs
    end
    # adds an additional job to the workload.
    def addJob(aJob)
        @jobs.push(aJob)
    end
    # Splits the workload in two: We use the splitJob method on
    # all jobs in the workload. Used for coallocation. Returns two
    # workload instances. Example usage:
    # (coallocatedA, coallocatedB) = coallocationWorkload.splitWorkload()
    def splitWorkload()
        # Create new configurations and workloads.
        nodes = (@clusterConfig.nodes / 2).to_i
        smallestJobSize = (@clusterConfig.nodes / 2).to_i
        name = @clusterConfig.name
        leftConfig=ClusterConfig.new("left"+name, nodes, smallestJobSize)
        leftWorkload = Workload.new(@clusterConfig)
        rightConfig=ClusterConfig.new("right"+name, nodes, smallestJobSize)
        rightWorkload = Workload.new(@clusterConfig)
        # Split each job of this workload and add it to the new workloads
        @jobs.each {|j|
            leftJob, rightJob = j.splitJob()
            print "leftJob: \n#{leftJob}\nrightJob: \n#{rightJob}"
            leftWorkload.addJob(leftJob)
            rightWorkload.addJob(rightJob)
        }
        return leftWorkload, rightWorkload
    end
    
    ###
    ## Turns each job in this workload in a multijob. The jobs are splitted in
    ## two parts using job.splitJob().
    #
    def createMultiJobWorkload()
        nodes = (@clusterConfig.nodes / 2).to_i
        smallestJobSize = (@clusterConfig.nodes / 2).to_i
        name = @clusterConfig.name
        retval = Workload.new(@clusterConfig)
        @jobs.each {|j|
            #leftJob, rightJob = j.splitJob()
            #multiJob=MultiJob.new(leftJob, rightJob)
            multiJob=MultiJob.new(j)
            retval.addJob(multiJob)
        }
        return retval        
    end
    
    ###
    ## Sorts the jobs according to their submit time.
    #
    def sort!
        # Strip out eventual nils, then sort accorting to the submit time
        @jobs.compact!
        @jobs.sort! { |a, b|
            a.submitTime <=> b.submitTime
        }
        # Check that the array index equals the job id.
        for i in 0..@jobs.length-1
            @jobs[i].jobID = i+1
        end
    end
    def xmlize(builder)
        @load=self.calculateLoadLevel(); 
        builder.instruct!
        builder.declare! :DOCTYPE, :gridworkload, :PUBLIC, "http://calana.net/schemas/gridworkload/v1/workload.xsd"
        builder.gridworkload("timecorrection"=>"#{@@config.timeCorrection}",
            "load"=>"#{self.calculateLoadLevel}",                  
            "xmlns:gridworkload" => "http://calana.net/gridworkload") {|w|
            builder.comment! "User definitions"
            w.users {|u|
                @users.each{|user|
                    user.writeXMLFormat(u)
                }
            }
            builder.comment! "Job definitions"
            w.jobs {|j|
                @jobs.each {|job|
                    job.writeXMLFormat(j)    
                }
            }
        }
    end
    ###
    ##                     r * n        r: mean runtime, n: mean nodes in job
    ## approximate-load = -------
    ##                     P * a        P: nodes in system, a: mean 
    ##                                                  inter-arrival time
    #
    def calculateLoadLevel()
        lastArrival = 0
        aggRuntime = aggNodes = aggInterarrivalTime = 0
        @jobs.each {|job|
            aggRuntime += job.runTime
            aggNodes += job.numberAllocatedProcessors
            aggInterarrivalTime += (job.submitTime - lastArrival)
            lastArrival = job.submitTime
        }
        @meanRuntime = aggRuntime / @clusterConfig.size.to_f
        @meanNodes = aggNodes / @clusterConfig.size.to_f
        @meanInterArrival = aggInterarrivalTime / @clusterConfig.size.to_f
        #print "Mean Runtime: #{meanRuntime}, Mean Interarrival Time: #{meanInterArrival}\n"
        @load=(@meanRuntime * @meanNodes) / (@clusterConfig.nodes * @meanInterArrival)
        return @load
    end
end

###
## Collects the workloads according to their individual load. 
## Problem: We do not have an exact model to determine a workload for 
## a given load level. Therefore, we must rerun the generator several times.
#
class WorkloadCollection
    def initialize
        @workloads=Hash.new
        # Now, we build the indices we need to have in the workload. 
        # We have for each interval @@config.loadDeviation a slot.
        0.step(1, @@config.loadDeviation) {|step|
            @workloads[step]=nil
        }
    end
    # Adds a workload with unknown load level to the workload collection.
    # The slot it is assigned to must have an deviation of less than 
    # @@config.loadDeviation.
    def addFuzzy(workload)
        loadLevel=workload.calculateLoadLevel()
         @workloads.keys.each{|key|
            numKey=key.to_f
         #   print "numKey: #{numKey}, load-numkey: #{(loadLevel - numKey).abs}\n"
            if ((loadLevel - numKey).abs <= @@config.loadDeviation)
                @workloads[key]=workload
                break
            end
        }
    end
    def addExact(load, workload)
        if (@workloads.has_key?(load))
            @workloads[load]=workload
        else
            raise "The load level you provided was not needed!"
        end
    end
    ###
    ## Are all values between the two indices assigned? Or is there a 
    ## workload missing? Returns true if a workload is assigned for all 
    ## slots between low and high.
    #
    def isDense?(low, high)
        if (! @workloads.has_key?(low) or ! @workloads.has_key?(high))
            raise "Illegal argument: key not present"
        end
        keys=@workloads.keys
        keys.sort!
        keys.each{ |key|
            if ((key >= low) and (key <= high))
                workload=@workloads[key]
                if (workload == nil)
                    return false;
                end
            end
        }
        return true
    end
    # Provides an iterator to walk over all desired load levels.
    def generateEachSlot
        @workloads.keys.each { |p|
            if (p != 0.0) # It doesn't make sense to have *no* load
                yield p 
            end
        }
    end
    def eachWorkload
        keys=@workloads.keys
        keys.each {|key|
            if (key != 0.0)
                yield @workloads[key]
            end
        }
    end
    def printWorkloadOverview
        keys=@workloads.keys
        keys.sort!
        keys.each{ |key|
            workload=@workloads[key]
        #@workloads.each{|slot, workload|
            slotValue="nil"
            if workload != nil
                slotValue=workload.calculateLoadLevel()
            end
            print "Slot #{key} : #{slotValue} \n"
        }
    end
end
