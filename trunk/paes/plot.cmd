#!/usr/local/bin/Rscript --vanilla
###!/usr/bin/env Rscript --vanilla
data<-read.table("data/abs-results-99999.txt", header=TRUE);
plot(data$QT, data$Price, type="b", xlab="queue time (s)", ylab="price");
