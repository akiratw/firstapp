#!/bin/bash
#定義DOMAIN 目錄
HOME_PATH=/webmail/usr/0/udngroup.com
START_DAY=`date -d '3 days ago' +"%Y-%m-%d"`
#DUMP_LOGIN_LOG FOR TOOLS
DUMP_LOGIN=/webmail/tools/dump_login_log
################################################################
# DUMP 語法為: -u $USER -r failure -t imap4
#執行時間
################################################################
DT_S=`date +"%Y/%m/%d %H:%M:%S"`
#檔案日期
DT=`date +"%Y%m%d"`
LOGPATH=/webmail/log_archive/userlogin
#依帳號登入錯誤次分別寫入的檔案
LOGIN_FAIL_IP_PREFIX=loginfail.$DT.list
ALL_USER_LIST=user_list.$DT.list
LOGIN_FAIL_USER=loginfail_user.$DT.list
LOGIN_FAIL_IPCOUNT=loginfail_ip_count.$DT.list
echo check User list folder
cd $LOGPATH/
rm -rf $ALL_USER_LIST
rm -rf $LOGIN_FAIL_USER
rm -rf $LOGIN_FAIL_IPCOUNT
touch $ALL_USER_LIST
echo "touch $LOGIN_FAIL_IPCOUNT"
touch $LOGIN_FAIL_IPCOUNT
ls $LOGIN_FAIL_IPCOUNT
echo $LOGIN_FAIL_IPCOUNT
################################################################
#從MAIL DOMAIN 目錄的下一層開始算三層為Mail User name
#透過 USER_LIST 指令執行 帳號列舉
#在帳號列舉的過程中,列出登入錯誤的次數
################################################################
USER_FOLDER_LEVEL=0
USER_COUNT=0
#整理登入錯誤的IP統計表
LOGIN_FAIL_IP_LIST() {
((USER_FOLDER_LEVEL++))
################################################################
#FS=列出檔名(含檔案或目錄) 
#$FOLDER_LEN=`echo $1 |awk -F "" '{print NF}'`
#echo $FOLDER_LEN
################################################################
for FS in `ls $1` ; do
	if [ -d $1/$FS ] ; then 
		if [ $USER_FOLDER_LEVEL == 3 ] ; then 
#判斷passwd 將使用者名稱匯出到USERLIST.date
			if [ -f $1/$FS/.passwd ] ; then
				echo PATH=${FS}_$LOGIN_FAIL_IP_PREFIX
				echo 寫入異常登入清單
###############################################################
#將帳號的登入錯誤的IP清單寫入$LOGPATH/${FS}_$LOGIN_FAIL_IP_PREFIX
#並檢查是否有帳號是異常的
#如果空白檔案
                                $DUMP_LOGIN -u $FS -r failure | sed "s/Login/Login ${FS}/" |sed 1d > ${FS}_$LOGIN_FAIL_IP_PREFIX
				RECORDS=`grep -c . ${FS}_$LOGIN_FAIL_IP_PREFIX`
				echo RECORDS=${RECORDS}
				if [ ${RECORDS} -gt 0 ] ; then 
					echo $FS 全部登入錯誤IP列表寫入完成   檢查是否有登入記錄 ERR=$ERR
					COUNT=0	
					unset SOURCE_IP
				for J in `cat ${FS}_$LOGIN_FAIL_IP_PREFIX|cut -f 10 -d" "` ; do
					echo ${SOURCE_IP[@]} | grep $J 1>/dev/null 2>&1
					ERR=$?
					echo 檢查${J}是否為新的IP ERR=${ERR}
					if [ ${ERR} -gt 0 ] ; then 
						echo 新的IP記錄寫入陣列索引:$COUNT IP=$J 
#新增資料到SOURCE_IP 陣列
						SOURCE_IP[$COUNT]="$J,1"
						((COUNT++))
					else 
						for ((K=0;K<${#SOURCE_IP[@]};K=$K+1)); do 
							IP=`echo ${SOURCE_IP[$K]}|cut -f1 -d","`
							if [ ${J} = ${IP} ] ;then
								IP_COUNT=`echo ${SOURCE_IP[$K]}|cut -f2 -d","`
								((IP_COUNT++))	
								unset SOURCE_IP[$K]
								SOURCE_IP[${K}]=$IP,$IP_COUNT
								echo 更新$IP登入錯誤次數$IP_COUNT
								unset IP_COUNT
							fi  
						done
					fi		
				done
				else 
 					echo "${FS}	登入失敗的清單寫入錯誤" >> ${LOGPATH}/loginfail_ip.err
					rm -rf ${FS}_$LOGIN_FAIL_IP_PREFIX
				fi 
				echo ===============USER $FS LOGIN FAIL IP LIST==============
###############################################################
#逐行列出本帳號的登入錯誤來源IP
#過濾將有登入錯誤的帳號寫入 $LOGIN_FAIL_USER 的LOG檔案
###############################################################
				for ((K=0;K<${#SOURCE_IP[@]};K=$K+1)); do
					if [ ! -z ${SOURCE_IP[K]} ] ; then 
						echo SOURCE_IP 有資料,正在寫入LOGIN_FAIL_IPCOUNT 
               					IP=`echo ${SOURCE_IP[K]} | cut -f1 -d","`
						IPCOUNT=`echo ${SOURCE_IP[K]} | cut -f2 -d","`
						CHECK_USERCOUNT=`grep -c "^${IP}," ${LOGIN_FAIL_IPCOUNT}`
						echo ${FS} CHECK_USERCOUNT = ${CHECK_USERCOUNT}
						if [ ${CHECK_USERCOUNT} = 0 ] ;then 
							echo 未發現 ${IP},${IPCOUNT},1 寫入 $LOGIN_FAIL_IPCOUNT
                                                        echo ${IP},${IPCOUNT},1 >> ${LOGIN_FAIL_IPCOUNT}
						else	
							IPCOUNT_LAST=`grep "^${IP},"  ${LOGIN_FAIL_IPCOUNT} | cut -f2 -d","`
							USERCOUNT_LAST=`grep "^${IP},"  ${LOGIN_FAIL_IPCOUNT} | cut -f3 -d","`
							echo "IPCOUNT_LAST = $IPCOUNT_LAST USERCOUNT_LAST = $USERCOUNT_LAST"
							echo $IP 目前登入錯誤次數 $IPCOUNT
							IPCOUNT=$((${IPCOUNT}+${IPCOUNT_LAST}))
							USERCOUNT=$(($USERCOUNT_LAST+1))
							echo 上次$IP 登入錯誤次數 $IPCOUNT_LAST
							echo 上次$IP 登入錯誤帳號次數 $USERCOUNT_LAST
							echo 更新錯誤登入次數 ${IP},${IPCOUNT},${USERCOUNT} to ${LOGIN_FAIL_IPCOUNT}
							sed -i "s/${IP},${IPCOUNT_LAST},${USERCOUNT_LAST}/${IP},${IPCOUNT},${USERCOUNT}/" ${LOGIN_FAIL_IPCOUNT}
						fi
					fi
			        done
				echo $FS 總共有$K個錯誤登入來源IP
				if [ $K == 0 ] ;then 
					rm -rf ${LOGIN_FAIL_USER}
					echo $FS 未有登入錯誤記錄
				else
					echo =========Write $FS to LOIGN FAIL USER======
					echo $FS >> $LOGIN_FAIL_USER
					echo $FS帳號己寫入$LOGIN_FAIL_USER完成
				fi
			fi 
		else 
################################################################
#檢查Mail Domain 的子層目錄名稱長度，0-F 為Mail 帳戶的資料夾。
################################################################
			if [ $USER_FOLDER_LEVEL = 1 ] && [ ${#FS} -ge 2 ]; then	
				echo $FS Not user folder
			else 
				LOGIN_FAIL_IP_LIST "$1/$FS"

			fi
		fi
	fi
done
((USER_FOLDER_LEVEL--))

}
###########################################
#執行使用者帳號清單列舉
###########################################
LOGIN_FAIL_IP_LIST $HOME_PATH 1





