CURRTIME=`date +%s`;
FILETIME=`ls -l --time-style=+%s /jobalert/logs/Cycle3a.log | awk '{print$6}'`;
hour=`echo "( $CURRTIME - $FILETIME ) /3600" | bc`;
min=`echo "( ( $CURRTIME - $FILETIME ) %3600 ) /60" | bc`;

if [[ $hour -le 0 && $min -le 20 ]]; then
        echo "OK : Cycle3a running logs with log delay $hour hour $min min"
        exit $STATE_OK
     exit 0
else
ps aux  |grep -v grep| grep -e /bin/.*sh > /opt/ps.txt
/usr/local/bin/sendEmail -t  saints@timesgroup.com,24x7grp@timesinternet.in  -f jobalert@timesjobsmail.com -l /var/log/sendEmail -u "Cycle3a stopped or complete on 172.29.75.204" -m "Hi All ,\n\nPlease start Cycle3a process on 172.29.75.204 \n\n Check log if completed than Start:- nohup ./NewJobAlertBatch.sh Cycle3a DD-MM-YYYY & \n\n Check log if log hang than Start with old date :- nohup ./NewJobAlertBatch.sh Cycle3a (old date DD-MM-YYYY) & \n\n Thanks & Regards,\nSunil kumar\nTBSL Noida" 
fi
