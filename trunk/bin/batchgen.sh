#!/bin/sh
echo "starting batch generator..."
NUMUSERS=100
NUMJOBS=10000
echo "generating singeCPU workloads"
COALLOCATION=0.0
ruby bin/singleCPUgridwgen.rb -u $NUMUSERS -j $NUMJOBS -c $COALLOCATION
tar cvjf singleCPU-$COALLOCATION.tar.bz var/workload\*
COALLOCATION=0.1
ruby bin/singleCPUgridwgen.rb -u $NUMUSERS -j $NUMJOBS -c $COALLOCATION
tar cvjf singleCPU-$COALLOCATION.tar.bz var/workload\*
COALLOCATION=0.2
ruby bin/singleCPUgridwgen.rb -u $NUMUSERS -j $NUMJOBS -c $COALLOCATION
tar cvjf singleCPU-$COALLOCATION.tar.bz var/workload\*
COALLOCATION=0.3
ruby bin/singleCPUgridwgen.rb -u $NUMUSERS -j $NUMJOBS -c $COALLOCATION
tar cvjf singleCPU-$COALLOCATION.tar.bz var/workload\*

echo "generating smallgrid workloads"
COALLOCATION=0.0
ruby bin/smallgridwgen.rb -u $NUMUSERS -j $NUMJOBS -c $COALLOCATION
tar cvjf smallgrid-$COALLOCATION.tar.bz var/workload\*
COALLOCATION=0.1
ruby bin/smallgridwgen.rb -u $NUMUSERS -j $NUMJOBS -c $COALLOCATION
tar cvjf smallgrid-$COALLOCATION.tar.bz var/workload\*
COALLOCATION=0.2
ruby bin/smallgridwgen.rb -u $NUMUSERS -j $NUMJOBS -c $COALLOCATION
tar cvjf smallgrid-$COALLOCATION.tar.bz var/workload\*
COALLOCATION=0.3
ruby bin/smallgridwgen.rb -u $NUMUSERS -j $NUMJOBS -c $COALLOCATION
tar cvjf smallgrid-$COALLOCATION.tar.bz var/workload\*

echo "generating keegrid workloads"
COALLOCATION=0.0
ruby bin/keegridwgen.rb -u $NUMUSERS -j $NUMJOBS -c $COALLOCATION
tar cvjf keegrid-$COALLOCATION.tar.bz var/workload\*
COALLOCATION=0.1
ruby bin/keegridwgen.rb -u $NUMUSERS -j $NUMJOBS -c $COALLOCATION
tar cvjf keegrid-$COALLOCATION.tar.bz var/workload\*
COALLOCATION=0.2
ruby bin/keegridwgen.rb -u $NUMUSERS -j $NUMJOBS -c $COALLOCATION
tar cvjf keegrid-$COALLOCATION.tar.bz var/workload\*
COALLOCATION=0.3
ruby bin/keegridwgen.rb -u $NUMUSERS -j $NUMJOBS -c $COALLOCATION
tar cvjf keegrid-$COALLOCATION.tar.bz var/workload\*
