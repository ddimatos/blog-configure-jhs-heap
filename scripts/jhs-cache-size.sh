
#NOTE: This script is a work in progress, it will be some more time before its ready for use.

#Count all the .jhst and .xml files for a day to get an idea of the number of jobs you run
DATE="2017/02/10";
]PERCENT=".20";
DIVISOR=24;
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

################################################################################
# STDOUT for the above commands:
################################################################################
# root@localhost ~]# DATE="2017/02/10";
# root@localhost ~]# PERCENT=".20";
# root@localhost ~]# DIVISOR=24;
# root@localhost ~]# JOB_COUNT=`sudo -u hdfs hdfs dfs -ls -R /mr-history/done/$DATE |grep jhist | gawk '{n++;} END {print n;}'`;
# root@localhost ~]# echo "$JOB_COUNT Jobs were run on date $DATE";
#                     77 Jobs were run on date 2017/02/10
# root@localhost ~]# JOB_CACHE_SIZE=`echo $JOB_COUNT/$DIVISOR|bc`;
# root@localhost ~]# echo "Based on $JOB_COUNT jobs and the divisor $DIVISOR, you should set the JHS cache size (mapreduce.jobhistory.loadedjobs.cache.size) to: $JOB_CACHE_SIZE"
#                     Based on 77 jobs and the divisor 24, you should set the JHS cache size (mapreduce.jobhistory.loadedjobs.cache.size) to: 3
# root@localhost ~]# XML_FILE_SUM=`sudo -u hdfs hdfs dfs -ls -R /mr-history/done/$DATE |grep xml |sort -r -k 5,5|head -$JOB_CACHE_SIZE | gawk '{sum += $5;} END {print sum;}'`;
# root@localhost ~]# echo "The sum for the largest $JOB_CACHE_SIZE XML files for date $DATE is: $XML_FILE_SUM bytes";
#                     The sum for the largest 3 XML files for date 2017/02/10 is: 387080 bytes
# root@localhost ~]# JHIST_FILE_SUM=`sudo -u hdfs hdfs dfs -ls -R /mr-history/done/$DATE |grep jhist |sort -r -k 5,5|head -$JOB_CACHE_SIZE | gawk '{sum += $5;} END {print sum;}'`
# root@localhost ~]# echo "The sum for the largest $JOB_CACHE_SIZE JHIST files for date $DATE is: $JHIST_FILE_SUM bytes";
#                     The sum for the largest 3 JHIST files for date 2017/02/10 is: 100585 bytes
# root@localhost ~]# JOB_SIZE_SUM=`echo $XML_FILE_SUM + $JHIST_FILE_SUM|bc`;
# root@localhost ~]# echo "The sum for the largest $JOB_CACHE_SIZE job logs is: $JOB_SIZE_SUM bytes"
#                     The sum for the largest 3 job logs is: 487665 bytes
# root@localhost ~]# COMPENSATION_FACTOR=`echo $JOB_SIZE_SUM*$PERCENT|bc| awk '{print int($1+0.9)}'`;
# root@localhost ~]# echo "Based on the job summary $JOB_SIZE_SUM bytes * $PERCENT varience, the compensation factor for large jobs is: $COMPENSATION_FACTOR bytes"
#                     Based on the job summary 487665 bytes * .20 varience, the compensation factor for large jobs is: 97533 bytes
# root@localhost ~]# HEAP=`echo $JOB_SIZE_SUM+$COMPENSATION_FACTOR|bc`;
# root@localhost ~]# echo "Based on the job size summary $JOB_SIZE_SUM bytes and the compenstaion $COMPENSATION_FACTOR bytes, the JHS HEAP should be set to: $HEAP bytes"
#                         Based on the job size summary 487665 bytes and the compenstaion 97533 bytes, the JHS HEAP should be set to: 585198 bytes
                                  
#########################################################
# IGNORE STEP 3, this is a work in progress for IOP 4.3 - Hadoop 2.7.3
#########################################################
3) Well there is another property that by default is NOT enabled until it is provided a positive number, 
   that property mapreduce.jobhistory.loadedtasks.cache.size and controls the JHS server by a TASK count. 
   So now you don't control your JHS by jobs, you configure it by deciding how many tasks should be retained
   for displaying in the JHS UI.

   If the total number of tasks loaded exceeds this value, then the job cache will be shrunk down until 
   it is under this limit (minimum 1 job in cache). If this value is empty or nonpositive then the cache 
   reverts to using the property mapreduce.jobhistory.loadedjobs.cache.size as a job cache size. 

   (from mapred-default.xml)
   The 2 recommendations for the mapreduce.jobhistory.loadedtasks.cache.size property are:
   a) For every 100k of cache size, set the heap size of the Job History Server to 1.2GB. 
      For example, mapreduce.jobhistory.loadedtasks.cache.size=500000, heap size=6GB.
   b) Make sure that the cache size is larger than the number of tasks required for the largest job run on the cluster. 
      It might be a good idea to set the value slightly higher (say, 20%) in order to allow for job size growth. 

   Now you are probably wondering how to calculate the number of tasks for the past day such that you can come up
   with a reasonable task cache size. If you review review your jobs for the day in HDFS, you can calculate the 
   number of tasks. Each job has JSON used by JHS and there is a key and value pair indicating the number
   of tasks, this is totalMaps:16, so here the key is totalMaps  and the value 16 (16 tasks)

   Running this command find parse all job log files for a given day, extract the totalMaps JSON , parse 
   it for the value of tasks and then sum the values. These values are the total maps tasks , when summed, 
   they account for all tasks for a given day which you can then use to set mapreduce.jobhistory.loadedtasks.cache.size.

   for F in `sudo -u hdfs hdfs dfs  -ls -R /mr-history/done/2017/02/10 |grep jhist |awk '{print $8}'`;do sudo -u hdfs hdfs dfs -cat $F |grep -i \"totalMaps\": | python -c 'import sys, json; print json.load(sys.stdin)["event"]["org.apache.hadoop.mapreduce.jobhistory.JobInited"]["totalMaps"]';done|{ tr '\n' +; echo 0; }|bc

   After you have the total number of map tasks for a day, you can then decide how many you want to cache, 
   if you choose  you want 500000 tasks, mapreduce.jobhistory.loadedtasks.cache.size=500000, then you need to 
   adjust your heap to accommodate each task size. JIRA MAPREDUCE-6622 recommends setting HEAP to  1.2GB + 20% which 
   averages each task about 16k, I have found through testing that most tasks are closer to 30k. I covered 
   how to measure this in the first step. 
