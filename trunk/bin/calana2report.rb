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

require 'lib/Workload'
require 'lib/Helpers'
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

###
## Job abstraction class
#
class Job
    attr_accessor :type, :responseTime, :jid, :price, :pricePref,
            :perfPref, :runTime, :queueTime
    def initialize(jid)
        @jid=jid
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
            puts "LowPref: #{job.responseTime.to_f}\t#{@lowResponseTime}"
            @lowResponseTime += job.responseTime.to_f
            @lowCounter += 1
        end
        if job.perfPref.to_f >= 0.75
            @highResponseTime += job.responseTime.to_f
            @highCounter += 1
        end
        @jobCounter += 1
    end
    
    def finalize()
        art = (@cumulativeResponseTime.to_f / @jobCounter.to_f)
        lowPerfPref = (@lowResponseTime.to_f / @lowCounter.to_f)
        highPerfPref = (@highResponseTime.to_f / @highCounter.to_f)
        @reportFile.puts("#{@load}\t#{art}\t#{lowPerfPref}\t#{highPerfPref}")
        @reportFile.close
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
        avgprice = (@cumulativePrice.to_f / @jobCounter.to_f)
        lowPricePref = (@lowPrice.to_f / @lowCounter.to_f)
        highPricePref = (@highPrice.to_f / @highCounter.to_f)
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
        @pricePrefs = Array.new
        @queueTimes=Array.new
        @perfPrefs = Array.new
    end
    
    def addJob(job)
        pricePerSecond = job.price.to_f / job.runTime.to_f
        @pricePerSeconds << pricePerSecond.to_f
        @pricePrefs << job.pricePref.to_f
        @queueTimes << job.queueTime.to_f
        @perfPrefs << job.perfPref.to_f
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
        priceCorrelation = calc_correlation(@pricePerSeconds, @pricePrefs)
        perfCorrelation = calc_correlation(@queueTimes, @perfPrefs)
        @reportFile.puts("#{@load}\t#{priceCorrelation}\t#{perfCorrelation}")
        @reportFile.close
    end
end

class ReportCollection
    def initialize(load)
        @reports = Array.new
        report1 = LoadARTReport.new($outDir, load);
        report2 = LoadAvgPriceReport.new($outDir, load);
        report3 = PriceRTPrefReport.new($outDir, load);
        report4 = PricePrefCorrelationReport.new($outDir, load);
        @reports << report1 << report2 << report3 << report4 
    end
    
    def addJob(job)
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


def createReport(reportFileName, loadLevel)
    reportFile=File.new(reportFileName, "r")
    reports = ReportCollection.new(loadLevel);
    print "Reading calanasim report file and converting.\n"
    inExplanation = false;
    context = 0;

    reportFile.each_line {|line|
        # We skip the comments.
        if (line =~ /^;/)
            next 
        end
        # And empty lines.
        if (line =~ /^$/)
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
        runTime = fields[13].strip!
        responseTime = fields[17].strip!
        queueTime = responseTime.to_i - runTime.to_i
        price = fields[18].strip!
        agent = fields[7].strip!
        prefs = fields[8].strip!
        prefFields = prefs.split(";")
        #puts "PREF for job #{jid}: #{prefFields}"
        finishtimeField = prefFields[0];
        perfPref = (finishtimeField.split("="))[1]
        pricePrefField = prefFields[1];
        pricePref = (pricePrefField.split("="))[1]
        #puts "perfPref = #{perfPref}, pricePref = #{pricePref}"
        
        ###
        ## Create a job instance
        #
        j = Job.new(jid)
        j.price = price
        j.pricePref = pricePref
        j.perfPref = perfPref
        j.responseTime = responseTime
        j.runTime = runTime
        j.queueTime = queueTime
            
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

    srate = 100000
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

if ($reportFileName != nil)
    createReport($reportFileName, $load)
end
if ($traceFileName != nil)
    processTrace($traceFileName, $load)
end



