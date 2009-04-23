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

require 'Utils'
require 'statistics'

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
        :timeAfterPreceedingJob, :startTime, :queueTime, :finishTime, :resourceID,
        :price
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
        @groupID = 0
        @appID = -1
        @penalty = 0
        @queueID = 0
        @partitionID = -1
        @preceedingJobID = -1
        @timeAfterPreceedingJob = -1
        # These attributes are needed for the ruby scheduler
        # implementation
        @queueTime = 0.0
        @startTime = 0.0
        @finishTime = 0.0
        @resourceID = "N/A"
        @price = 0.0
    end
    def writeSWFFormat
        retval = "#{@jobID}\t#{@submitTime}\t#{@waitTime}\t#{@runTime}\t"
        retval += "#{@numberAllocatedProcessors}\t#{@averageCPUTimeUsed}\t"
        retval += "#{@usedMemory}\t#{@reqNumProcessors}\t#{@wallTime}\t"
        retval += "#{@reqMemory}\t#{@status}\t#{@userID}\t#{@groupID}\t"
        retval += "#{@appID}\t#{@queueID}\t#{@partitionID}\t"
        retval += "#{@preceedingJobID}\t#{@timeAfterPreceedingJob}\n"
    end
    def AtomicJob.get_R_header
      retval="jid submittime runtime walltime " 
      retval+="numprocessors"
    end
    def to_R_format
      retval="#{@jobID.to_f} #{@submitTime} #{@runTime} #{@wallTime} " 
      retval+="#{@numberAllocatedProcessors}"
    end
    def writeXMLFormat(builder)
      builder.job("id" => "job-#{@jobID}") { |j| 
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
          m.userID("value"=>"user-#{@userID}")
          m.groupID("value"=>"group-#{@groupID}")
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
    # Human-readable data.
    def to_s
      retval="Jid: #{@jobID.to_i} SUBT:#{"%.2f" % @submitTime} STARTT: #{"%.2f" % @startTime} "
      retval+="RT:#{"%.2f" % @runTime} WT:#{"%.2f" % @wallTime} " 
      retval+="P:#{"%.2f" % @price} "
      retval+="NODES: #{@numberAllocatedProcessors} R: #{@resourceID}"
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
    builder.user("id"=>"user-#{@id}") {|u|
      u.pref("key"=>"price", "weight"=>"#{@pricePreference}")
      u.pref("key"=>"finishtime", "weight"=>"#{@perfPreference}")
    }
  end
end

###
## Encapsulates the task tag in the workload XML file.
#
class Task
  attr_accessor :id
  ###
  ## Create a new task. type must be a string of either "sequence"
  ## or "coallocation" and describes how the associated jobs are
  ## related.
  #
  def initialize(id, type)
    @id = id
    @type = type
    @jobs = []
  end
  # Adds a single job.
  def addJob(job)
    @jobs.push(job)
  end
  # Add an array of jobs to the tasks.
  def addJobs(additionalJobs)
    @jobs = @jobs | additionalJobs
  end
  def writeXMLFormat(builder)
    builder.task("id"=>"task-#{@id}", "type"=>"#{@type}") {|t|
      @jobs.each {|j|
        t.part("job-ref"=>"job-#{j.jobID}")
      }
    }
  end
  # Determines the earliest submit time of all jobs in this task.
  def getEarliestSubmitTime()
    retval = @jobs[0].submitTime()
    @jobs.each {|j|
      if retval > j.submitTime
        retval = j.submitTime
      end
    }
    return retval
  end
  def eachJob
    @jobs.each { |p| yield p }
  end
end

###
## Represents a sample which can be added or subtracted from an
## accumulator variable. Usage:
## accumulator = 0
## sample = AccumulatorSampleEvent(time)
## sample.addAmount(4) // or: sample.subAmount(4)
## accumulator = sample.accumulate(accumulator)
## => 4
#
class AccumulatorSampleEvent 
  include Comparable
  attr_accessor :time
  def initialize(time)
    @time=time
    @amount = 0
    @add=false
    @sub=false
  end
  def addAmount(a)
    if (a < 0 )
      raise "Invalid amount!"
    end
    @amount = a
    @add=true
  end
  def subAmount(a)
    if (a < 0)
      raise "Invalid amount!"
    end
    @amount = a
    @sub=true
  end
  def <=>(other)
    @time <=> other.time
  end
  def accumulate(accumulator)
    if @add
      accumulator=accumulator + @amount
    end
    if @sub
      accumulator=accumulator - @amount
    end
    return accumulator, @time
  end
  def to_s
    retval = "#{@time}: "
    if @add
      retval << "+#{@amount}"
    end
    if @sub
      retval << "-#{@amount}"
    end
    return retval
  end
end



###
## This class defines the workload as a collection of jobs.
#
class Workload
  include DeepClone
  attr_accessor :jobs, :clusterConfig, :tasks, :load
  def initialize(clusterConfig)
    @clusterConfig=clusterConfig
    @jobs=Array.new
    @users=Array.new
    @tasks=Array.new
    @swf=nil
  end
  def to_s
    return "Workload with #{@clusterConfig.nodes} nodes"
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
  def getUserByID(userID)
    return @users[userID]
  end
  def writeSWFFormat()
    retval=""
    @jobs.each{|job|
      retval += job.writeSWFFormat()
    }    
    return retval
  end
  def generateRandomUsers()
    count=@@config.numUsers
    for i in 0..(count-1)
      current=User.new(i)
      pref=rand
      current.pricePreference = pref
      current.perfPreference = 1-pref
      @users.push(current)
    end
  end
  def generateDoubleGaussUsers()
    count=@@config.numUsers
    gaussRand=generateDoubleGaussianRandoms(count) #TODO testen!
    gaussRand.shuffle!
    for i in 0..(count-1)
      current=User.new(i)
      pref=gaussRand.pop
      current.pricePreference = pref
      current.perfPreference = 1-pref
      @users.push(current)
    end
  end
  ###
  ## Links the users with the tasks on a random basis.
  def linkUsers
    size=@users.size()
    @tasks.each{|task|
      thisUserID=(rand(size.to_i))
      #puts "considering task #{task}, userID = #{thisUserID}"
      task.eachJob{|job|
        #puts "subjob: userID = #{thisUserID}"
        job.userID=thisUserID
      }
    }
  end
  ###
  ## Checks for strange jobs that have both a submitTime and runTime of zero.
  ## Use for debugging.
  #
  def checkForNullJobs
    @jobs.each{|job|
      if (job.runTime == 0 and job.submitTime == 0)
        print("Found invalid job: #{job}")
      end
    }
  end
  ###
  ## Scales the load level to another value. Iterates over all jobs, modifies the
  ## submission time, and returns a new workload.
  #
  def scaleLoadLevel(destinationLoad)
    scaledJobs=self.deep_clone()
    currentLoad=self.calculateLoadLevel()
    scalingFactor=destinationLoad/currentLoad;
    puts "Will scale current load #{currentLoad} to #{destinationLoad} using factor #{scalingFactor}"
    scaledJobs.eachJob{|j|
      #j.submitTime = j.submitTime * scalingFactor;
      #j.submitTime = j.submitTime / scalingFactor;
      j.runTime = j.runTime * scalingFactor;
      j.runTime = 1 if j.runTime < 1;
      j.wallTime = j.wallTime * scalingFactor;
      j.wallTime = 1 if j.wallTime < 1;
    }
    print "Scaled workload (load = #{currentLoad}) to load = #{scaledJobs.calculateLoadLevel}\n"
    return scaledJobs;
  end
  ###
  ## Adds the given workload to this instance. Basically, we need to
  ## iterate over both workloads, and put them in the right sequence.
  ## Right sequence means: Job are sorted according to their submission
  ## time. Please note that this might lead to problems regarding the 
  ## distribution of submission times - use appendWorkloadTo instead.
  #
  def mergeWorkloadTo(aWorkload)
    puts "mergeWorkloadTo is deprecreated! use appendWorkloadTo instead"
    aWorkload.addJobs(self.jobs)
    aWorkload.addTasks(self.tasks)
    aWorkload.sort!
    aWorkload.fixJobIndices
    @clusterConfig.mergeTo(aWorkload.clusterConfig)
  end

  # appends this workload to the given workload. the submission times of
  # this workload are adjusted so that these jobs start after the jobs
  # in the given workload.
  def appendWorkloadTo(aWorkload)
    offset = aWorkload.maxSubmitTime()
    shiftJobSubmissionTime(offset)
    aWorkload.addJobs(self.jobs)
    aWorkload.addTasks(self.tasks)
    aWorkload.fixJobIndices
    @clusterConfig.mergeTo(aWorkload.clusterConfig)
  end

  # for all jobs, add an offset to the submission time.
  def shiftJobSubmissionTime(offset)
    jobs.each{|job|
      job.submitTime+=offset
    }
  end
  # Add an array of jobs to the workload.
  def addJobs(additionalJobs)
    @jobs = @jobs | additionalJobs
  end
  def addTasks(additionalTasks)
    @tasks = @tasks | additionalTasks
  end
  # adds an additional job to the end of the workload.
  def addJob(aJob)
    @jobs.push(aJob)
  end
  # Turns each job in this workload in a multijob. The jobs are splitted in
  # two parts using job.splitJob().
  def createCoallocationJobWorkload()
    nodes = (@clusterConfig.nodes / 2).to_i
    smallestJobSize = (@clusterConfig.nodes / 2).to_i
    name = @clusterConfig.name
    newConfig=ClusterConfig.new(name, nodes, smallestJobSize, @jobs.length)
    retval = Workload.new(newConfig)
    @jobs.each {|j|
      leftJob, rightJob = j.splitJob()
      retval.addJob(leftJob)
      retval.addJob(rightJob)
      retval.buildCoallocationTask(leftJob, rightJob)
    }
    return retval        
  end
  def createSequentialJobWorkload()
    retval = Workload.new(@clusterConfig)
    @jobs.each {|j|
      retval.addJob(j)
      retval.buildSequentialTask(j)
    }
    return retval
  end
  # Adds a new task for the given job to the task list.
  def buildSequentialTask(job)
    task=Task.new(@tasks.length, "sequence")
    task.addJob(job)
    @tasks.push(task)
  end
  # Adds a new coallocation task consisting of the given jobs
  # to the task list.
  def buildCoallocationTask(job1, job2)
    task=Task.new(@tasks.length, "coallocation")
    task.addJob(job1)
    task.addJob(job2)
    @tasks.push(task)
  end
  ###
  ## Sorts the jobs according to their submit time. The task structure is
  ## adjusted as well.
  #
  def sort!
    # Strip out eventual nils, then sort accorting to the submit time
    @jobs.compact!
    @jobs.sort! { |a, b|
      a.submitTime <=> b.submitTime
    }
    @tasks.sort! { |a,b|
      a.getEarliestSubmitTime <=> b.getEarliestSubmitTime
    }
  end
  # Check that the array index equals the job id. otherwise, the
  # produced XML will have mixed indices...
  def fixJobIndices
    for i in 0..@jobs.length-1
      @jobs[i].jobID = i+1
    end
    # same for tasks.
    for i in 0..@tasks.length-1
      @tasks[i].id = i+1
    end
  end
  # calculate the mean runtime of this workload
  def calculateMeanRuntime
    aggRuntime = 0
    count = 0
    @jobs.each {|job|
      aggRuntime += job.runTime
      count += 1
    }
    return aggRuntime / count;
  end
  def xmlize(builder)
    @load=self.calculateLoadLevel(); 
    meanRuntime = calculateMeanRuntime();
    builder.instruct!
    builder.declare! :DOCTYPE, :gridworkload, :SYSTEM, "workload.dtd"
    builder.gridworkload("timecorrection"=>"#{@@config.timeCorrection}",
            "load"=>"#{self.calculateLoadLevel}", "meanRuntime" => "#{meanRuntime}",                 
            "xmlns:gridworkload" => "http://calana.net/gridworkload") {|w|
      builder.comment! "User definitions"
      w.users {|u|
        @users.each{|user|
          user.writeXMLFormat(u)
        }
      }
      builder.comment! "Task structure definition"
      w.tasks {|t|
        @tasks.each {|task|
          task.writeXMLFormat(t)
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
  def estimateLoadLevel()
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


  ###
  ## Calculate load level of this workload using the sample method
  # 
  def calculateLoadLevel()
    puts "calculating load level for #{self}" if $verbose
    capacity = @clusterConfig.nodes
    @events=Array.new
    @jobs.each{|job|
      ###
      ## Todo: Think about the timing!
      #
      startTime=job.submitTime
      endTime=startTime + job.runTime
      size=job.numberAllocatedProcessors
      startEvent=AccumulatorSampleEvent.new(startTime)
      startEvent.addAmount(size)
      @events.push(startEvent) 
      endEvent=AccumulatorSampleEvent.new(endTime)
      endEvent.subAmount(size)
      @events.push(endEvent)
    }
    @events.sort!
    maxTime = 0
    accumulator = 0
    lastEventTime=0
    sumLoadSamples = 0.0
    @events.each{|event|
      accumulator, eventTime=event.accumulate(accumulator)
      # Update max values
      maxTime = event.time if eventTime > maxTime
      sumLoadSamples += (accumulator.to_f * (eventTime - lastEventTime))
      lastEventTime = eventTime
    }
    @load = sumLoadSamples / (capacity * maxTime)
    return @load
  end
  def maxRuntime()
    maxRuntime=0
    @jobs.each{|job|
      if (job.runTime > maxRuntime)
        maxRuntime = job.runTime
      end
    }
    return maxRuntime
  end
  def maxSubmitTime()
    maxSubmitTime=0
    @jobs.each{|job|
      if (job.submitTime > maxSubmitTime)
        maxSubmitTime = job.submitTime
      end
    }
    return maxSubmitTime
  end

  def size()
    return @jobs.size
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
  def getWorkload(loadlevel)
    return @workloads[loadlevel]
  end
  # returns a schedule instance unmarshalled from the given file path.
  def WorkloadCollection.instanceFromFile(workloadCollectionFile)
    retval=nil;
    File.open(workloadCollectionFile, "r") {|file|
      retval=Marshal::load(file)
    }
    retval
  end

  def printWorkloadOverview
    puts to_s
  end
  def getLoadlevels
    keys=@workloads.keys
    keys.sort!
  end
  def to_s
    retval=""
    keys=@workloads.keys
    keys.sort!
    keys.each{ |key|
      workload=@workloads[key]
      slotValue="nil"
      if workload != nil
        slotValue=workload.calculateLoadLevel()
      end
      retval += "Slot #{key}: load #{slotValue} \n"
    }
    return retval
  end
    
end

# Provides various analysis methods for workloads.
class WorkloadAnalysis
  def initialize(workload, outdir)
    @workload=workload
    @outdir=outdir
    @capacity = @workload.clusterConfig.nodes
    @loadlevel=@workload.calculateLoadLevel()
    @levelString = sprintf("%1.3f", @loadlevel)
    @runner = RRunner.new(@outdir)
  end
  def writeRDatafile()
    reportFileName = "rtable-"+@levelString+".txt"
    @fullDataFileName = File.expand_path(File.join(@outdir,reportFileName))
    @datafile = File.new(@fullDataFileName, "w")
    puts "creating R export file #{fullDataFileName}" if $verbose
    @datafile.puts(AtomicJob.get_R_header())
    @workload.eachJob{|job|
      jobline=job.to_R_format;
      puts jobline if $verbose
      @datafile.puts(jobline);
    }
    @datafile.puts("\n")
    @datafile.close
  end
  def plot_Runtimes()
    drawcmd=<<-END_OF_CMD
      plot(data$jid, data$runtime,
        main="Runtimes for all jobs",
        xlab="Job ID",
        ylab="Runtime [s]"
      )
    END_OF_CMD
    outfile="runtimes-"+@levelString
    @runner.execute(@fullDataFileName, outfile, drawcmd)
  end
  def plot_submissiontimes()
    drawcmd=<<-END_OF_CMD
      plot(data$jid, data$submittime,
        main="Submittime for all jobs",
        xlab="Job ID",
        ylab="Submittime [s]"
      )
    END_OF_CMD
    outfile="submittime-"+@levelString
    @runner.execute(@fullDataFileName, outfile, drawcmd)
  end

  def plot_interarrivaltimes()
    drawcmd=<<-END_OF_CMD
      iat<-array()
      for (i in 2:length(data$submittime)) {
        iat<-append(iat, (data$submittime[i] - data$submittime[i-1]))
      }
      plot(data$jid, iat,
        main="Job interarrival time for all jobs",
        xlab="Job ID",
        ylab="Interarrival time [s]"
      )
    END_OF_CMD
    outfile="interarrival-"+@levelString
    @runner.execute(@fullDataFileName, outfile, drawcmd)
  end

  def plot_interarrivaltimes_histogram()
    drawcmd=<<-END_OF_CMD
      iat<-array()
      for (i in 2:length(data$submittime)) {
        iat<-append(iat, (data$submittime[i] - data$submittime[i-1]))
      }
      hist(iat,
        main="Histogram: Job interarrival times",
        xlab="Interarrival time [s]"
      )
    END_OF_CMD
    outfile="interarrival-hist-"+@levelString
    @runner.execute(@fullDataFileName, outfile, drawcmd)
  end


  def plot_numprocessors()
    drawcmd=<<-END_OF_CMD
      plot(data$jid, data$numprocessors,
        main="Requested processors for all jobs",
        xlab="Job ID",
        ylab="# Processors"
      )
    END_OF_CMD
    outfile="req-processors-"+@levelString
    @runner.execute(@fullDataFileName, outfile, drawcmd)
  end
  def plot_SubmittimeHistogram()
    drawcmd=<<-END_OF_CMD
      hist(data$submittime,
        main="Histogram of submission times",
        xlab="Time [s]",
        ylab="Frequency"
      )
    END_OF_CMD
    outfile="histsubmittime-"+@levelString
    @runner.execute(@fullDataFileName, outfile, drawcmd)
  end
  def plot_RuntimeHistogram()
    drawcmd=<<-END_OF_CMD
      hist(data$runtime,
        main="Histogram of runtimes",
        xlab="Time [s]",
        ylab="Frequency"
      )
    END_OF_CMD
    outfile="histruntimes-"+@levelString
    @runner.execute(@fullDataFileName, outfile, drawcmd)
  end
  
  def plotGraphs
    writeRDatafile()
    methods.grep(/^plot_/){|m|
      self.send(m)
    }
    sleep(1)
  end

 
  def plotUtilization()
    maxTime = 0
    maxNodes = 0
    intermediateTimeStep=100
    @events=Array.new
    puts ("Sampling load data for each loadlevel - using intermediateTimeStep=#{intermediateTimeStep}") if $verbose
    datafilepath=File.expand_path(File.join(@outdir, "allocationsamples-#{@levelString}.txt"))
    picfilepath=File.expand_path(File.join(@outdir,"/allocationsamples-#{@levelString}.eps"))
    puts("Working on load level #{@loadlevel}, sampling to #{datafilepath}")
    datafile=File.new(datafilepath, "w")
    datafile.print("time\trequested nodes\n")
    @workload.eachJob{|job|
      ###
      ## Todo: Think about the timing!
      #
      startTime=job.submitTime
      endTime=startTime + job.runTime
      size=job.numberAllocatedProcessors
      startEvent=AccumulatorSampleEvent.new(startTime)
      startEvent.addAmount(size)
      endEvent=AccumulatorSampleEvent.new(endTime)
      endEvent.subAmount(size)
      @events.push(startEvent) 
      @events.push(endEvent)
    }
    @events.sort!
    accumulator = 0
    lastEventTime=0
    sumLoadSamples = 0.0
    @events.each{|event|
      #puts "Processing: #{event}"
      #puts "before: #{accumulator}"
      oldAccumulator=accumulator
      accumulator, eventTime=event.accumulate(accumulator)
      #puts "got: acc=#{accumulator}, time=#{eventTime}"
      #puts "after: #{accumulator}"
      intermediateTime=lastEventTime
      while (intermediateTime < eventTime)
        datafile.print("#{intermediateTime}\t#{oldAccumulator}\n")
        intermediateTime+=intermediateTimeStep
      end
      datafile.print("#{event.time}\t#{accumulator}\n")
      puts "#{event.time}\t#{accumulator}" if $verbose
      # Update max values
      maxTime = event.time if eventTime > maxTime
      maxNodes = accumulator if accumulator > maxNodes
      sumLoadSamples += (accumulator.to_f * (eventTime - lastEventTime))
      lastEventTime = eventTime
      #puts "Load info: sum=#{sumLoadSamples}, numLoadSamples=#{numLoadSamples}, lastEventTime=#{lastEventTime}"
    }
    datafile.close
    avgLoad = sumLoadSamples / (@capacity * maxTime)
    puts "The average load for @loadlevel #{@loadlevel} is #{avgLoad}, maxNodes = #{maxNodes}"
    puts "Maximum nodes: #{maxNodes}, maximum time: #{maxTime}"
    #levels.each{|@levelString|
    #  datafilepath=@outdir+"/allocationsamples-#{@levelString}.txt"
    #  picfilepath=@outdir+"/allocationsamples-#{@levelString}.eps"
    puts "Plotting workload..." if $verbose
    gnuPlot2Lines(datafilepath, picfilepath, "Accumulated allocation (load = #{@levelString})", "time", "requested nodes", 1, 2, maxTime, maxNodes)
    #}
  end
end

