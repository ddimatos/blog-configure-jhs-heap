#!/bin/sh
##########################################################################################
# Script will review the log files (.jhst & .xml) to suggest a heap
# size for the JHS. 
#
# Variables require to be set:
# DATE is the day you wish to capture the files for, jobs are usually located 
#      on HDFS with a date directory structure where files are located in HDFS
#      at /mr-history/done/$DATE 
# PERCENT is the over compensating factor needed for large unanticipated jobs.
# DIVISOR is the how many iterations you want to divide the number of jobs into. 
##########################################################################################
##########################################################################################
# STDOUT example of the commmands:
##########################################################################################
# 29 Jobs were run on date 2017/06/08
# Based on 29 jobs and the divisor 3, you should set the JHS cache size (mapreduce.jobhistory.loadedjobs.cache.size) to: 9
# The sum for the largest 9 XML files for date 2017/06/08 is: 1148175 bytes
# The sum for the largest 9 JHIST files for date 2017/06/08 is: 300574 bytes
# The sum for the largest 9 job logs is: 1448749 bytes
# Based on the job summary 1448749 bytes * .20 varience, the compensation factor for large jobs is: 289750 bytes
# Based on the job size summary 1448749 bytes and the compenstaion 289750 bytes, the JHS HEAP should be set to: 1738499 bytes
##########################################################################################

##########################################################################################
# Hadoop 2.7.2
##########################################################################################
#Count all the .jhst and .xml files for a day to get an idea of the number of jobs you run
DATE="2017/06/08";
PERCENT=".20";
DIVISOR=3;
JOB_COUNT=`sudo -u hdfs hdfs dfs -ls -R /mr-history/done/$DATE |grep jhist | gawk '{n++;} END {print n;}'`; 
echo "$JOB_COUNT Jobs were run on date $DATE";
            
#Divide the number of jobs you run by a divisor (a number that equates to something meaningful, ie , 24 is mine for 24 hours, so i am going to cache only the last hour of jobs) 
JOB_CACHE_SIZE=`echo $JOB_COUNT/$DIVISOR|bc`;
echo "Based on $JOB_COUNT jobs and the divisor $DIVISOR, you should set the JHS cache size (mapreduce.jobhistory.loadedjobs.cache.size) to: $JOB_CACHE_SIZE"
       
#Sort the .xml and .jhst files in descending order and sum only the number you have set for $JOB_CACHE_SIZE. 
#We are interested in the largest ones, we will base our JHS HEAP on the larger jobs to avoid any memory issues.
#Note: job history file is made up of an xml and jhst file. 
XML_FILE_SUM=`sudo -u hdfs hdfs dfs -ls -R /mr-history/done/$DATE |grep xml |sort -r -k 5,5|head -$JOB_CACHE_SIZE | gawk '{sum += $5;} END {print sum;}'`;
echo "The sum for the largest $JOB_CACHE_SIZE XML files for date $DATE is: $XML_FILE_SUM bytes";
           
JHIST_FILE_SUM=`sudo -u hdfs hdfs dfs -ls -R /mr-history/done/$DATE |grep jhist |sort -r -k 5,5|head -$JOB_CACHE_SIZE | gawk '{sum += $5;} END {print sum;}'`
echo "The sum for the largest $JOB_CACHE_SIZE JHIST files for date $DATE is: $JHIST_FILE_SUM bytes";
         
#Sum the largest XML and JHST files 
JOB_SIZE_SUM=`echo $XML_FILE_SUM + $JHIST_FILE_SUM|bc`;
echo "The sum for the largest $JOB_CACHE_SIZE job logs is: $JOB_SIZE_SUM bytes"
            
#Multiply file size sum by 20% to compensate for unplanned large jobs
COMPENSATION_FACTOR=`echo $JOB_SIZE_SUM*$PERCENT|bc| awk '{print int($1+0.9)}'`; 
echo "Based on the job summary $JOB_SIZE_SUM bytes * $PERCENT varience, the compensation factor for large jobs is: $COMPENSATION_FACTOR bytes"
            
#Add SUM and FACTOR together, this is your new heap size
HEAP=`echo $JOB_SIZE_SUM+$COMPENSATION_FACTOR|bc`; 
echo "Based on the job size summary $JOB_SIZE_SUM bytes and the compenstaion $COMPENSATION_FACTOR bytes, the JHS HEAP should be set to: $HEAP bytes"
echo "Set variable HADOOP_JOB_HISTORYSERVER_HEAPSIZE in mapred-site.xml to $HEAP bytes navigating Ambari > MapReduce2 > Configs > Advanced > History Server > History Server heap size" 

##########################################################################################
# Hadoop 2.7.3 supports property mapreduce.jobhistory.loadedtasks.cache.size
##########################################################################################
#Count all the tasks used on $DATE
TASK_COUNT=`for F in \`sudo -u hdfs hdfs dfs  -ls -R /mr-history/done/$DATE |grep jhist |awk '{print $8}'\`;do sudo -u hdfs hdfs dfs -cat $F |grep -i \"totalMaps\": | python -c 'import sys, json; print json.load(sys.stdin)["event"]["org.apache.hadoop.mapreduce.jobhistory.JobInited"]["totalMaps"]';done|{ tr '\n' +; echo 0;}|bc`;

#Divide the number of task you run by a divisor (a number that equates to something meaningful, ie , 24 is mine for 24 hours, so i am going to cache only the last hour of jobs) 
TASK_CACHE_SIZE=`echo $TASK_COUNT/$DIVISOR|bc`;
echo "Based on $TASK_COUNT tasks and the divisor $DIVISOR, you should set the JHS task cache size (mapreduce.jobhistory.loadedtasks.cache.size) to: $TASK_CACHE_SIZE"
      
#Multiply the task cache size by a historical task size (15 kb) to get a rough heap estimate before the compensation
TASK_SIZE_KB=15
TASK_SIZE_SUM=`echo $TASK_CACHE_SIZE*$TASK_SIZE_KB|bc`;

#Multiply task cache  size sum by 20% to compensate for unplanned large jobs
COMPENSATION_FACTOR=`echo $TASK_SIZE_SUM*$PERCENT|bc| awk '{print int($1+0.9)}'`; 
echo "Based on the task count $TASK_COUNT * $TASK_SIZE_KB task size * $PERCENT varience, the compensation factor is: $COMPENSATION_FACTOR bytes"
            
# Sum the task size and compensation factor together, this is your new heap size
HEAP=`echo $TASK_SIZE_SUM+$COMPENSATION_FACTOR|bc`; 
echo "Based on the task size summary $TASK_SIZE_SUM bytes and the compenstaion $COMPENSATION_FACTOR bytes, the JHS HEAP should be set to: $HEAP bytes"
echo "Set variable HADOOP_JOB_HISTORYSERVER_HEAPSIZE in mapred-site.xml to $HEAP bytes navigating Ambari > MapReduce2 > Configs > Advanced > History Server > History Server heap size" 

