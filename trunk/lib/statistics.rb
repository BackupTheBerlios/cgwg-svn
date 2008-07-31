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
# Read the CGWG location from the environment, warn otherwise
if (ENV["CGWG_HOME"] == nil)
  puts "WARNING: Environment does not define $CGWG_HOME!"
else
  libpath= File.join(File.expand_path(ENV["CGWG_HOME"]), "lib")
  $:.unshift << libpath
end

# A simple function that dumps the given array of values to
# a file in the global temp directory -> this is for debugging
def dumpRTable(values, filename)
  filename = File.join(ENV["HOME"], "tmp", filename);
  puts "Dumping values to #{filename}"
  File.open(filename, "w") {|file|
    file.puts("index\tvalue")
    values.each_index{|index|
      file.puts("#{index}\t#{values[index]}")
    }
  }
end

# Implements the MC approach - takes a block that checks if x < pdf(y).
def generateMCRandoms(amount)
  if not block_given?
    raise "No probability density function check given - aborting"
  end
  values = Array.new
  while values.size() < amount
    x=rand()
    y=rand()
    inDistribution = yield(x, y)
    if inDistribution
      values << x
    end
  end
  return values
end

# Used for generating randoms for the user preference setting.
def generateDoubleGaussianRandoms(amount)
  values = generateMCRandoms(amount) {|x, y|
    gaussianvalue1 = pdf_gaussian(x, 0.15, 0.1)
    gaussianvalue2 = pdf_gaussian(x, 0.85, 0.1)
    (y < gaussianvalue1) or (y < gaussianvalue2) 
  }
  return values
end

# Use Monte-Carlo method to filter uniform randoms such that they 
# fit the gaussian distribution
def generateGaussianRandoms(amount, mean=0.0, sd=1.0)
  values = generateMCRandoms(amount) {|x, y|
    gaussianvalue = pdf_gaussian(x, mean, sd)
    y < gaussianvalue
  }
  return values
end

# Calculates the value of the probability density function (PDF)
# for the gaussian distribution for x with the given parameters.
def pdf_gaussian(x, mean, sd)
  return (1/(sd*Math.sqrt(Math::PI*2)))*Math.exp(-((x-mean)**2/(2*sd**2)))
end

# Generate simple uniformly distributed random numbers.
def generateUniformRandoms(amount)
  values=Array.new
  amount.downto(0) {|index|
    values << rand()
  }
  values
end

if __FILE__ == $0 
  $verbose = true
  amount=1000
  uniforms=generateUniformRandoms(amount);
  dumpRTable(uniforms, "uniform.txt");
  gaussians=generateGaussianRandoms(amount, mean=0.5, sd=0.25);
  dumpRTable(gaussians, "gaussians.txt");
  doublegaussians=generateDoubleGaussianRandoms(amount);
  dumpRTable(doublegaussians, "doublegaussians.txt");
end
