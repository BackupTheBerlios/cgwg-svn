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
end

require 'Workload'
require 'Helpers'
#require 'Dataplot'
require 'R'
require 'Latex'
require 'optparse'
require 'ostruct'

# Constants for context of the job description...
SEQUENCE = 1;
COALLOCATION = 2;

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
            opts.banner = "Usage: calana2report.rb [options]"
            opts.separator ""
            opts.separator "Specific options:"
            # Mandatory argument.
            opts.on("-r", "--report FILE", "the report file in calanasim format") do |reportFile|
                options.reportfile=reportFile
            end
            opts.on("-t", "--trace FILE", "the trace file in calanasim format") do |reportFile|
                options.tracefile=reportFile
            end
            opts.on("-o", "--output directory","the output directory for the report files") do |outdir|
                options.outdir=outdir
            end
            opts.on("-l", "--load FLOAT", "the load level of the run") do |load|
                options.load = load
            end
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


class Float
  def to_s
    #force all Floats to 2 decimal places
    "%.2f" % self
  end
end 

###
## Job abstraction class
#
class Job
  attr_accessor :type, :responseTime, :jid, :price, :minprice, :maxprice, :pricePref,
    :perfPref, :runTime, :queueTime, :startTime, :endTime, :minfinishtime, :maxfinishtime,
    :agent, :submitTime, :eventState
  def initialize(jid)
    @jid=jid
    @pricePref=0.0
    @perfPref=0.0   
    @responseTime=@runTime=@queueTime=0
  end
  def check
    puts "job #{@jid}: negative queueTime: #{@queueTime}" if @queueTime < 0
    puts "job #{@jid}: negative runtime: #{@runTime}" if @runTime <= 0
    puts "job #{@jid}: invalid responseTime: #{@responseTime}" if @eventState == "CLOSE" && @responseTime < (@runTime + @queueTime)
    puts "job #{@jid}: invalid responseTime: is #{@responseTime} but should be 0" if @eventState == "KILLED" && @responseTime != 0
    puts "job #{@jid}: invalid preferences: #{@pricePref}-#{@perfPref}" if (@pricePref+@perfPref) != 1
  end
  def setPrefs(perfPref, pricePref)
    @perfPref=Float(perfPref);
    @pricePref=Float(pricePref);
    #puts("Updating prefs: perf=#{perfPref}, price=#{pricePref}")
  end
  def to_dataplot_format
    retval="#{@jid.to_f} #{pricePref} #{@price} #{(@price/@runTime)} "
    retval+="#{@perfPref} #{@runTime} #{@queueTime} #{@responseTime} #{@minprice} #{@maxprice}" 
  end
  def to_R_format
    retval="#{@jid.to_f} #{pricePref} #{@price} #{(@price/@runTime)} #{@minprice} #{@maxprice} "
    retval+="#{@perfPref} #{@submitTime} #{@runTime} #{@queueTime} #{@responseTime} "
  end
end

###
## A report that prints the Load vs. Queuetime (QT) table
#
class LoadQTReport
    def initialize(directory, load)
        reportFileName = directory+"/load-QT.txt"
        @load = load
        if (File.exists?("#{reportFileName}"))
            @reportFile = File.new(reportFileName, "a")
        else
            @reportFile = File.new(reportFileName, "w")
            @reportFile.puts("#load\tQT\tlowPerfPref\thighPerfPref")
        end
        @cumulativeQueueTime = 0.0
        @lowQueueTime = 0.0
        @highQueueTime = 0.0
        @lowCounter = 0
        @highCounter = 0
        @jobCounter = 0
    end
    
    def addJob(job)
        @cumulativeQueueTime += job.queueTime.to_f 
        if job.perfPref.to_f <= 0.25
            puts "LowPerfPref: #{job.queueTime.to_f}\t#{@lowQueueTime}" if $verbose
            @lowQueueTime += job.queueTime.to_f
            @lowCounter += 1
        end
        if job.perfPref.to_f >= 0.75
            puts "HighPerfPref: #{job.queueTime.to_f}\t#{@highQueueTime}" if $verbose
            @highQueueTime += job.queueTime.to_f
            @highCounter += 1
        end
        @jobCounter += 1
    end
    
    def finalize()
        art=lowPerfPref=highPerfPref=0;
        aqt = (@cumulativeQueueTime.to_f / @jobCounter.to_f) unless @jobCounter==0;
        lowPerfPref = (@lowQueueTime.to_f / @lowCounter.to_f) unless @lowCounter==0;
        highPerfPref = (@highQueueTime.to_f / @highCounter.to_f) unless @highCounter==0;
        @reportFile.puts("#{@load}\t#{aqt}\t#{lowPerfPref}\t#{highPerfPref}")
        @reportFile.close
    end
end


###
## A report that prints the Load vs. ART table
#
class LoadARTReport
    def initialize(directory, load)
        reportFileName = directory+"/load-ART.txt"
        @load = load
        if (File.exists?("#{reportFileName}"))
            @reportFile = File.new(reportFileName, "a")
        else
            @reportFile = File.new(reportFileName, "w")
            @reportFile.puts("#load\tART\tlowPerfPref\thighPerfPref")
        end
        @cumulativeResponseTime = 0.0
        @lowResponseTime = 0.0
        @highResponseTime = 0.0
        @lowCounter = 0
        @highCounter = 0
        @jobCounter = 0
    end
    
    def addJob(job)
        @cumulativeResponseTime += job.responseTime.to_f 
        if job.perfPref.to_f <= 0.25
            puts "LowPerfPref: #{job.responseTime.to_f}\t#{@lowResponseTime}" if $verbose
            @lowResponseTime += job.responseTime.to_f
            @lowCounter += 1
        end
        if job.perfPref.to_f >= 0.75
            puts "HighPerfPref: #{job.responseTime.to_f}\t#{@lowResponseTime}" if $verbose
            @highResponseTime += job.responseTime.to_f
            @highCounter += 1
        end
        @jobCounter += 1
    end
    
    def finalize()
        art=lowPerfPref=highPerfPref=0;
        art = (@cumulativeResponseTime.to_f / @jobCounter.to_f) unless (@jobCounter == 0)
        lowPerfPref = (@lowResponseTime.to_f / @lowCounter.to_f) unless (@lowCounter == 0)
        highPerfPref = (@highResponseTime.to_f / @highCounter.to_f) unless (@highCounter == 0)
        @reportFile.puts("#{@load}\t#{art}\t#{lowPerfPref}\t#{highPerfPref}")
        @reportFile.close
    end
end

###
## A report that prints the total revenue for each workload
#
class LoadTotalRevenue
  def initialize(directory, load)
    @reportFileName = directory+"/load-total-revenue.txt"
    @load = load
    @totalRevenue = 0.0
  end

  def addJob(job)
    @totalRevenue += job.price.to_f
  end

  def finalize()
    mode = "w"
    mode = "a" if File.exists?("#{@reportFileName}")
    File.open(@reportFileName, mode) {|handle|
      handle.puts("#load\ttotalRevenue") if mode == "w"
      handle.puts("#{@load}\t#{@totalRevenue}")
      }
  end
end


###
## A report that prints the Load vs. Price table
#
class LoadAvgPriceReport
    def initialize(directory, load)
        reportFileName = directory+"/load-avgprice.txt"
        @load = load
        if (File.exists?("#{reportFileName}"))
            @reportFile = File.new(reportFileName, "a")
        else
            @reportFile = File.new(reportFileName, "w")
            @reportFile.puts("#load\tavgprice\tlowPricePref\thighPricePref")
        end
        @cumulativePrice = 0.0
        @lowPrice = 0.0
        @highPrice = 0.0
        @lowCounter = 0
        @highCounter = 0
        @jobCounter = 0
    end

    def addJob(job)
      @cumulativePrice += job.price.to_f 
      @jobCounter += 1
      if job.pricePref.to_f <= 0.25
        @lowPrice += job.price.to_f
        @lowCounter += 1
      end
      if job.pricePref.to_f >= 0.75
        @highPrice += job.price.to_f
        @highCounter += 1
      end
    end
    
    def finalize()
        avgprice=lowPricePref=highPricePref=0;
        avgprice = (@cumulativePrice.to_f / @jobCounter.to_f) unless (@jobCounter==0)
        lowPricePref = (@lowPrice.to_f / @lowCounter.to_f) unless (@lowCounter==0)
        highPricePref = (@highPrice.to_f / @highCounter.to_f) unless (@highCounter==0)
        @reportFile.puts("#{@load}\t#{avgprice}\t#{lowPricePref}\t#{highPricePref}")
        @reportFile.close
    end
end

###
## A report that prints the price vs. pricePreference and rt vs. perfPref data
#
class PriceRTPrefReport
  def initialize(directory, load)
    @load = load
    reportFileName = directory+"/price-rt-preference-"+load+".txt"
    @reportFile = File.new(reportFileName, "w")
    @reportFile.puts("#pricePerSecond\tpricePref\tqueueTime\tperfPref")
  end

  def addJob(job)
    pricePerSecond = job.price.to_f / job.runTime.to_f
    @reportFile.puts("#{pricePerSecond}\t#{job.pricePref}\t"+
            "#{job.queueTime}\t#{job.perfPref}")
  end

  def finalize()
    @reportFile.close
  end
end

###
## A report that prints the price per run time along time
#
class TimePriceReport
  def initialize(directory, load)
    @load = load
    reportFileName = directory+"/time-price-"+load+".txt"
    @reportFile = File.new(reportFileName, "w")
    @reportFile.puts("#time\tprice")
  end

  def addJob(job)
    pricePerSecond = job.price.to_f / job.runTime.to_f
    @reportFile.puts("#{job.startTime}\t#{pricePerSecond}")
  end

  def finalize()
    @reportFile.close
  end
end

###
## A report that prints the relative difference of the user's price preference to the price range time along time
#
class PricePrefReport
  def initialize(directory, load)
    @load = load
    reportFileName = directory+"/price-pref-"+load+".txt"
    @reportFile = File.new(reportFileName, "w")
    @reportFile.puts("#time\trelUserPref")
  end
    
  def addJob(job)
    relUserPref = 0
    priceSpan = job.maxprice - job.minprice
    if (not priceSpan == 0)
      difference = job.price - priceSpan * job.pricePref - job.minprice
      relUserPref = difference.abs / priceSpan
    end
    @reportFile.puts("#{job.startTime}\t#{relUserPref}")
  end
    
  def finalize()
    @reportFile.close
  end
end

class TotalRevenueReport
  def initialize(directory, load)
    @load = load
    @reportFileName = directory+"/total-revenue-"+load+".txt"

    @totalRunTime = Hash.new(0.0)
    @totalRevenue = Hash.new(0)
  end

  def addJob(job)
    agentName = job.agent.split("-")[1]
    @totalRunTime[agentName] += job.runTime.to_f
    @totalRevenue[agentName] += job.price
  end

  def finalize()
    agents = @totalRevenue.keys
    agents.sort!
    File.open(@reportFileName, "w") {|handle|
      handle.puts("#agent\tavgPricePerSec\ttotalRevenue")
      agents.each {|entity|
        handle.puts("#{entity}\t#{@totalRevenue[entity]/@totalRunTime[entity]}\t#{@totalRevenue[entity]}")
      }
    }
  end
end

###
## A report that prints the queue time along time
#
class QueueTimeReport
  def initialize(directory, load)
    @load = load
    reportFileName = directory+"/queue-time-"+load+".txt"
    @reportFile = File.new(reportFileName, "w")
    @reportFile.puts("#time\tqueue-time-per-second")
  end
    
  def addJob(job)
    queueTimePerSecond = job.queueTime.to_f / job.runTime.to_f
    @reportFile.puts("#{job.startTime}\t#{queueTimePerSecond}")
  end
    
  def finalize()
    @reportFile.close
  end
end

###
## A report that prints the price vs. pricePreference and rt vs. perfPref data
#
class PricePrefCorrelationReport
  def initialize(directory, load)
    @load=load
    reportFileName = directory+"/preference-correlation.txt"
    if (File.exists?("#{reportFileName}"))
      @reportFile = File.new(reportFileName, "a")
    else
      @reportFile = File.new(reportFileName, "w")
      @reportFile.puts("#load\tpricecorrelation\tperfcorrelation")
    end
    @pricePerSeconds=Array.new
    @prices = Array.new
    @pricePrefs = Array.new
    @projectedPrices = Array.new
    @queueTimes=Array.new
    @perfPrefs = Array.new
    @referencePerf = Array.new
  end

  def addJob(job)
    pricePerSecond = job.price.to_f / job.runTime.to_f
    # We want to compare the actual price with the price preference.
    # Therefore, calculate a relative price which gives us a double
    # 0<=relativePrice<=1 - this reflects the relative position of the
    # real price in the price range between minimum and maximum possible
    # price.
    #relativePrice = (job.price.to_f - job.minprice) / (job.maxprice - job.minprice)
    # Alternative: calculate the projected price if the price preference
    # would be applied on a uniformly distributed price range
    # (idealization)
    projectedPrice = (job.maxprice - job.minprice) * job.pricePref.to_f + job.minprice
    @pricePerSeconds << pricePerSecond.to_f
    @prices << job.price.to_f
    @pricePrefs << job.pricePref.to_f
    @projectedPrices << projectedPrice.to_f
    @queueTimes << job.queueTime.to_f
    @perfPrefs << job.perfPref.to_f
    line="real p: #{job.price.to_f}, "
    line+= "min p: #{job.minprice.to_f}, max p: #{job.maxprice.to_f}, "
    line+= "proj. p: #{projectedPrice}, pref: #{job.pricePref.to_f}"
    #puts line 
  end

  ###
  ## Algorithm: See http://en.wikipedia.org/wiki/Correlation
  #
  def calc_correlation(x, y)
    sum_sq_x = 0
    sum_sq_y = 0
    sum_coproduct = 0
    mean_x = x[0]
    mean_y = y[0]
    n = x.length - 1
    for i in 1..n
      sweep = (i - 1.0) / i
      delta_x = x[i] - mean_x
      delta_y = y[i] - mean_y
      sum_sq_x += delta_x * delta_x * sweep
      sum_sq_y += delta_y * delta_y * sweep
      sum_coproduct += delta_x * delta_y * sweep
      mean_x += delta_x / i
      mean_y += delta_y / i 
    end
    pop_sd_x = Math.sqrt( sum_sq_x / n )
    pop_sd_y = Math.sqrt( sum_sq_y / n )
    cov_x_y = sum_coproduct / n
    correlation = cov_x_y / (pop_sd_x * pop_sd_y)
    return correlation
  end

  def finalize()
    #priceCorrelation = calc_correlation(@pricePerSeconds, @pricePrefs)
    priceCorrelation = calc_correlation(@projectedPrices, @prices)
    # TODO: Implement proper correlation of queuetimes
    perfCorrelation = calc_correlation(@queueTimes, @perfPrefs)
    @reportFile.puts("#{@load}\t#{priceCorrelation}\t#{perfCorrelation}")
    @reportFile.close
  end
end

###
## A report that prints a dataplot-compatible representation in a file.
## Then, several reports are printed - see the plotSingle* routines in
## lib/Dataplot.rb.
#
class DataplotReport
  def initialize(directory, load)
    @load = load
    reportFileName = "DP"+load+".DAT"
    fullReportFileName = directory+"/"+reportFileName
    @dp=Dataplot.new(directory, reportFileName, load);
    @reportFile = File.new(fullReportFileName, "w")
    @reportFile.puts("jid pricepref price pricert perfpref rtime qtime resptime")
  end

  def addJob(job)
    jobline=job.to_dataplot_format;
    #puts jobline
    @reportFile.puts(jobline);
  end

  def finalize()
    @reportFile.puts("\n")
    @reportFile.close
    # now, run dataplot to do the analysis.
    @dp.plotSingleRun()
    @dp.ps2pdf()
    @dp.finalize()
  end
end

###
## A report that prints a R-compatible representation of the current
## workload level in a file.
## Then, several reports are printed - see the plotSingle* routines in
## lib/R.rb.
#
class RReport
  def initialize(directory, load)
    @load = load
    reportFileName = "rtable-"+load+".txt"
    fullReportFileName = File.expand_path(File.join(directory,reportFileName))
    @r=RExperimentAnalysis.new(directory, reportFileName, load);
    @reportFile = File.new(fullReportFileName, "w")
    @reportFile.puts("jid pricepref price pricert minprice maxprice perfpref stime rtime qtime resptime")
  end

  def addJob(job)
    jobline=job.to_R_format;
    puts jobline if $verbose
    @reportFile.puts(jobline);
  end

  def finalize()
    @reportFile.puts("\n")
    @reportFile.close
    # now, run R to do the analysis.
    @r.plotSingleRun()
  end
end


class ReportCollection
  def initialize(load)
    @reports = Array.new
    report1 = LoadARTReport.new($outDir, load);
    report2 = LoadAvgPriceReport.new($outDir, load);
    report3 = PriceRTPrefReport.new($outDir, load);
    report4 = PricePrefCorrelationReport.new($outDir, load);
    report5 = LoadQTReport.new($outDir, load);
    report6 = TimePriceReport.new($outDir, load);
    report7 = QueueTimeReport.new($outDir, load);
    report8 = PricePrefReport.new($outDir, load);
    report9 = TotalRevenueReport.new($outDir, load);
    #report10 = DataplotReport.new($outDir, load);
    report10 = RReport.new($outDir, load);
    report11 = LoadTotalRevenue.new($outDir, load);
#    report12 = LatexExperimentReport.new($outDir);
    @reports << report1 << report2 << report3 
    @reports << report4 << report5 << report6
    @reports << report7 << report8 << report9
    @reports << report10 << report11 #<< report12
  end

  def addJob(job)
    job.check();
    @reports.each{|report|
      report.addJob(job)
    }
  end

  def finalize()
    @reports.each{|report|
      report.finalize();
    }
  end
end

# TODO: MAke this more generic - loading of sa-scheduler result files.
def createReport(reportFileName, loadLevel)
  reportFile=File.new(reportFileName, "r")
  reports = ReportCollection.new(loadLevel);

  print "Reading calanasim report file and converting.\n"
  inExplanation = false;
  context = 0;

  reportFile.each_line {|line|
    # We skip the comments - except for the report version.
    if (line =~ /^;/)
      if line =~ /report version/
        fields = line.split(":")
        reportversion = fields[1].strip!
        puts "found report version #{reportversion}"
        if reportversion != "0.6"
          puts "Found different report version, aborting!"
          exit
        end
			end
			next
		end
    # And empty lines.
    if (line =~ /^$/)
      next
    end
    # And debug messages.
    if (line =~ /^[0-9]/)
      next
    end
    # We need to ignore the three field explanation lines.
    if (line =~ /^=/ and not inExplanation)
      inExplanation=true
      next
    end
    if (inExplanation and line =~ /^=/)
      inExplanation = false
      next
    end
    if (inExplanation)
      next
    end

    ###
    ## Now, we have only the job result lines.
    #
    #puts "Analyzing: #{line}" if $verbose 
    fields=line.split("|")

    tid = fields[0].strip!
    type = fields[1].strip!
    if (tid =~ /^task-/)
      if (type =~ /^sequence/)
        context = SEQUENCE 
      elsif (type =~ /^coallocation/)
        context = COALLOCATION
      end
      next
    end

    #puts "Input line: #{line}" if $verbose    
    ###
    ## Read the job description fields
    #
    jid = fields[2].strip!
    jid.sub!("job-", "")
    submitTime = fields[12].strip!
    runTime = fields[15].strip!
    responseTime = fields[19].strip!
    enqueued = fields[13].strip!
    startTime = fields[14].strip!
    endTime = fields[16].strip!
    minfinishtime = fields[17].strip!
    maxfinishtime = fields[18].strip!
    queueTime = startTime.to_i - enqueued.to_i
    puts "Calculated negative queuetime, enqueued=#{enqueued.to_i}, startTime=#{startTime.to_i}" if queueTime < 0
    price = fields[20].strip!
    minprice = fields[21].strip!
    maxprice = fields[22].strip!
    agent = fields[7].strip!
    prefs = fields[8].strip!
    eventState = fields[9].strip!
    prefFields = prefs.split(";")
    #puts "PREF for job #{jid}: #{prefFields}"
    finishtimeField = prefFields[0];
    perfPref = ((finishtimeField.split("="))[1]).gsub(/0,/, "0.")
    pricePrefField = prefFields[1];
    pricePref = ((pricePrefField.split("="))[1]).gsub(/0,/, "0.")
    #puts "perfPref = #{perfPref}, pricePref = #{pricePref}"

    ###
    ## Create a job instance
    #
    j = Job.new(jid)
    j.submitTime = submitTime.to_i
    j.price = price.to_f
    j.minprice = minprice.to_f
    j.maxprice = maxprice.to_f
    j.setPrefs(perfPref, pricePref);
    j.responseTime = responseTime.to_i
    j.runTime = runTime.to_i
    j.queueTime = queueTime.to_i
    j.startTime = startTime.to_i
    j.endTime = endTime.to_i
    j.minfinishtime = minfinishtime.to_i
    j.maxfinishtime = maxfinishtime.to_i
    j.agent = agent
    j.eventState = eventState

    if (context == SEQUENCE)
      puts "SEQUENCE: #{jid} #{submitTime} #{responseTime} #{price}" if $verbose
      j.type=SEQUENCE
    elsif (context == COALLOCATION)
      puts "COALLOCATION: #{jid} #{submitTime} #{responseTime} #{price}" if $verbose
      j.type=COALLOCATION
    end

    reports.addJob(j)
  }
  reports.finalize()
  reportFile.close()
end

class EventStore
  attr_accessor :entityname
  def initialize(entityname)
    @entityname = entityname
    @events=Hash.new
    @currentSample = 0;
    @rate = 0;
    @samples = Array.new
  end
  def addEvent(time, value)
    @events[time.to_i]=value.to_f
    @sorted = nil;
  end
  def getName
    return @entityname
  end
  def prepare(rate)
    @rate = rate
    @currentSample=0;
    currentValue = 0.0
    upperBound = @rate
    @sorted = @events.sort
    @sorted.each {|time, value|
      if (time <= upperBound)
        if currentValue < value
          currentValue = value
        end
      else
        sample = [upperBound, value]
        @samples << sample
        upperBound += @rate
        currentValue = 0
      end
    }
    #@samples.each_pair{|key, value|
    #    puts "Key #{key} -> value #{value}"
    #}
  end
  def hasNext()
    if (@currentSample > @samples.length)
      return false
    else
      return true
    end
  end
  def getNext()
    retval = @samples[@currentSample]
    @currentSample += 1
    return retval
  end
end

class UtilizationReport
  def initialize(directory, load, entities)
    @load=load
    reportFileName = directory+"/utilization-all.txt"
    if (File.exists?("#{reportFileName}"))
      @reportFile = File.new(reportFileName, "a")
    else
      entityHeader = "#entities: "
      @reportFile = File.new(reportFileName, "w")
      entities.each{|e|
        entityHeader << "#{e};"
      }
      @reportFile.puts("#load\ttotalUtilization\tentityUtilizations...")
      @reportFile.puts(entityHeader)
    end
    @samples = Hash.new
    @samples.default = 0.0
    @countSamples = Hash.new
    @countSamples.default=0
    @countEntities = entities.length
    @totalUtilization = 0.0
    @totalSampleCount = 0
  end

  def addSample(entity, value)
    #puts "Adding sample: Entity #{entity}, value #{value}"
    @samples[entity] += value.to_f
    @countSamples[entity] += 1
    @totalUtilization += value.to_f
    @totalSampleCount += 1
  end

  def finalize
    tmpLine = "" 
    entityNames = @samples.keys
    entityNames.sort!
    entityNames.each {|entity|
      avgUtilization = (@samples[entity].to_f/ @countSamples[entity])
      tmpLine << "#{avgUtilization}\t"
    }
    totalUtilization = (@totalUtilization.to_f / @totalSampleCount)
    logLine = "#{@load}\t#{totalUtilization}\t#{tmpLine}"
    puts "Writing logline: #{logLine}"
    @reportFile.puts(logLine)
    @reportFile.close()
  end
end


def processTrace(traceFileName, loadLevel)
  queueLength = Hash.new();
  utilization = Hash.new();

  traceFile=File.new(traceFileName, "r")
  puts "Processing trace file #{traceFileName}"
  @utilReportFile = File.new($outDir+"/utilization-"+loadLevel+".txt", "w")
  @queueReportFile = File.new($outDir+"/queuelength-"+loadLevel+".txt", "w")
  traceFile.each_line {|line|
    line.sub!(/trace./, "") # Drop the trace. prefix.
    line.sub!(/-\ /, "") # Drop the dash.
    line.sub!(/:/, "") # Drop the colon.
    # Print the clean line if requested.
    puts("#{line}") if $verbose
    fields = line.split()
    entity = fields[0]
    proptime = fields[1]
    tmp = proptime.split("@")
    property = tmp[0]
    time = tmp[1].to_i
    value = fields[2]
    puts("#{entity} says: #{property} is #{value} at time #{time}") if $verbose

    if property =~ /queuelength/
      if not queueLength.has_key?(entity)
        es=EventStore.new(entity)
        queueLength[entity]=es
      end
    es = queueLength[entity]
    es.addEvent(time, value)
    elsif property =~ /utilization/
      if not utilization.has_key?(entity)
        es=EventStore.new(entity)
        utilization[entity]=es
      end
    es = utilization[entity]
    es.addEvent(time, value)
    end
  }

#  srate = 100000
  srate = 100
  puts "Sampling trace events with samplingrate #{srate}"

  ###
  ## Prepare our iterator and put the name of the entities in a
  ## header.
  #
  entities = Array.new
  queueLength.each_value{|eventStore|
    eventStore.prepare(srate)
    puts "Initializing #{eventStore.getName()}" if $verbose
    entities << eventStore.getName()
  }
  entities.sort!
  entityHeader = "#entities: "
  entities.each{|e|
    entityHeader << "#{e};"
  }
  @queueReportFile.puts(entityHeader)
  entities = Array.new
  utilization.each_value{|eventStore|
    eventStore.prepare(srate)
    puts "Initializing #{eventStore.getName()}" if $verbose
    entities << eventStore.getName()
  }
  entities.sort!
  entityHeader = "#entities: "
  entities.each{|e|
    entityHeader << "#{e};"
  }
  @utilReportFile.puts(entityHeader)

  utilReporter = UtilizationReport.new($outDir, $load, entities)

  ###
  ## Iterate as long as we don't get an Exception, which signals we're at
  ## the last value
  #
  hasMoreValues = true
  while (hasMoreValues)
    hasMoreQueueValues = true;
    eventTime = 0
    queueValues = Hash.new
    dequeuedValues = 0
    queueLength.each_value{|eventStore|
      entity = eventStore.getName
      if (eventStore.hasNext())
        eventTime, value = eventStore.getNext()
        dequeuedValues += 1
      end
      queueValues[entity]=value
    }
    if dequeuedValues == 0
      hasMoreQueueValues = false;
    end
    queueLogLine = "#{eventTime}\t"
    sorted = queueValues.sort
    sorted.each{|key, value|
      puts "Entity #{key} => value #{value}" if $verbose
      queueLogLine << "#{value}\t"
    }
    puts "Utilization at time #{eventTime}" if $verbose
    hasMoreUtilValues = true;
    dequeuedValues = 0
    utilValues = Hash.new
    utilization.each_value{|eventStore|
      entity = eventStore.entityname
      if (eventStore.hasNext())
        eventTime, value = eventStore.getNext()
        dequeuedValues += 1
      end
      utilValues[entity]=value
      utilReporter.addSample(entity, value)
    }
    if dequeuedValues == 0
      hasMoreUtilValues = false;
    end
    utilLogLine = "#{eventTime}\t"
    tmpLine = ""
    aggregatedUtilization = 0.0
    sorted = utilValues.sort
    sorted.each{|key, value|
      puts "Entity #{key} => value #{value}" if $verbose
      tmpLine << "#{value}\t"
      aggregatedUtilization += value.to_f
    }
    utilLogLine << "#{tmpLine}"
    puts "queuelength-log: #{queueLogLine}\nutilization-log: #{utilLogLine}\n"
    if (not hasMoreUtilValues) and (not hasMoreQueueValues)
      hasMoreValues = false
    end
    @utilReportFile.puts(utilLogLine)
    @queueReportFile.puts(queueLogLine)
  end
  utilReporter.finalize
  @utilReportFile.close
  @queueReportFile.close
end

###
## Script begins here
#
print "calanasim to report converter\n"

options = Optparser.parse(ARGV)

$reportFileName = options.reportfile
$traceFileName = options.tracefile
$outDir = options.outdir
$load = options.load
$verbose = options.verbose

if ($reportFileName == nil and $traceFileName == nil) or
  $outDir == nil or $load == nil
  print "please read usage note (-h)\n"
  exit
end

puts "Using library path #{$:.join(":")}" if $verbose

if ($reportFileName != nil)
  createReport($reportFileName, $load)
end
if ($traceFileName != nil)
  processTrace($traceFileName, $load)
end



