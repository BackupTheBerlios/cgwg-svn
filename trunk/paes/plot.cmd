#!/usr/bin/env Rscript --vanilla
data<-read.table("data.txt", header=TRUE);
plot(data$QT, data$Price);
