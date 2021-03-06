source('https://raw.githubusercontent.com/ZyuAFD/SWRE_Project/master/Non_stationaryGenerator/Non_StationaryInterMFunctions.R')


library(data.table)
library(lubridate)
library(RcppRoll)

###  Load Historical data -----------
Path='\\\\SWV.cae.drexel.edu\\ziwen\\Research\\Precipitation analysis\\Data\\'

#### PHL data  
PHL_Clim=fread(paste0(Path,'PHL\\Air Pressure & Temp & Humidity\\9901356023046dat.txt'),
               sep=',',
               skip=2,
               col.names = c('USAF',
                             'NCDC',
                             'Date',
                             'HrMn',
                             'I',
                             'Type',
                             'Temp',
                             'Temp_Q',
                             'DewPt',
                             'DewPt_Q',
                             'SLP',
                             'SLP_Q',
                             'PRES_CHG_T',
                             'PRES_CHG_Q',
                             'PRES_CHG_3Hr',
                             'PRES_CHG_3Hr_Q',
                             'PRES_CHG_24Hr',
                             'PRES_CHG_24Hr_q',
                             'RHX',
                             'unk'),
               colClasses=c('numeric',
                            'numeric',
                            'Character',
                            'Character',
                            'Character',
                            'Character',
                            'numeric',
                            'Character',
                            'numeric',
                            'Character',
                            'numeric',
                            'Character',
                            'numeric',
                            'Character',
                            'numeric',
                            'Character',
                            'numeric',
                            'Character',
                            'numeric',
                            'Character')) %>% 
  mutate(Time=ymd_hm(paste(Date,HrMn))) %>% 
  select(Time,
         Temp,
         DewPt,
         SLP) %>% 
  #Remove invalid datas
  mutate(Temp=ifelse(Temp==999.9,NA,Temp),
         DewPt=ifelse(DewPt==999.9,NA,DewPt),
         SLP=ifelse(SLP==9999.9,NA,SLP)) %>% 
  #Round time to hourly step
  mutate(Time=Round_hour(Time)) %>% 
  #Combine duplicated Time
  select(Time,
         Temp,
         DewPt,
         SLP) %>% 
  group_by(Time) %>% 
  summarise(Temp=mean(Temp,na.rm =T),
            DewPt=mean(DewPt,na.rm =T),
            SLP=mean(SLP,na.rm =T))


#Get column names
Col_Nm=fread(paste0(Path,'PHL\\Precip\\Data1900~2010.txt'),
             nrows=1,
             header=F,
             sep=',') %>% 
  t(.)
             
PHL_Precip=fread(paste0(Path,'PHL\\Precip\\Data1900~2010.txt'),
                 skip=2,
                 sep=',',
                 col.names = Col_Nm,
                 colClasses = c('numeric',
                                'character',
                                'character',
                                'character',
                                'character',
                                'character',
                                'character',
                                'character','numeric','character','character',
                                'character','numeric','character','character',
                                'character','numeric','character','character',
                                'character','numeric','character','character',
                                'character','numeric','character','character',
                                'character','numeric','character','character',
                                'character','numeric','character','character',
                                'character','numeric','character','character',
                                'character','numeric','character','character',
                                'character','numeric','character','character',
                                'character','numeric','character','character',
                                'character','numeric','character','character',
                                'character','numeric','character','character',
                                'character','numeric','character','character',
                                'character','numeric','character','character',
                                'character','numeric','character','character',
                                'character','numeric','character','character',
                                'character','numeric','character','character',
                                'character','numeric','character','character',
                                'character','numeric','character','character',
                                'character','numeric','character','character',
                                'character','numeric','character','character',
                                'character','numeric','character','character',
                                'character','numeric','character','character',
                                'character','numeric','character','character')) 

PHL_Precip[ , !duplicated(colnames(PHL_Precip)),with=F] %>% 
  select(YEAR,
         MO,
         DA,
         HOUR01,
         HOUR02,
         HOUR03,
         HOUR04,
         HOUR05,
         HOUR06,
         HOUR07,
         HOUR08,
         HOUR09,
         HOUR10,
         HOUR11,
         HOUR12,
         HOUR13,
         HOUR14,
         HOUR15,
         HOUR16,
         HOUR17,
         HOUR18,
         HOUR19,
         HOUR20,
         HOUR21,
         HOUR22,
         HOUR23,
         HOUR24) %>% 
  mutate(Date=paste(YEAR,MO,DA,sep='-')) %>% 
  select(-YEAR,-MO,-DA) %>% 
  gather(Hour,Precip,-Date) %>% 
  mutate(Hour=substr(Hour,5,6)) %>% 
  mutate(Time=ymd_h(paste(Date,Hour))) %>% 
  #Round time to hourly step
  mutate(Time=Round_hour(Time)) %>% 
  select(Time,Precip) %>% 
  mutate(Precip=ifelse(Precip>999,0,Precip)) %>% 
  group_by(Time) %>% 
  summarise(Precip=mean(Precip,na.rm =T)) %>% 
  arrange(Time) ->PHL_Precip


############### Date Range
Dt_Rng=rbind(
  PHL_Precip %>% 
    select(Time) %>% 
    summarise(MinTm=min(Time),
              MaxTm=max(Time)),
  PHL_Clim %>% 
    select(Time) %>% 
    summarise(MinTm=min(Time),
              MaxTm=max(Time))
  ) %>% 
  summarise(MinTm=max(MinTm),MaxTm=min(MaxTm)) 


PHL_Clim %<>% 
  filter(Time>=Dt_Rng$MinTm,
         Time<=Dt_Rng$MaxTm) 

PHL_Precip %<>% 
  filter(Time>=Dt_Rng$MinTm,
         Time<=Dt_Rng$MaxTm) 

PHL_Clim %>% 
  full_join(PHL_Precip,by=c('Time'='Time')) -> PHL

# Manipulation ---------
PHL %<>%
    arrange(Time) %>%
    pad %>% 
    mutate(SLP.spl=spline(x=Time,y=SLP,xout=Time)$y,
          Temp.spl=spline(x=Time,y=Temp,xout=Time)$y) %>%
    # Moving average
    mutate(Temp.av=roll_mean(Temp.spl,n=24,align='center',fill=NA),
           SLP.av=roll_mean(SLP.spl,n=24,align='center',fill=NA)) %>% 
    # Change of SLP to previous day
    mutate(SLP_chng.av=SLP.av-lag(SLP.av,24))

rm(Col_Nm,Dt_Rng,PHL_Clim,PHL_Precip)
