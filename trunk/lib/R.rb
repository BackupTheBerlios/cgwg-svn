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
require 'Annotations'
#require "rubygems"
#require "ruby-debug"

# Run R without saving of environment, as quiet as possible.
R_CMD = "Rscript --vanilla"

class RExperimentSingleAnalysis
  def RExperimentSingleAnalysis.plotTwoDimensional(path, loadlevel, fileName, title, xLabel, yLabel)
    @runner = RRunner.new(path)
    outFile = fileName+"-"+loadlevel.to_s
    inFile = outFile+".txt"
    fullInFile = File.expand_path(File.join(path, inFile))
    puts "Using data from file #{fullInFile}" if $verbose
    drawcmd=<<-END_OF_CMD
      plot(data,
        main="#{title}",
        xlab="#{xLabel}",
        ylab="#{yLabel}"
      )
    END_OF_CMD
    @runner.execute(fullInFile, outFile, drawcmd)
  end

  def RExperimentSingleAnalysis.linePlotTwoDimensional(path, loadlevel, fileName, title, xLabel, yLabel)
    @runner = RRunner.new(path)
    outFile = fileName+"-"+loadlevel.to_s
    inFile = outFile+".txt"
    fullInFile = File.expand_path(File.join(path, inFile))
    puts "Using data from file #{fullInFile}" if $verbose
    drawcmd=<<-END_OF_CMD
      plot(data,
        main="#{title}",
        xlab="#{xLabel}",
        ylab="#{yLabel}",
        type="l"
      )
    END_OF_CMD
    @runner.execute(fullInFile, outFile, drawcmd)
  end

  def RExperimentSingleAnalysis.barplotTwoDimensional(path, loadlevel, fileName, title, valuesRow, labelsRow)
    @runner = RRunner.new(path)
    outFile = fileName+"-"+loadlevel.to_s
    inFile = outFile+".txt"
    fullInFile = File.expand_path(File.join(path, inFile))
    puts "Using data from file #{fullInFile}" if $verbose
    drawcmd=<<-END_OF_CMD
      barplot(data$#{valuesRow},
        main="#{title}",
        names.arg=data$#{labelsRow}
      )
    END_OF_CMD
    @runner.execute(fullInFile, outFile, drawcmd)
  end

  def RExperimentSingleAnalysis.multiLinePlotTwoDimensional(path, loadlevel, fileName, title, xLabel, yLabel)
    @runner = RRunner.new(path)
    outFile = fileName+"-"+loadlevel.to_s
    inFile = outFile+".txt"
    fullInFile = File.expand_path(File.join(path, inFile))
    puts "Using data from file #{fullInFile}" if $verbose

    # Entities aus der Datei lesen, erstes entity merken und löschen und die restlichen gegen dieses auftragen
    file = File.open(File.expand_path(File.join(path, inFile)), "r");
    tableHeader = file.readline
    entities = tableHeader.split(" ")
    baseEntity = entities[0]
    entities.delete(entities[0])

    # Build legend
    legend = Array.new
    i = 0
    entities.each{|entity|
      legend[i] = "\""+entity+"\""
      i += 1
    }
    legend.join(",")

    # Draw plot (first line)
    color = 1;
    drawcmd=<<-END_OF_CMD
      ran <- range(data[2:length(colnames(data))]);
      plot(data$#{baseEntity}, data$#{entities[0]},
        xlab="#{xLabel}",
        ylab="#{yLabel}",
        ylim=ran,
        main="#{title}",
        type='l'
      );
    END_OF_CMD
    entities.delete(entities[0])

    # Draw other lines
    color = color+1
    entities.each{|entity|
      drawcmd+=<<-END_OF_CMD
        lines(
          data$#{baseEntity},
          data$#{entity},
          col=#{color}
        );
      END_OF_CMD
      color += 1
      }

    # Draw legend
    drawcmd+=<<-END_OF_CMD
      numLastEntity <- length(colnames(data))
      legend("topright", colnames(data[2:numLastEntity]), lwd=1, col=c(1:numLastEntity))
    END_OF_CMD

    @runner.execute(fullInFile, outFile, drawcmd)
  end

  def RExperimentSingleAnalysis.multiLinePlotTwoDimensional2(path, loadlevel, inFile, outFile, xRow, yRow, colorRow, title, xLabel, yLabel)
    @runner = RRunner.new(path)
    outFile = outFile+"-"+loadlevel.to_s
    inFile = inFile+"-"+loadlevel.to_s+".txt"
    fullInFile = File.expand_path(File.join(path, inFile))
    puts "Using data from file #{fullInFile}" if $verbose

    file = File.open(File.expand_path(File.join(path, inFile)), "r");

    drawcmd=<<-END_OF_CMD
      xRan <- range(data$#{xRow})
      yRan <- range(data$#{yRow})
      plot(0, 0, xlab="#{xLabel}", ylab="#{yLabel}", xlim=xRan, ylim=yRan)
      for(rowNo in rownames(data)) points(data[rowNo,]$#{xRow}, data[rowNo,]$#{yRow}, col=data[rowNo,]$#{colorRow})
    END_OF_CMD

    @runner.execute(fullInFile, outFile, drawcmd)
  end
end

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

  def plotSingleRun_perfPrefHistogram
    drawcmd=<<-END_OF_CMD
      hist(data$perfpref,
        main="Histogram of user preferences",
        xlab="Performance Preference",
        ylab="Frequency"
      )
    END_OF_CMD
    outfile="histperfpref-"+@loadlevel.to_s
    @runner.execute(@datafile, outfile, drawcmd)
  end

  def plotSingleRun_user_prices
    RExperimentSingleAnalysis.multiLinePlotTwoDimensional2(@workingdir, @loadlevel,
            "rtable", "user-costs", "stime", "price", "uid",
            "User costs for each job", "JobID", "Price")
  end

  def plotSingleRun_user_qtimes
    RExperimentSingleAnalysis.multiLinePlotTwoDimensional2(@workingdir, @loadlevel,
            "rtable", "user-queuetimes", "stime", "qtime", "uid",
            "User queuetimes for each job", "JobID", "Queuetime")
  end

  def plotSingleRun_userBoxplot
    drawcmd=<<-END_OF_CMD
      ordereduids <- unique(data[order(data$pricepref, decreasing=T),]$uid)
      uids <- factor(data$uid, levels=ordereduids)
      boxplot(data$price/data$rtime ~ uids, col=c(1:8),
        main="Price per sec for each user", xlab="users", ylab="price/sec")
    END_OF_CMD
    outfile="user-boxes-"+@loadlevel.to_s
    @runner.execute(@datafile, outfile, drawcmd)
  end

  def plotSingleRun
    methods.grep(/^plotSingleRun_/){|m|
      self.send(m)
    }
    sleep(1)
  end
end


class PAES_Analysis
  def initialize(path, annotationsfile)
    @workingdir=path
    @annotationsfile=annotationsfile
    if @annotationsfile != nil
      @annotations=AnnotationCollection.new(@annotationsfile)
    end
    @runner = RRunner.new(path)
  end
  def plotSingleRun
    methods.grep(/^plotSingleRun_/){|m|
      self.send(m)
    }
    sleep(1)
  end
  def arrayToC(input)
    retval="c("
    input.each{|element|
      if element.instance_of?(String)
        retval += "\"#{element}\","
      else
        retval += "#{element},"
      end
    }
    retval.sub!(/,$/, "");   # delete the last comma
    return retval+")";
  end
  ###
  ## takes a drawcommand as an argument and adds annotations
  ## as needed.
  ## TODO: Points are not plotted if they are out of the range of
  ## the plot - this might be necessary in the future.
  #
  def appendAnnotations(drawcmd)
    if @annotations != nil
      puts "Adding annotations\n#{@annotations.to_s}"
      colors=Array.new()
      labels=Array.new()
      ltyInfo=Array.new()
      pchInfo=Array.new()
      counter=0;
      pointlines=""
      @annotations.each{|a|
        counter+=1;
        colors << counter;
        labels << a.text;
        pointlines+="points(#{a.qt}, #{a.price}, type=\"p\", pty=2, col=#{counter})\n"
        ltyInfo << -1;
        pchInfo << 1;
      }
      cols=arrayToC(colors)
      labelList=arrayToC(labels)
      ltyList=arrayToC(ltyInfo)
      pchList=arrayToC(pchInfo)
      drawcmd+=<<-EOC
        cols=#{cols}
        labels=#{labelList}
        #{pointlines}
        legend("topright", labels, col = cols,
           text.col = "black", lty = #{ltyList}, pch = #{pchList},
           bg = 'gray90')
      EOC
    end
    return drawcmd
  end
  def plotSingleRun_ParetoSchedules_Absolute
    basename="absolute-results"
        #main="Pareto Front (absolute values)",
    drawcmd=<<-END_OF_CMD
      plot(data$QT, data$Price, type="b",
        xlab="queue time (s)",
        ylab="price"
      )
    END_OF_CMD
    infile=File.join(@workingdir, basename+".txt")
    outfile=basename+".eps"
    puts "infile: #{infile}"
    puts "outfile: #{outfile}"
    @runner.execute(infile, outfile, drawcmd)
  end
  def plotSingleRun_ParetoSchedules_Relative
    basename="relative-results"
    max_qt_annotation = @annotations.getMaxQT()
    max_price_annotation = @annotations.getMaxPrice()
    min_qt_annotation = @annotations.getMinQT()
    min_price_annotation = @annotations.getMinPrice()
    puts "### Calculated: #{max_qt_annotation}, #{max_price_annotation}"
        #main="Pareto Front (relative values)",
    drawcmd=<<-END_OF_CMD
      max_qt<-max(data$QT, #{max_qt_annotation});
      max_price<-max(data$Price, #{max_price_annotation});
      min_qt<-min(data$QT, #{min_qt_annotation});
      min_price<-min(data$Price, #{min_price_annotation});
      qt_range<-c(min_qt,max_qt);
      price_range<-c(min_price,max_price);
      plot(qt_range, price_range, type="n",
        xlab="queue time (s)",
        ylab="price / second"
      )
      points(data$QT, data$Price, type="b")
    END_OF_CMD
    drawcmd=appendAnnotations(drawcmd)
    infile=File.join(@workingdir, basename+".txt")
    outfile=basename+".eps"
    puts "infile: #{infile}"
    puts "outfile: #{outfile}"
    @runner.execute(infile, outfile, drawcmd)
  end
  def plotSingleRun_Runtime
    basename="runtime-report"
    drawcmd=<<-END_OF_CMD
      l<-length(data$acc)
      range<-1:l
      plot(range, data$acc, type="n",
        xlab="Iteration (x 1000)",
        ylab="Dominant Solutions"
      )
      points(range, data$acc, type="l", lty=1)
    END_OF_CMD
    infile=File.join(@workingdir, basename+".txt")
    outfile=basename+".eps"
    puts "infile: #{infile}"
    puts "outfile: #{outfile}"
    @runner.execute(infile, outfile, drawcmd)
  end
  def plotSingleRun_Runtime_Distance
    basename="runtime-report"
    drawcmd=<<-END_OF_CMD
      l<-length(data$distance)
      range<-1:l
      plot(range, data$distance, type="n",
        xlab="Iteration (x 1000)",
        ylab="Distance"
      )
      points(range, data$distance, type="l", lty=2)
    END_OF_CMD
    infile=File.join(@workingdir, basename+".txt")
    outfile=basename+"-distance.eps"
    puts "infile: #{infile}"
    puts "outfile: #{outfile}"
    @runner.execute(infile, outfile, drawcmd)
  end

  def plotSingleRun_ParetoSchedules_Intermediates
    # Search for all intermediate-* files in the data directory
    Dir.foreach(@workingdir) {|file|
      #puts "checking #{file}"
      if file =~ /^intermediate-/
        if not file =~ /.eps$/
          plotIntermediate(file)
        end
      end
    }
  end
  def plotIntermediate(filename)
    drawcmd=<<-END_OF_CMD
      plot(data$QT, data$Price, type="b",
        main="Pareto Front (absolute values)",
        xlab="queue time (s)",
        ylab="price"
      )
    END_OF_CMD
    infile=File.join(@workingdir, filename)
    outfile=filename+".eps"
    puts "infile: #{infile}"
    puts "outfile: #{outfile}"
    @runner.execute(infile, outfile, drawcmd)
  end

end



class SA_Analysis
  def initialize(path, datafile, loadlevel)
    @workingdir=path
    @datafile = File.expand_path(File.join(path, datafile))
    @loadlevel = loadlevel
    puts "Using data from file #{@datafile}" if $verbose
    @runner = RRunner.new(path)
  end
  def plotSingleRun
    methods.grep(/^plotSingleRun_/){|m|
      self.send(m)
    }
    sleep(1)
  end
  def plotSingleRun_Energy
    drawcmd=<<-END_OF_CMD
      l<-length(data$Energy)
      range<-1:l
      plot(range, data$Energy, type="n",
        main="Energy of the Solutions",
        xlab="Iteration",
        ylab="Absolute Energy"
      )
      points(range, data$Energy)
    END_OF_CMD
    outfile="sa-energy-"+@loadlevel.to_s
    @runner.execute(@datafile, outfile, drawcmd)
  end
  def plotSingleRun_Temperature
    drawcmd=<<-END_OF_CMD
      l<-length(data$Temperature)
      range<-1:l
      plot(range, data$Temperature, type="n",
        main="Temperature of the Solutions",
        xlab="Iteration",
        ylab="Temperature"
      )
      points(range, data$Temperature, pch=1)
    END_OF_CMD
    outfile="sa-temperature-"+@loadlevel.to_s
    @runner.execute(@datafile, outfile, drawcmd)
  end
  def plotSingleRun_Accepted
    drawcmd=<<-END_OF_CMD
      l<-length(data$Accepted)
      range<-1:l
      plot(range, data$Accepted, type="n",
        main="Number of Accepted Solutions",
        xlab="Iteration",
        ylab="# Accepted"
      )
      points(range, data$Accepted, pch=1)
    END_OF_CMD
    outfile="sa-accepted-"+@loadlevel.to_s
    @runner.execute(@datafile, outfile, drawcmd)
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