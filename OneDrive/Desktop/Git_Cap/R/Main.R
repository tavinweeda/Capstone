rm(list=ls())
source('Functions.R')

json_file<-readRDS("C:\\Users\\tavin\\OneDrive\\Desktop\\json_holder.RData")

##Read in monthly, quarterly, yearly, or other data
json_file<-read_data(which_data='monthly')
##Turns series into numeric values
json_file<-to_numeric(json_file)
## Sets meta data about series
json_file<-series_features(json_file)


## Get Cochrane orcutt trend results
json_file<-cochrane_orcutt_eval(json_file)


##Remove Trend
json_file<-remove_trend_differencing(json_file)

##Get Phis and Thetas for ARIMA (currently uses top AIC for p and q)
json_file<-get_Phi_Thetas_aic(json_file)

##Forecast

ARIMA_Forecasts<-lapply(2:3,function(x) forecast_arima(json_file[1:20],horizon=x))

##Write forecasts to folder as RDS file.

write_forecasts(ARIMA_Forecasts,folder = 'ARIMA_Forecasts',name='ARIMA_CochraneOrc_forecast1')
