# This file is part of the calana grid workload generator.
# (c) 2008 Mathias Dalheimer, md@gonium.net
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

require "tempfile"
#require "rubygems"
#require "ruby-debug"

# Run R without saving of environment, as quiet as possible.
R_CMD = "Rscript --vanilla"  

class RExperimentAnalysis
  def initialize(path, datafile, loadlevel)
    @workingdir=path
    @datafile = File.expand_path(File.join(path, datafile))
    @loadlevel = loadlevel
    puts "Using data from file #{@datafile}" if $verbose
    @runner = RRunner.new(path)
  end

  def plotSingleRun_Queuetimes
    drawcmd=<<-END_OF_CMD
      plot(data$stime, data$qtime,
        main="Queuetime for all jobs",
        xlab="submittime",
        ylab="queuetime"
      )
    END_OF_CMD
    outfile="queuetimes-"+@loadlevel.to_s
    @runner.execute(@datafile, outfile, drawcmd)
  end

  def plotSingleRun_Price
    drawcmd=<<-END_OF_CMD
      plot(data$price,
        main="Price for all jobs",
        xlab="Job ID",
        ylab="price"
      )
    END_OF_CMD
    outfile="price-"+@loadlevel.to_s
    @runner.execute(@datafile, outfile, drawcmd)
  end

  def plotSingleRun_PricePrefVsPrice()
    drawcmd=<<-END_OF_CMD
      plot(data$pricepref, data$pricert,
        main="Price preference vs. price per second",
        xlab="Price Preference",
        ylab="price/runtime [price/s]"
      )
    END_OF_CMD
    outfile="priceprefvspricert-"+@loadlevel.to_s
    @runner.execute(@datafile, outfile, drawcmd)
  end 

  def plotSingleRun_PerfPrefVsQueueTime()
    drawcmd=<<-END_OF_CMD
      plot(data$perfpref, data$qtime,
        main="Performance preference vs. queuetime",
        xlab="Performance Preference",
        ylab="absolute queuetime [s]"
      )
    END_OF_CMD
    outfile="perfprefvsqtime-"+@loadlevel.to_s
    @runner.execute(@datafile, outfile, drawcmd)
  end

  def plotSingleRun_PricePerSecond
    drawcmd=<<-END_OF_CMD
      plot(data$pricert,
        main="Price per second for all jobs",
        xlab="Job ID",
        ylab="price/runtime [price/s]"
      )
    END_OF_CMD
    outfile="pricepersecond-"+@loadlevel.to_s
    @runner.execute(@datafile, outfile, drawcmd)
  end

  def plotSingleRun_PriceHistogram
    drawcmd=<<-END_OF_CMD
      hist(data$pricert,
        main="Histogram of prices per second",
        xlab="Price per second",
        ylab="Frequency"
      )
    END_OF_CMD
    outfile="histpricepersecond-"+@loadlevel.to_s
    @runner.execute(@datafile, outfile, drawcmd)
  end

  def plotSingleRun_QueuetimeHistogram
    drawcmd=<<-END_OF_CMD
      hist(data$qtime,
        main="Histogram of queuetimes",
        xlab="Queuetime [s]",
        ylab="Frequency"
      )
    END_OF_CMD
    outfile="histqueuetimes-"+@loadlevel.to_s
    @runner.execute(@datafile, outfile, drawcmd)
  end

  def plotSingleRun
    methods.grep(/^plotSingleRun_/){|m|
      self.send(m)
    }
    sleep(1)
  end
end

class RRunner
  def initialize(workingdir)
    @workingdir = workingdir
    puts "Using working directory #{@workingdir}" if $verbose
  end

  # returns a preamble string: which file to use etc.
  def createPreamble(datafilename, outfilename)
    if not outfilename =~ /\.eps$/
      outfilename = outfilename+".eps"
    end
    absOutFilename = File.expand_path(File.join(@workingdir, outfilename))
    cmd= <<-END_OF_CMD
      data<-read.table("#{datafilename}", header=TRUE);
      setEPS();
      postscript("#{absOutFilename}")
    END_OF_CMD
    puts "using filename #{absOutFilename} for output." if $verbose
    return cmd
  end

  # returns a closing string - close file, terminate R
  def createClosing()
    close=<<-END_OF_CMD
      q()
    END_OF_CMD
    return close
  end

  # Executes the given command. Expects a string that contains the 
  # commands to execute.
  def execute(infilename, outfilename, commands) 
    cmdSet = createPreamble(infilename, outfilename)
    cmdSet << commands << createClosing
    # The Tempfile will get deleted automagically when ruby terminates.
    cmdfile=Tempfile.new("r-cmd", @workingdir)
    cmdfile.print(cmdSet)
    cmdfile.close()
    puts "executing commands:\n#{cmdSet}" if $verbose
    commandline="#{R_CMD} #{cmdfile.path}"
    puts "using commandline: #{commandline}" if $verbose
    stdout = %x[#{commandline}]
    puts "R (Exitcode: #{$?}) said: #{stdout}" if $verbose
  end

  def plotTestEPS()
    cmd= <<-END_OF_CMD
      v=1:100
      p=1:100
      plot(v,p)
    END_OF_CMD
    execute("foo.txt", "test.eps", cmd)
  end
end


# Test routines below - execute this file directly...
if __FILE__ == $0
  $verbose=true;
  tmpdir=File.join(ENV["HOME"], "tmp")
  r=RExperimentAnalysis.new(tmpdir, "rtable-0.65.txt",  0.65);
#  r.plotSingleRun_PricePerSecond()
  r.plotSingleRun()
#  runner=RRunner.new(".");
#  runner.plotTestEPS()
end
