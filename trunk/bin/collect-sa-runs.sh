#!/bin/bash
LOAD="0.75"
PARAMS="-s var/testworkload/workload-wcollection.bin -l $LOAD"
#PARAMS="-s var/serial-u10j100l100r3/workload-wcollection.bin -l $LOAD"
MAXRUNS=5
OUTDIR="var/collecting"
ENERGYFILE="energies.txt"
RUBY_BIN=ruby1.9
SA_BIN=bin/sa-scheduler.rb
echo "Collecting various results from several runs of the sa-scheduler."
echo "Using commandline parameters $PARAMS"
echo "Adding output directory parameter $OUTDIR"

for ((run=0; run < $MAXRUNS; run+=1)); do
  echo "Run no. $run: $RUBY_BIN $SA_BIN $PARAMS -o $OUTDIR"
  $RUBY_BIN $SA_BIN $PARAMS -o $OUTDIR
  logfile=$OUTDIR/sa-log-$LOAD.txt
  mv $logfile $logfile.$run
  binfile=$OUTDIR/sa-schedule-$LOAD.bin
  mv $binfile $binfile.$run
done

echo "Starting energy analysis."
targetfiles=""
for ((run=0; run < $MAXRUNS; run+=1)); do
  logfile=$OUTDIR/sa-log-$LOAD.txt.$run
  targetfile=$logfile.energy
  cut -f 2 $logfile > $targetfile
  targetfiles="$targetfiles $targetfile"
done
paste $targetfiles > $OUTDIR/$ENERGYFILE

gnuplotCmd=`mktemp`
cat > $gnuplotCmd <<EOC
set terminal postscript eps color
set output "$OUTDIR/$ENERGYFILE.eps"
set xlabel "Iteration"
set ylabel "Energy"
EOC
# compose plot command.
echo -n "plot \"$OUTDIR/$ENERGYFILE\" using 0:1 axis x1y1 title \"run-0\"" >> $gnuplotCmd
for ((run=1; run <= $MAXRUNS; run+=1)); do
  echo -n ", \"$OUTDIR/$ENERGYFILE\" using 0:$run axis x1y1 title \"run-$run\" " >> $gnuplotCmd
done
#echo "Using plot command"
#cat $gnuplotCmd
#echo
cat "$gnuplotCmd" | gnuplot
echo "Result in $OUTDIR/$ENERGYFILE.eps"
