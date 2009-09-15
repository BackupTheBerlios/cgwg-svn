#!/usr/bin/env ruby
# This file is part of the calana grid workload generator.
# (c) 2008 Christian Bischof, christianbischof@gmx.de
#
# The calana grid work$load generator (CGWG) is free software; you can 
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

require 'optparse'
require 'ostruct'
require 'statistics'
require 'Utils'

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
            opts.banner = "Usage: experimentGenerator.rb [options]"
            opts.separator ""
            opts.separator "Specific options:"
            # Mandatory argument.
            opts.on("-a", "--agents INT", "number of agents to createa") do |agents|
                options.agents=agents
            end
            opts.on("-c", "--cpus INT", "#cpus (regard cpu-mode)") do |cpus|
                options.cpus=cpus
            end
            opts.on("-d", "--duration INT", "auction duration") do |duration|
                options.duration=duration
            end
            opts.on("-f", "--force", "ignore existing output file") do |force|
                options.force=force
            end
            opts.on("-g", "--upper-bound FLOAT:FLOAT", "if agentType == bounded") do |ub|
                options.ub=ub
            end
            opts.on("-i", "--lower-bound FLOAT:FLOAT", "if agentType == bounded") do |lb|
                options.lb=lb
            end
            opts.on("-j", "--bundle-size INT", "if agentType == bounded") do |bs|
                options.bs=bs
            end
            opts.on("-k", "--smooth-factor FLOAT", "if agentType == exp") do |sf|
                options.sf=sf
            end
            opts.on("-l", "--smooth-length INT", "if agentType == exp") do |sl|
                options.sl=sl
            end
            opts.on("-m", "--cpu-mode STRING","single: (#CPUs = #cpus), pow: (#CPUs = 2^n where max(n) = #cpus)") do |cpumode|
                options.cpumode=cpumode
            end
            opts.on("-o", "--output-file STRING","output file name (without .xml)") do |filename|
                options.filename=filename
            end
            opts.on("-p", "--bid-prob FLOAT:FLOAT","min:max bid probability") do |bp|
                options.bp=bp
            end
            opts.on("-q", "--abort-prob FLOAT:FLOAT","min:max abort probability") do |ap|
                options.ap=ap
            end
            opts.on("-r", "--reject-prob FLOAT:FLOAT","min:max reject probability") do |rp|
                options.rp=rp
            end
            opts.on("-s", "--disable-scoring", "disable scoring") do |s|
                options.disablescoring=s
            end
            opts.on("-t", "--broker_type STRING","broker type (direct, text)") do |brokertype|
                options.brokertype=brokertype 
            end
            opts.on("-u", "--agent_type STRING","agent type (if broker_type == text) (normal, exp, bounded, rulebased)") do |agenttype|
                options.agenttype=agenttype 
            end
            opts.on("-v", "--verbose", "run verbosely") do |v|
                options.verbose = v
            end
            opts.on("-x", "--base-price FLOAT:FLOAT","min:max base price") do |baseprice|
                options.baseprice=baseprice
            end
            opts.on("-y", "--time-price FLOAT:FLOAT","min:max time price") do |timeprice|
                options.timeprice=timeprice
            end
            opts.on("-z", "--over-alloc FLOAT:FLOAT","min:max over allocation fee") do |overalloc|
                options.overalloc=overalloc
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

# some useful methods

def round(number, decimals)
  (number * 10**decimals).round.to_f / 10**decimals
end

def getCpus
  if @cpuMode == "single"
    return @cpus
  elsif @cpuMode == "pow"
    return 2**rand(@cpus+1)
  end
end

def generateRandomDirect(amount)
  randoms = mda(amount, 3)
  basePrices = generateUniformRandoms(amount, Range.new(@basePriceMin, @basePriceMax))
  timePrices = generateUniformRandoms(amount, Range.new(@timePriceMin, @timePriceMax))
  amount.times {|row|
    randoms[row][0] = round(basePrices[row], 2)
    randoms[row][1] = round(timePrices[row], 2)
    randoms[row][2] = getCpus
  }
  return randoms
end

def generateRandomTextNormal(amount)
  randoms = mda(amount, 6)
  basePrices = generateUniformRandoms(amount, Range.new(@basePriceMin, @basePriceMax))
  timePrices = generateUniformRandoms(amount, Range.new(@timePriceMin, @timePriceMax))
  oversizedAllocFee = generateUniformRandoms(amount, Range.new(@overAllocMin, @overAllocMax))
  bidProb = generateUniformRandoms(amount, Range.new(@bidProbabilityMin, @bidProbabilityMax))
  rejectProb = generateUniformRandoms(amount, Range.new(@rejectProbabilityMin, @rejectProbabilityMax))
  abortProb = generateUniformRandoms(amount, Range.new(@abortProbabilityMin, @abortProbabilityMax))
  amount.times {|row|
    randoms[row][0] = round(basePrices[row], 2)
    randoms[row][1] = round(timePrices[row], 2)
    randoms[row][2] = round(oversizedAllocFee[row], 2)
    randoms[row][3] = round(bidProb[row], 2)
    randoms[row][4] = round(rejectProb[row], 2)
    randoms[row][5] = round(abortProb[row], 2)
  }
  return randoms
end

def generateRandomTextExp(amount)
  randoms = mda(amount, 6)
  smoothFactor = generateUniformRandoms(amount, Range.new(@smoothFactorMin, @smoothFactorMax))
  smoothLength = generateUniformRandoms(amount, Range.new(@smoothLengthMin, @smoothLengthMax))
  oversizedAllocFee = generateUniformRandoms(amount, Range.new(@overAllocMin, @overAllocMax))
  bidProb = generateUniformRandoms(amount, Range.new(@bidProbabilityMin, @bidProbabilityMax))
  rejectProb = generateUniformRandoms(amount, Range.new(@rejectProbabilityMin, @rejectProbabilityMax))
  abortProb = generateUniformRandoms(amount, Range.new(@abortProbabilityMin, @abortProbabilityMax))
  amount.times {|row|
    randoms[row][0] = round(smoothFactor[row], 2)
    randoms[row][1] = round(smoothLength[row], 0)
    randoms[row][2] = round(oversizedAllocFee[row], 2)
    randoms[row][3] = round(bidProb[row], 2)
    randoms[row][4] = round(rejectProb[row], 2)
    randoms[row][5] = round(abortProb[row], 2)
  }
  return randoms
end

def generateRandomTextBounded(amount)
  randoms = mda(amount, 6)
  upperBound = generateUniformRandoms(amount, Range.new(@upperBoundMin, @upperBoundMax))
  lowerBound = generateUniformRandoms(amount, Range.new(@lowerBoundMin, @lowerBoundMax))
  bundleSize = generateUniformIntegerRandoms(amount, Range.new(@bundleSizeMin, @bundleSizeMax))
  changeRatio = generateGaussianRandoms(amount, 0.5, 1.0, Range.new(0.1, 0.9))
  oversizedAllocFee = generateUniformRandoms(amount, Range.new(@overAllocMin, @overAllocMax))
  bidProb = generateUniformRandoms(amount, Range.new(@bidProbabilityMin, @bidProbabilityMax))
  rejectProb = generateUniformRandoms(amount, Range.new(@rejectProbabilityMin, @rejectProbabilityMax))
  abortProb = generateUniformRandoms(amount, Range.new(@abortProbabilityMin, @abortProbabilityMax))
  amount.times {|row|
    randoms[row][0] = round(upperBound[row], 2)
    randoms[row][1] = round(lowerBound[row], 2)
    randoms[row][2] = bundleSize[row]
    randoms[row][3] = round(changeRatio[row], 2)
    randoms[row][4] = round(oversizedAllocFee[row], 2)
    randoms[row][5] = round(bidProb[row], 2)
    randoms[row][6] = round(rejectProb[row], 2)
    randoms[row][7] = round(abortProb[row], 2)
  }
  return randoms
end

def getHeader #TODO adept
  header = <<-END_OF_HEADER
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE calana:experiment SYSTEM "experiment.dtd">
<calana:experiment name="#{@fileName.match(/var\/(.*).xml/)[-1]}" xmlns:calana="http://www.itwm.fhg.de/calana/experiment/">
  <description>
    some experiment
  </description>
  <workload>
    <input format="xml">
      <!-- we use the file from the commandline -->
      <file>some-non-existent-file.xml</file>
    </input>
    <output format="txt">
      <file>-</file>
    </output>
  </workload>
  <cluster name="cluster-1-1">
    <cpus>#{getCpus}</cpus>
    <scheduler type="fcfs"/>
  </cluster>
  <agents topbroker="broker">
    <manager name="workload-manager"/>
END_OF_HEADER
  if @brokerType == "direct"
    header << <<-END_OF_DIRECT_BROKER
    <broker name="broker" class="calana.agents.impl.DirectBroker">
      <cluster-ref name="cluster-1-1"/>
    </broker>
END_OF_DIRECT_BROKER
  else
    header << <<-END_OF_TEXT_BROKER
    <broker name="broker">
      <prop name="auctionDuration" value="#{@duration}"/>
      <prop name="enableScoring" value="#{@scoring}"/>
    </broker>
END_OF_TEXT_BROKER
  end
  return header
end

def getDirectAgents(amount)
  randNum = generateRandomDirect(amount)
  agents = ""
  amount.times {|num|
    agents << <<-END_OF_DIRECT_AGENTS
    <agent name="bidder-#{num+1}" class="calana.agents.impl.BasicBidAgent">
    <cluster-ref name="cluster-1-1"/>
      <prop name="basePrice" value="#{randNum[num][0]}"/>
      <prop name="timePrice" value="#{randNum[num][1]}"/>
      <prop name="cpus" value="#{randNum[num][2]}"/>
    </agent>
END_OF_DIRECT_AGENTS
  }
  return agents
end

def getBiddingAgents(amount)
  randNum = generateRandomTextNormal(amount)
  agents = ""
  amount.times {|num|
    agents << <<-END_OF_BID_AGENTS
    <agent name="bidder-#{num+1}" class="calana.agents.impl.BasicBidAgent">
      <cluster-ref name="cluster-1-1"/>
      <prop name="basePrice" value="#{randNum[num][0]}"/>
      <prop name="timePrice" value="#{randNum[num][1]}"/>
      <prop name="oversizedAllocationFee" value="#{randNum[num][2]}"/>
      <prop name="bidProbability" value="#{randNum[num][3]}"/>
      <prop name="rejectProbability" value="#{randNum[num][4]}"/>
      <prop name="abortProbability" value="#{randNum[num][5]}"/>
    </agent>
END_OF_BID_AGENTS
  }
  return agents
end

def getExpSmoothingAgents(amount)
  randNum = generateRandomTextExp(amount)
  agents = ""
  amount.times {|num|
    agents << <<-END_OF_BID_AGENTS
    <agent name="bidder-#{num+1}" class="calana.agents.impl.ExpSmoothingBidAgent">
      <cluster-ref name="cluster-1-1"/>
      <prop name="smoothFactor" value="#{randNum[num][0]}"/>
      <prop name="smoothLength" value="#{randNum[num][1]}"/>
      <prop name="oversizedAllocationFee" value="#{randNum[num][2]}"/>
      <prop name="bidProbability" value="#{randNum[num][3]}"/>
      <prop name="rejectProbability" value="#{randNum[num][4]}"/>
      <prop name="abortProbability" value="#{randNum[num][5]}"/>
    </agent>
END_OF_BID_AGENTS
  }
  return agents
end

def getBoundedBidAgents(amount)
  randNum = generateRandomTextBounded(amount)
  agents = ""
  amount.times {|num|
    agents << <<-END_OF_BID_AGENTS
    <agent name="bidder-#{num+1}" class="calana.agents.impl.BoundedBidAgent">
      <cluster-ref name="cluster-1-1"/>
      <prop name="upperBound" value="#{randNum[num][0]}"/>
      <prop name="lowerBound" value="#{randNum[num][1]}"/>
      <prop name="bundleSize" value="#{randNum[num][2]}"/>
      <prop name="changeRatio" value="#{randNum[num][3]}"/>
      <prop name="oversizedAllocationFee" value="#{randNum[num][4]}"/>
      <prop name="bidProbability" value="#{randNum[num][5]}"/>
      <prop name="rejectProbability" value="#{randNum[num][6]}"/>
      <prop name="abortProbability" value="#{randNum[num][7]}"/>
    </agent>
END_OF_BID_AGENTS
  }
  return agents
end

def getRuleBasedAgents(amount) #TODO
  agents = ""
  amount.times {|num|
    agents << <<-END_OF_BID_AGENTS
    <agent name="bidder-#{num+1}" class="calana.agents.impl.RuleBasedAgents">
      <cluster-ref name="cluster-1-1"/>
    </agent>
END_OF_BID_AGENTS
  }
  return agents
end

def getFooter # TODO adept
  footer = <<-END_OF_FOOTER
  </agents>
</calana:experiment>
END_OF_FOOTER
  return footer
end


###
## Script begins here
#
print "Calana Experiment Generator Frontend\n"

options = Optparser.parse(ARGV)

agents = options.agents.to_i
disableScoring = options.disablescoring
force = options.force
basePrice = options.baseprice
timePrice = options.timeprice
overAllocFee = options.overalloc
bidProbability = options.bp
rejectProbability = options.rp
abortProbability = options.ap
upperBound = options.ub
lowerBound = options.lb
bundleSize = options.bs
smoothFactor = options.sf
smoothLength = options.sl
@fileName = options.filename
@scoring = true
@brokerType = options.brokertype
@agentType = options.agenttype
@verbose = options.verbose
@duration = options.duration.to_i
@cpus = options.cpus.to_i
@cpuMode = options.cpumode



# checking mandatory parameters
if agents == 0 or (@brokerType != "direct" and @brokerType != "text")
  puts "plase read usage note (-h)\n"
  puts "agents: #{agents}" if @verbose
  puts "brokerType: #{@brokerType}" if @verbose
  puts
  puts "mandatory parameters: -a, -t"
  exit
end



# checking for valid syntax 
#if baseprice =~ #TODO



# setting default values
@scoring = false if disableScoring

if @brokerType == "text" and (@agentType == nil or (@agentType != "exp" and @agentType != "bounded" and @agentType != "rulebased"))
  @agentType = "normal"
  puts "none or wrong agent type set: setting to '#{@agentType}'"
end
if @cpuMode == nil or (@cpuMode != "single" and @cpuMode != "pow")
  @cpuMode = "single"
  puts "none or wrong CPU-mode: setting to '#{@cpuMode}'"
end
if @duration == 0
  @duration = 100
  puts "no duration set: setting to #{@duration}"
end
if @cpus == 0
  @cpus = 32
  puts "no #cpus set: setting to #{@cpus}"
end
if basePrice == nil
  basePrice = "10:17"
  puts "no basePrice set: setting to #{basePrice}"
end
if timePrice == nil
  timePrice = "0.1:2.0"
  puts "no timePrice set: setting to #{timePrice}"
end
if overAllocFee == nil
  overAllocFee = "5:10"
  puts "no overAllocFee set: setting to #{overAllocFee}"
end
if bidProbability == nil
  bidProbability = "1:1"
  puts "no bidProbability set: setting to #{bidProbability}"
end
if rejectProbability == nil
  rejectProbability = "0:0"
  puts "no rejectProbability set: setting to #{rejectProbability}"
end
if abortProbability == nil
  abortProbability = "0:0"
  puts "no abortProbability set: setting to #{abortProbability}"
end
if @agentType == "bounded"
  if upperBound == nil
    upperBound = "70:120"
    puts "no upperBound set: setting to #{upperBound}"
  end
  if lowerBound == nil
    lowerBound = "10:50"
    puts "no lowerBound set: setting to #{lowerBound}"
  end
  if bundleSize == nil
    bundleSize = "2:20"
    puts "no bundleSize set: setting to #{bundleSize}"
  end
end
if @agentType == "exp"
  if smoothFactor == nil
    smoothFactor = "0.05:0.3"
    puts "no smoothFactor set: setting to #{smoothFactor}"
  end
  if smoothLength == nil
    smoothLength = "2:20"
    puts "no smoothLength set: setting to #{smoothLength}"
  end
end



# settin ranges
@basePriceMin = basePrice.split(":")[0].to_f
@basePriceMax = basePrice.split(":")[1].to_f
@timePriceMin = timePrice.split(":")[0].to_f
@timePriceMax = timePrice.split(":")[1].to_f
@bidProbabilityMin = bidProbability.split(":")[0].to_f
@bidProbabilityMax = bidProbability.split(":")[1].to_f
@rejectProbabilityMin = rejectProbability.split(":")[0].to_f
@rejectProbabilityMax = rejectProbability.split(":")[1].to_f
@abortProbabilityMin = abortProbability.split(":")[0].to_f
@abortProbabilityMax = abortProbability.split(":")[1].to_f
@overAllocMin = overAllocFee.split(":")[0].to_f
@overAllocMax = overAllocFee.split(":")[1].to_f
if @agentType == "bounded"
  @upperBoundMin = upperBound.split(":")[0].to_f
  @upperBoundMax = upperBound.split(":")[1].to_f
  @lowerBoundMin = lowerBound.split(":")[0].to_f
  @lowerBoundMax = lowerBound.split(":")[1].to_f
  @bundleSizeMin = bundleSize.split(":")[0].to_i
  @bundleSizeMax = bundleSize.split(":")[1].to_i
end
if @agentType == "exp"
  @smoothFactorMin = smoothFactor.split(":")[0].to_f
  @smoothFactorMax = smoothFactor.split(":")[1].to_f
  @smoothLengthMin = smoothLength.split(":")[0].to_i
  @smoothLengthMax = smoothLength.split(":")[1].to_i
end

basedir=File.expand_path(ENV["CGWG_HOME"])
puts "Assuming base directory #{basedir}\n"
puts ""



# generate name if none is provided and append the extension
if @fileName == nil
  if @brokerType == "text"
    @fileName = "experiment_#{@brokerType}_#{@agentType}_#{agents}.xml"
  else
    @fileName = "experiment_#{@brokerType}_#{agents}.xml"
  end
else
  @fileName = "#{@fileName}.xml"
end
@fileName = File.expand_path("#{basedir}/var/#{@fileName}")
puts "File name: #{@fileName}" if @verbose

# check if file exists
if File.exists?(@fileName) and not force
  puts "File '#{@fileName}' already exists."
  puts "Exiting."
  exit
end



# build file
File.open(@fileName, "w") {|handle|
  puts "Generate header ..." if @verbose
  handle.puts getHeader
  puts "Generate agents (#{agents}) ..." if @verbose
  if @brokerType == "direct"
    handle.puts getDirectAgents(agents)
  else
    if @agentType == "normal" then handle.puts getBiddingAgents(agents)
    elsif @agentType == "bounded" then handle.puts getBoundedBidAgents(agents)
    elsif @agentType == "exp" then handle.puts getExpSmoothingAgents(agents)
    elsif @agentType == "rulebased" then handle.puts getRuleBasedAgents(agents)
    end
  end
  puts "Generate footer ..." if @verbose
  handle.puts getFooter
}
puts "file generated: #{@fileName}"
