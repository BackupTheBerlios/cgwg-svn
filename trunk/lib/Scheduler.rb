# This file is part of the calana grid workload generator.
# (c) 2009 Mathias Dalheimer, md@gonium.net
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

require 'Workload'
require 'Helpers'
#require 'ruby-debug'

###
## A resource is capable of executing a job. It maintains a queue and
## appends jobs to the local queue when they are submitted. It is also
## possible to remove a job from a queue.
#
class Resource
  attr_accessor :name
  def initialize(name)
    @queue = Array.new
    @name=name
  end
  def popRandomJob()
    raise "No job available - queue is empty" if @queue.empty?
    candidateIndex=rand(@queue.length.to_i)
    #puts "removing job at position #{candidateIndex}" 
    candidate=@queue.delete_at(candidateIndex)
    @queue.compact!
    return candidate
  end
  # Appends a job to the end of the queue. The queues are not scheduled
  # automatically - a caller could add a lot of jobs and trigger the
  # scheduling afterwards.
  def appendJob(newJob)
    @queue.push(newJob)
  end
  # returns a copy of the current queue.
  def getJobQueue
    retval = @queue.clone
    retval.each{|job|
      job.resourceID=name
    }
    return retval
  end
  # Inserts a new job into the queue. The job is inserted in the right
  # position according to its submission time (FIFO). The reschedule
  # method is triggered afterwards.
  def enqueueJob(newJob)
    if (@queue.empty?)
      @queue.push(newJob)
    else
      # Find the right position to insert the job into the queue.
      insertIndex=@queue.size # default: insert at the end of the queue.
      0.upto(@queue.size - 1) { |qindex|
        job=@queue[qindex]
        #puts "job at index #{qindex}: #{job}"
        if (job.submitTime.to_f > newJob.submitTime.to_f)
          # We found our place - the new job must be enqueued in front
          # of this one.
          #puts "Inserting newJob (SubmitTime=#{newJob.submitTime}) in front of existing job (SubmitTime=#{job.submitTime})" if $verbose
          insertIndex=qindex
          break
        end
      }
      # Array.insert inserts a new element *before* the given index.
      @queue.insert(insertIndex, newJob)
    end
    reSchedule()
  end
  # Rebuilds the timing information of the jobs in the queue. Namely,
  # startTime, finishTime and queueTime are updated according to the state in the
  # queue.
  # TODO: This could be optimized by only rescheduling the jobs after
  # the insertIndex, see enqueueJob above.
  def reSchedule()
    if (! @queue.empty?)
      freetime=0.0 # at which time index is the resource ready to process a job?
      @queue.each{|job|
        if (freetime < job.submitTime) 
          # the job can run instantly.
          job.startTime=job.submitTime
        else # (freetime >= job.submitTime)
          # The job must wait for the resource to become available.
          job.startTime = freetime
        end
        job.queueTime = job.startTime - job.submitTime
        job.finishTime = job.startTime+job.runTime
        # TODO: runtime or submittime?
        #freetime=job.submitTime + job.runTime
        freetime=job.startTime + job.runTime
      }
    end
  end
  def sanityCheck()
    success=true;
    puts "Performing sanity check for resource #{name}: "
    if (@queue.size >= 2)
      1.upto(@queue.size-1) { |qindex|
        lastjob=@queue[qindex-1]
        currentjob=@queue[qindex]
        if currentjob.startTime < currentjob.submitTime
          puts " - start time before submit time"
          puts "   * current: #{currentjob} "
          success=false
        end
        if currentjob.startTime < lastjob.finishTime
          puts " - start time before previous job's finishtime"
          puts "   * current: #{currentjob} "
          puts "   * previous: #{lastjob} "
          success=false
        end
        if currentjob.submitTime < lastjob.submitTime
          puts " - submit time before previous job's submit time"
          puts "   * current: #{currentjob} "
          puts "   * previous: #{lastjob} "
          success=false
        end
      }
    end
    success ? (puts "--- OK.") : (puts "--- FAILED!")
  end
  def size
    return @queue.size
  end
  def to_s
    retval = "Resource #{name} (#{size} jobs, QT (abs/avg): #{absoluteQueueTime}/#{averageQueueTime})\n"
    if $verbose
      retval += "Current queue:\n"
      @queue.each {|job|
        retval += "#{job.jobID} "
      }
    end
    retval
  end
  def absoluteQueueTime
    absQueueTime=0.0
    @queue.each{|job|
      absQueueTime+=job.queueTime
    }
    return absQueueTime
  end
  def averageQueueTime
    return (absoluteQueueTime / @queue.size.to_f)
  end
  # Returns a number corresponding to the quality of the current queue.
  def averageQuality
    return averageQueueTime
  end
  def absoluteQuality
    return absoluteQueueTime
  end
end

###
## A Schedule is a mapping of jobs to resources.
#
class Schedule
  include DeepClone
  attr_reader :workload, :resources
  # provide the workload and an array of resources.
  def initialize(workload, resources)
    raise "workload must be a workload type!" unless workload.kind_of? Workload
    raise "resources must be an array of resource types!" unless resources.kind_of? Array
    resources.each{|resource|
      raise "invalid resource definition: #{resource}" unless resource.kind_of? Resource
    }
    raise "please provide at least one resource" if resources.empty?
    @workload=workload
    @resources=resources
  end
  def getSolution
    retval=Array.new
    @resources.each{|resource|
      retval << resource.clone
    }
    retval
  end
  def setSolution(newSolution)
    @resources=newResources
    # The solution only saves the queue assignments. recalculate the
    # schedules in order to update the workload.
    @resources.each{|resource|
      resource.reSchedule();
    }
  end 
  # takes a job from one resource and puts it on another one.
  def permutateJobs()
    success=false
    while (! success)
      begin
        # randomly select two resources to swap jobs.
        resourceId1=rand(@resources.size)
        begin
          resourceId2=rand(@resources.size)
        end while resourceId1 == resourceId2
        puts "Swapping job from resource#{resourceId1} to resource#{resourceId2}" if $verbose
        job=@resources[resourceId1].popRandomJob()
        @resources[resourceId2].enqueueJob(job)
        success=true
      rescue Exception
        puts "Cannot pop from empty queue, new try." if $verbose
      end
    end
  end
  # creates an initial solution for the scheduling problem.
  def initialSolution
    #initialSolutionFirstResource()
    #initialSolutionRoundRobinResource()
    initialSolutionRandomResource()
  end
  def initialSolutionFirstResource
    firstResource=@resources[0]
    @workload.eachJob{|job|
      firstResource.appendJob(job)
    }
    firstResource.reSchedule();
  end
  def initialSolutionRoundRobinResource
    nextResourceId=0;
    @workload.eachJob{|job|
      nextResourceId=(nextResourceId + 1).modulo(@resources.size);
      @resources[nextResourceId].appendJob(job)
    }
    @resources.each{|resource|
      resource.reSchedule();
    }
  end
  def initialSolutionRandomResource
    @workload.eachJob{|job|
      resourceId=rand(@resources.size)
      @resources[resourceId].appendJob(job)
    }
    @resources.each{|resource|
      resource.reSchedule();
    }
  end
  def sanityCheck
    @resources.each{|resource|
      resource.sanityCheck()
    }
  end
  def assessSchedule
    #return assessAverageQualitySchedule
    return assessAbsoluteQualitySchedule
  end
  def assessAbsoluteQualitySchedule
    absQuality=0.0
    @resources.each{|resource|
      absQuality+=resource.absoluteQuality()
    }
    return absQuality 
  end

  def assessAverageQualitySchedule
    avgQuality=0.0
    @resources.each{|resource|
      avgQuality+=resource.averageQuality()
    }
    return (avgQuality / @resources.size.to_f)
  end
  def renderResourceString
    retval=""
    @resources.each{|resource|
      retval += resource.to_s 
    }
    retval
  end
  def collectSchedule
    alljobs=Array.new
    @resources.each{|resource|
      jobqueue=resource.getJobQueue()
      alljobs = alljobs + jobqueue
    } 
    alljobs.sort! { |a,b|
      a.jobID <=> b.jobID
    }
    return alljobs
  end
  def renderSchedule
    jobs=collectSchedule
    retval=""
    jobs.each{|job|
      retval += job.to_s + "\n"
    }
    retval
  end
  def renderToTable
    retval = renderResourceString 
    retval += renderSchedule
  end
  def to_s
    renderToTable
  end
end

class GeometricCoolingSchedule
  def initialize(minTemp, maxTemp, alpha)
    raise "minTemp must be greater than zero!" unless minTemp > 0
    raise "alpha must be in ]0,1[!" unless (alpha > 0 and alpha < 1)
    @maxTemp=maxTemp
    @minTemp=minTemp
    @alpha=alpha
  end
  def getTemperatures()
    retval=Array.new
    current=@maxTemp
    while( current >= @minTemp )
      retval << current
      current=@alpha * current
    end
    retval
  end
end


# Test routines below - execute this file directly...
if __FILE__ == $0
  $verbose=true;
  # This would normally come from the command line - hardcoded for
  # testing here. The Workload is assumed to be stored in
  # var/testworkload.
  storePath="var/testworkload/workload-wcollection.bin"
  loadlevel=0.75
  puts "# Unmarshalling the store #{storePath}"
  store=File.new(storePath, "r");
  collection = Marshal.load(store);
  store.close;

  workload=collection.getWorkload(loadlevel);
  if (workload == nil)
    puts "The workload with loadlevel = #{loadlevel} is not available."
    puts("The store claims these workloads:")
    collection.printWorkloadOverview()
    exit
  end

  puts "# Using workload with real load #{workload.load} and #{workload.clusterConfig.nodes} nodes."

  if $verbose
    puts "Printing workload:"
    workload.eachJob{|job|
      puts job
    }
  end

  # todo: generate this from the workload itself.
  resource1=Resource.new("Resource1")
  resource2=Resource.new("Resource2")
  resource3=Resource.new("Resource3")

  resourceSet=Array.new
  resourceSet.push(resource1)
  resourceSet.push(resource2)
  resourceSet.push(resource3)

  schedule=Schedule.new(workload, resourceSet)
  schedule.initialSolution
  initialEnergy=schedule.assessSchedule();
  puts "Found initial energy of #{initialEnergy}"

  for i in 0..2 do
    backup=schedule.deep_clone()
    schedule.permutateJobs();
    schedule=backup;
    newEnergy=schedule.assessSchedule
    schedule.sanityCheck()
    if (newEnergy != initialEnergy)
      puts "Shit, they differ: newEnergy=#{newEnergy}, initialEnergy=#{initialEnergy}"
    else
      puts "Check."
    end
  end


end
