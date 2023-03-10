library(jsonlite)
library(tswge)
library(lsa)  ##for cosine similarity
library(proxy) ## for jaccard similarity
library(neighbr)
library(nnfor)
library(RDCOMClient)

#######################################################################################

read_data<-function(which_data='monthly'){

  ##change which_data for different m3 series
  json_file = switch(
    which_data,
    "monthly"= lapply(readLines("https://raw.githubusercontent.com/tavinweeda/Capstone/main/OneDrive/Desktop/Git_Cap/M3_Json/monthly.json"), fromJSON),
    "yearly"= lapply(readLines("https://raw.githubusercontent.com/tavinweeda/Capstone/main/OneDrive/Desktop/Git_Cap/M3_Json/yearly.json"), fromJSON),
    "quarterly"= lapply(readLines("https://raw.githubusercontent.com/tavinweeda/Capstone/main/OneDrive/Desktop/Git_Cap/M3_Json/quarterly.json"), fromJSON),
    "other"= lapply(readLines("https://raw.githubusercontent.com/tavinweeda/Capstone/main/OneDrive/Desktop/Git_Cap/M3_Json/other.json"), fromJSON),
  )

  return(json_file)

}

#######################################################################################-

to_numeric<-function(json_file){
  ##turn target variables into numeric from string, if necessary

  json_file <- lapply(json_file, function(x) {
    x$target <- as.numeric(x$target)
    return(x)
  })

  return(json_file)
}

#######################################################################################-


series_features<-function(json_file){
  ##stores information as seasonality, difference, phis thetas, and overall series length

  json_file<-lapply(json_file,function(x){
    x$series_features<-list('p'=0,'q'=0,'d'=0,'s'=0,'series_length'=length(x$target),'phi'=0,'theta'=0)
    return(x)})


  return(json_file)
}



#######################################################################################-

##This assigns d=1 if p value is less than .05

cochrane_orcutt_eval<-function(json_file){

  json_file<-lapply(json_file,function(x) {

    ##get data

    t<-seq(1,x$series_features$series_length,1)
    data=x$target

    ##fit cochrane orcutt
    fit.lm<-lm(data~t)

    p_value <- tryCatch({
      # code that might produce an error
      summ=summary(cochrane.orcutt(fit.lm,convergence = 1e-6))
      p_value<-summ$coefficients[,4]['t']
    }, error = function(e) {
      # code to execute if an error occurs
      p_value=.03
    })

    if(p_value<=.05){
      x$series_features$d=1
    }
    return(x)
  })

  return(json_file)

}


#



#######################################################################################-


remove_trend_differencing<-function(json_file){

  json_file<-lapply(json_file,function(x) {

    if(x$series_features$d==1){
      x$Transformed=artrans.wge(x$target,c(1),plottr = FALSE) }
    else {
      x$Transformed=x$target
    }


    return(x)

  })
  return(json_file)
}


#######################################################################################-




my_aic<-function (x, p = 0:5, q = 0:2, type = "aic")
{
  pmax = max(p)
  pmin = min(p)
  qmax = max(q)
  qmin = min(q)
  nr = (pmax - pmin + 1) * (qmax - qmin + 1)
  aval <- matrix(0, nrow = nr, ncol = 3)
  mytype = type
  indx = 0
  for (ip in pmin:pmax) for (iq in qmin:qmax) {
    {
      indx <- indx + 1
      ret <- try(aic.wge(x, p = ip, q = iq, type = mytype),
                 silent = TRUE)
      if (is.list(ret) == TRUE) {
        aval[indx, ] <- c(ret$p, ret$q, ret$value)
      }
      else {
        aval[indx, ] <- c(ip, iq, 999999)
      }
    }
  }
  dat <- data.frame(aval)
  sorted_aval <- dat[order(dat[, 3], decreasing = F), ]
}



#######################################################################################-



get_Phi_Thetas_aic<-function(json_file){

  ## estimate phis and thetas...data at this point shoudl be transformed for trend and seasonality
  ##This estimates phis and thetas based off of the top aic value.
  json_file<- lapply(json_file,function(x){

    aic<-my_aic(x$Transformed)
    p=aic$X1[1]
    q=aic$X2[1]
    x$series_features$p=p
    x$series_features$q=q
    estimates<-est.arma.wge(x$Transformed,p=p,q=q,factor=FALSE)
    x$series_features$phi=estimates$phi
    x$series_features$theta=estimates$theta

    return(x)
  }
  )

  return(json_file)
}

#######################################################################################-



#######################################################################################-



forecast_arima<-function(json_file,horizon=0){


  ##this just returns forecasts horizon and series features.
  fore_holder<-invisible(lapply(json_file,function(x){
                                                          fores<-(fore.aruma.wge(x$target,phi=x$series_features$phi,
                                                          theta=x$series_features$theta,
                                                          d=x$series_features$d,
                                                          s=x$series_features$s,
                                                          n.ahead=horizon,
                                                          lastn=TRUE,
                                                          plot = FALSE))

                                                          return(list('forecasts'=fores$f,
                                                                    'horizon'=horizon,
                                                                    'phi'=x$series_features$phi,
                                                                    'theta'=x$series_features$theta,
                                                                    'd'=x$series_features$d,
                                                                    's'=x$series_features$s,
                                                                    'original_length'=x$series_features$series_length))}
  ))



  return(fore_holder)
}


#######################################################################################-


write_forecasts<-function(forecasts,name,folder){

  saveRDS(forecasts, file=paste0(folder,'/',name,".RData"))

}



#######################################################################################-

sMAPE_calculate<-function(json_file,forecast_object){
  #sMAPE_holder<-c()

  ##Gets forecasts and originals for horizon passed.
      my_sMAPES<-lapply(horizon,function(h) {

      targets<-lapply(which_series,function(x) {
                        l<-length(json_file[[x]]$target)
                        json_file[[x]]$target[(l+1-h):l]
                        })
      fores<-lapply(forecast_object[[h-1]],function(x) x$forecasts)

      ##indexes into targets and fores
      sMAPE<-sapply(1:length(targets),function(ind) (2/(h+1))*sum((abs(targets[[ind]]-fores[[ind]])/(abs(targets[[ind]])+abs(fores[[ind]])))*100))
      return(sMAPE)

      fores<-lapply(forecast_object[[h-1]],function(x) x$forecasts)

      lapply(forecast_object[[h-1]],function(x) lapply(1:which_series,function(ind) x[[ind]]$sMAPE==sMAPE[ind]))
      })

     return(my_sMAPES)
}



#######################################################################################-




read_forecasts<-function(folder,name){


  read_in<-readRDS(paste0(folder,'/',name,".RData"))

  return(read_in)

}


#######################################################################################-


write_sMAPES<-function(sMAPES,folder,name){

  saveRDS(sMAPES, file=paste0(folder,'/',name,"_sMAPES_.RData"))
}



#######################################################################################-

##This is for individual horizons
sMAPE_summary<-function(sMAPES,h){

  print(summary(sMAPES[[h-1]]))
  hist(sMAPES[[h-1]],main=paste('Horizon',h),xlab='sMAPE')
  ?hist

}


#######################################################################################-

summary_all_horizons<-function(sMAPES){

  mins<-sapply(my_sMAPES,function(x) min(x))
  means<-sapply(my_sMAPES,function(x) mean(x))
  medians<-sapply(my_sMAPES,function(x) median(x))
  maxes<-sapply(my_sMAPES,function(x) max(x))
  df<-data.frame('Horizon'=horizon,'Min'=mins,'Median'=medians,'Mean'=means,'Max'=maxes)
  print(df)

}
