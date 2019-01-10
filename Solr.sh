#!/bin/bash

YDATE=`date -d "1 day ago" +"%d%b%y"`
TDATE=`date +%d%b%y`
HTIME=`date +%H:%M`
/bin/mkdir /tmp/solrlogs_$TDATE
##############Delete Old Indexes########################################################
/usr/bin/ssh 172.29.75.209 'bash -s' << EOF
/bin/rm -rf /index/timesjobs/resume/data/index_$YDATE
EOF

/bin/echo -e "\n\t1-Old indexes are delete & going to copy ivr\n" > /tmp/solrlogs_$TDATE/Script-Status.out

############Copy Ivr to Slaves###########################################################
for i in 172.29.75.209 172.29.75.210 172.29.75.220 172.29.75.221 
do
/usr/bin/scp -r /opt/timesjobs/ivr-new/data/index root@$i:/index/timesjobs/ivr-new/data/index_ivr 
done
for j in 172.29.75.169 172.29.75.170 172.29.75.171
do
/usr/bin/scp -r /opt/timesjobs/ivr-new/data/index root@$j:/index/timesjobs/ivr-new/data/index_ivr 
done

/bin/echo -e "\n\t2-IVR Copy on slaves & going to execute scripts on remote 75.142\n" >> /tmp/solrlogs_$TDATE/Script-Status.out
#############################75-142 Scripts##############################################################

/usr/bin/ssh 172.29.75.142 '/bin/sh /opt/BatchProcesses/Block.sh ; /bin/sh /opt/BatchProcesses/CanUpdation.sh ; /bin/sh /opt/BatchProcesses/BatchProcessUserCand.sh'    > /tmp/solrlogs_$TDATE/85.out 

/bin/echo -e "\n\t3-Script Execute on remote 75.142 server & going to kill real time Full & stop replication\n" >> /tmp/solrlogs_$TDATE/Script-Status.out
############################stop Replication & kill realTimeFull###########################

ps aux|egrep [r]ealTimeFull | awk '{print $2}' | xargs kill -9
/usr/bin/kill -9 $(ps aux|grep java | grep [R]esumeIndexTool | awk '{print $2}')
sleep 4
/usr/bin/kill -9 $(ps aux|grep java | grep [R]esumeIndexTool | awk '{print $2}')
#ps aux|egrep [r]ealTimeFull | awk '{print $2}' | xargs kill -9                                                                                       
sleep 4
#ps aux|grep java | grep [R]esumeIndexTool | awk '{print $2}' | xargs kill -9
/usr/bin/kill -9 $(ps aux|grep java | grep [R]esumeIndexTool | awk '{print $2}')
sleep 4
#ps aux|grep java | grep [R]esumeIndexTool | awk '{print $2}' | xargs kill -9
/usr/bin/kill -9 $(ps aux|grep java | grep [R]esumeIndexTool | awk '{print $2}')
sleep 4

/bin/sh /opt/timesjobs/resume/bin/disableReplication.sh > /tmp/solrlogs_$TDATE/ReplicationDisbale.out
sleep 5
/bin/echo -e "\n\t4-RealtimeFull kill & Replication disabled & going to run RunprocessStream\n" >> /tmp/solrlogs_$TDATE/Script-Status.out
#########################Start Solr Process################################################

cd /opt/ResumeBatchProcess
nohup /bin/sh runProcessStream.sh &

sleep 10
COUNT1=`ps aux|grep [r]unProcessStream.sh | grep -v grep | wc -l`

while 
[ "$COUNT1" -ge "1" ] 
do
COUNT1=`ps aux|grep [r]unProcessStream.sh | grep -v grep | wc -l`
sleep 10 
done

/bin/echo -e "\n\t5-RunProcessStream Complete & going to execute script on 85 remote machine\n" >> /tmp/solrlogs_$TDATE/Script-Status.out
######################Run Scripts on @85 Server#############################################
sleep 5
/usr/bin/ssh 172.29.75.142 '/bin/sh /opt/BatchProcesses/updateFACandtoCorp.sh' >> /tmp/solrlogs_$TDATE/85.out
/bin/echo -e "\n\t6-Scripts execute on 85 Server & going to run testrunStage1\n" >> /tmp/solrlogs_$TDATE/Script-Status.out
######################Reume Again Solr Process##############################################
sleep 5
cd /opt/ResumeBatchProcess
nohup /bin/sh testrunStage1.sh &

sleep 10

COUNT2=`ps aux|grep [t]estrunStage1.sh | grep -v grep | wc -l`
while 
[ "$COUNT2" -ge "1" ] 
do
COUNT2=`ps aux|grep [t]estrunStage1.sh | grep -v grep | wc -l`
sleep 10 
done

/usr/bin/tail -100 /opt/ResumeBatchProcess/ThreadBaseProcess2/ResumeIndex1.log > /tmp/solrlogs_$TDATE/ResumeIndex.out
/bin/echo -e "\n\t7-Testrunstage1 complete & going to run RunReportAbuse\n" >> /tmp/solrlogs_$TDATE/Script-Status.out
sleep 5
cd /opt/ResumeBatchProcess
nohup /bin/sh runReportAbuse.sh &

sleep 10

COUNT3=`ps aux|grep [r]unReportAbuse.sh | grep -v grep  | wc -l`
while 
[ "$COUNT3" -ge "1" ] 
do
COUNT3=`ps aux|grep [r]unReportAbuse.sh | grep -v grep  | wc -l`
sleep 10 
done

/bin/echo -e "\n\t8-RunReportAbuse complete & going to execute RunHibernateProcess\n" >> /tmp/solrlogs_$TDATE/Script-Status.out
sleep 5
cd /opt/ResumeBatchProcess
nohup /bin/sh runHibernateProcess.sh &

sleep 10
COUNT4=`ps aux|grep [r]unHibernateProcess.sh | grep -v grep  | wc -l`
while 
[ "$COUNT4" -ge "1" ] 
do
COUNT4=`ps aux|grep [r]unHibernateProcess.sh | grep -v grep  | wc -l`
sleep 10 
done

/bin/echo -e "\n\t9-RunHibernateProcess is complete & going to run Optimize\n" >> /tmp/solrlogs_$TDATE/Script-Status.out
#########################Run Optimization##########################################################
sleep 5
nohup /bin/sh /opt/timesjobs/resume/bin/optimize.sh &

sleep 10
COUNT5=`ps aux|grep [o]ptimize.sh  | grep -v grep | wc -l`
while 
[ "$COUNT5" -ge "1" ] 
do
COUNT5=`ps aux|grep [o]ptimize.sh  | grep -v grep | wc -l`
sleep 10
done

/bin/echo -e "\n\t10-Optmize Complete & going to live the index on 1st Slave \n" >> /tmp/solrlogs_$TDATE/Script-Status.out

#######################Live Index on 1st-209 Slave##########################################################
/usr/bin/scp -r /opt/timesjobs/resume/data/index root@172.29.75.209:/index/timesjobs/resume/data/index_full
/usr/bin/ssh 172.29.75.209 'bash -s' << EOF
/bin/sh /opt/tomcat/bin/shutdown.sh ; sleep 10 ;  killall -9 java
cd /index/timesjobs/resume/data/
/bin/mv index index_$TDATE
/bin/mv index_full index
cd /index/timesjobs/ivr-new/data/
/bin/mv index index_$TDATE
/bin/mv index_ivr index
/bin/sh /opt/tomcat/bin/startup.sh
EOF
sleep 5

#######################Live Index on 2nd-210 Slave##########################################################
/usr/bin/scp -r /opt/timesjobs/resume/data/index root@172.29.75.210:/index/timesjobs/resume/data/index_full
/usr/bin/ssh 172.29.75.210 'bash -s' << EOF
/bin/sh /opt/tomcat/bin/shutdown.sh ; sleep 10 ;  killall -9 java
cd /index/timesjobs/resume/data/
/bin/rm -rf index
/bin/mv index_full index
cd /index/timesjobs/ivr-new/data/
/bin/rm -rf index 
/bin/mv index_ivr index
/bin/sh /opt/tomcat/bin/startup.sh
EOF
sleep 5
###################################################################################################
#######################Live Index on 3rd 220 Slave##########################################################
/usr/bin/scp -r /opt/timesjobs/resume/data/index root@172.29.75.220:/index/timesjobs/resume/data/index_full
/usr/bin/ssh 172.29.75.220 'bash -s' << EOF
/bin/sh /opt/tomcat/bin/shutdown.sh ; sleep 10 ;  killall -9 java
cd /index/timesjobs/resume/data/
/bin/rm -rf index
/bin/mv index_full index
cd /index/timesjobs/ivr-new/data/
/bin/mv index index_$TDATE
/bin/mv index_ivr index
/bin/sh /opt/tomcat/bin/startup.sh
EOF
sleep 5
#######################Live Index on 4th-221 Slave##########################################################
/usr/bin/scp -r /opt/timesjobs/resume/data/index root@172.29.75.221:/index/timesjobs/resume/data/index_full
/usr/bin/ssh 172.29.75.221 'bash -s' << EOF
/bin/sh /opt/tomcat/bin/shutdown.sh ; sleep 10 ;  killall -9 java
cd /index/timesjobs/resume/data/
/bin/rm -rf index
/bin/mv index_full index
cd /index/timesjobs/ivr-new/data/
/bin/rm -rf index 
/bin/mv index_ivr index
/bin/sh /opt/tomcat/bin/startup.sh
EOF
sleep 120


######################### 75.111.#################################
#######################Live Index on 4th-111 Slave##########################################################
/usr/bin/scp -r /opt/timesjobs/resume/data/index root@172.29.75.111:/data/timesjobs/resume/data/index_full
/usr/bin/ssh 172.29.75.111 'bash -s' << EOF
/bin/sh /opt/tomcat/bin/shutdown.sh ; sleep 10 ;  killall -9 java; killall -9 java
cd /data/timesjobs/resume/data/
/bin/rm -rf index
/bin/mv index_full index
sleep 5
/bin/echo 3 >/proc/sys/vm/drop_caches 
/bin/sh /opt/tomcat/bin/startup.sh
EOF
sleep 600

######################----------------start Proccess for 75.250-----##############
#/usr/bin/ssh 172.29.75.250 '/bin/sh /root/scripts/process_data_dataextraction.sh'
#/usr/bin/ssh 172.29.75.250 'bash -s' << EOF
/usr/bin/scp -r /opt/timesjobs/resume/data/index 172.29.75.250:/data/solrhome/timesjobs/resume/data/index_full
/usr/bin/ssh 172.29.75.250 'bash -s' << EOF
/usr/bin/ps -ef | grep java | grep -i "com.tj.dataextraction" | /usr/bin/awk '{print $2}'| xargs /usr/bin/kill -9;
sleep 10;
/usr/bin/ps -ef | grep java | grep -i "com.tj.dataextraction" | /usr/bin/awk '{print $2}'| xargs /usr/bin/kill -9;
cd /data/solrhome/timesjobs/resume/data
/bin/rm -rf index
/bin/mv index_full index
cd /data/spreadprojectslive/spreadbatch/;
#/bin/sh /data/spreadprojectslive/spreadbatch/dataextractionprocess.sh
cd /data/spreadprojectslive/spreadbatch/;/bin/sh /data/spreadprojectslive/spreadbatch/dataextractionprocess.sh >> /data/spreadprojectslive/spreadbatch/nohup.out 2>&1 &
EOF
sleep 120

##########################################################################################################

#######################Live Index on 4th-151 Slave##########################################################
/usr/bin/scp -r /opt/timesjobs/resume/data/index root@172.29.75.151:/resumeIndex/index_full
/usr/bin/ssh 172.29.75.151 'bash -s' << EOF
/bin/sh /opt/tomcat/bin/shutdown.sh ; sleep 10 ;  killall -9 java; killall -9 java
cd /resumeIndex/
/bin/rm -rf index
/bin/mv index_full index
/bin/echo 3 >/proc/sys/vm/drop_caches
/bin/sh /opt/tomcat/bin/startup.sh
EOF
sleep 600

########################    Start Full Index    ###########################################################

cd /opt/ResumeBatchProcess/
nohup /bin/sh realTimeFull.sh &

sleep 20

########################### Sending Mail ###################################################################


#HIRE60=`curl "http://172.16.85.60:8080/Hire/resume/select?q=*%3A*&wt=json&indent=true" 2> /dev/null  | grep numFound  | awk -F: '/"numFound":/{print $3}' > /tmp/60  && tr -d 'start,"' </tmp/60> /tmp/60.out && cat /tmp/60.out`
HIRE209=`curl "http://172.29.75.209/Hire/resume/select?q=*%3A*&wt=json&indent=true" 2> /dev/null  | grep numFound  | awk -F: '/"numFound":/{print $3}' > /tmp/209  && tr -d 'start,"' </tmp/209> /tmp/209.out && cat /tmp/209.out`
HIRE210=`curl "http://172.16.85.210/Hire/resume/select?q=*%3A*&wt=json&indent=true" 2> /dev/null  | grep numFound  | awk -F: '/"numFound":/{print $3}' > /tmp/210  && tr -d 'start,"' </tmp/210> /tmp/210.out && cat /tmp/210.out`
HIRE220=`curl "http://172.16.85.220/Hire/resume/select?q=*%3A*&wt=json&indent=true" 2> /dev/null  | grep numFound  | awk -F: '/"numFound":/{print $3}' > /tmp/220  && tr -d 'start,"' </tmp/220> /tmp/220.out && cat /tmp/220.out`
HIRE221=`curl "http://172.16.85.221/Hire/resume/select?q=*%3A*&wt=json&indent=true" 2> /dev/null  | grep numFound  | awk -F: '/"numFound":/{print $3}' > /tmp/221  && tr -d 'start,"' </tmp/221> /tmp/221.out && cat /tmp/221.out`
HIRE63=`curl "http://172.16.85.63/Hire/resume/select?q=*%3A*&wt=json&indent=true" 2> /dev/null  | grep numFound  | awk -F: '/"numFound":/{print $3}' > /tmp/63  && tr -d 'start,"' </tmp/63> /tmp/63.out && cat /tmp/63.out`
HIRE168=`curl "http://172.29.75.168:8080/Hire/resume/select?q=*%3A*&wt=json&indent=true" 2> /dev/null  | grep numFound  | awk -F: '/"numFound":/{print $3}' > /tmp/168  && tr -d 'start,"' </tmp/168> /tmp/168.out && cat /tmp/168.out`
HIRE169=`curl "http://172.29.75.169/Hire/resume/select?q=*%3A*&wt=json&indent=true" 2> /dev/null  | grep numFound  | awk -F: '/"numFound":/{print $3}' > /tmp/169  && tr -d 'start,"' </tmp/169> /tmp/169.out && cat /tmp/169.out`
HIRE170=`curl "http://172.29.75.170/Hire/resume/select?q=*%3A*&wt=json&indent=true" 2> /dev/null  | grep numFound  | awk -F: '/"numFound":/{print $3}' > /tmp/170  && tr -d 'start,"' </tmp/170> /tmp/170.out && cat /tmp/170.out`
HIRE171=`curl "http://172.29.75.171/Hire/resume/select?q=*%3A*&wt=json&indent=true" 2> /dev/null  | grep numFound  | awk -F: '/"numFound":/{print $3}' > /tmp/171  && tr -d 'start,"' </tmp/171> /tmp/171.out && cat /tmp/171.out`




COUNT=`echo -e "Hire Solr Resume Live Process has been fully Automated now, Please find Below HireSolrs & Slaves Resume Index Count & If the count of 223 and 168 Master Solr not match with its slaves then check the Process manually\n\n************************************************************\n\tServers\t\t\tCounts\n************************************************************\n\t$HIRE60\n\tHIRE209\t\t$HIRE210\n\t$HIRE220\t\t$HIRE221\n\t$HIRE169\t$HIRE170\t$HIRE171\n************************************************************\n\n************************************************************"`

/usr/local/bin/sendEmail -f hire-solr@timesmail.com -t saints@timesgroup.com,tjtech@timesgroup.com  -u "HireSolr Resume Process Complete - $TDATE" -m "Hi Team,\n\n$COUNT\nNote:- The attached file contains executed Steps informations during the Process & if you need more logs informations then check at /tmp/solrlogs_$TDATE location of 223 & 168 Servers \n\nRegards\nsysadmin"  -a  "/tmp/solrlogs_$TDATE/Script-Status.out"


/bin/echo -e "\n\t15-Process is Complete & Mail is Sended to Particular Team & if you want to check script-status of 75-169 server then check it at tmp location of 75-169 server\n" >> /tmp/solrlogs_$TDATE/Script-Status.out
##############################################################################################################
